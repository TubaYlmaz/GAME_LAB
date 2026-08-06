module.exports = function ({ app, io, redisClient, db }) {
    // Gece oylarını ve mutabakatları tutan bellek
    const nightVotes = {};

    // ==========================================
    // 🎯 KÖTÜ ROL KONTROL YARDIMCISI (Vampir veya Seri Katil)
    // ==========================================
    function isEvilPlayer(player) {
        if (!player) return false;
        if (player.isVampire === true) return true;

        const roleStr = String(player.role || '').toLowerCase();
        return roleStr.includes('vampir') || roleStr.includes('seri') || roleStr.includes('katil');
    }

    function normalisePlayerName(name) {
        return String(name || '').trim().toLocaleLowerCase('tr-TR');
    }

    function getSpecialRoleTeam(player) {
        const role = String(player && player.role || '').toLocaleLowerCase('tr-TR');
        if (player && player.isVampire === true || role.includes('vampir')) return 'Vampirler';
        if (role.includes('doktor')) return 'Doktorlar';
        if (role.includes('seri') || role.includes('katil')) return 'Seri Katiller';
        return null;
    }

    async function emitTeamVoteStatus(roomCode, players, currentVotes) {
        const sockets = await io.in(roomCode).fetchSockets();

        for (const connectedSocket of sockets) {
            const player = players.find(candidate =>
                normalisePlayerName(typeof candidate === 'object' ? candidate.name : candidate) ===
                normalisePlayerName(connectedSocket.data.vkPlayerName)
            );
            const team = getSpecialRoleTeam(player);
            const teamMembers = team
                ? players.filter(candidate => candidate.isAlive !== false && getSpecialRoleTeam(candidate) === team)
                    .map(candidate => candidate.name)
                : [];
            const teamVotes = {};

            if (team) {
                Object.entries(currentVotes).forEach(([voterName, targetName]) => {
                    const voter = players.find(candidate =>
                        normalisePlayerName(candidate.name) === normalisePlayerName(voterName)
                    );
                    if (getSpecialRoleTeam(voter) !== team || !targetName || targetName === 'skip') return;

                    const target = String(targetName);
                    if (!teamVotes[target]) teamVotes[target] = [];
                    teamVotes[target].push(voter.name);
                });
            }

            io.to(connectedSocket.id).emit('vk_team_vote_status', {
                team,
                teamMembers,
                teamVotes
            });
        }
    }

    async function getLobbyReturnStatus(roomCode, players) {
        const returnedPlayers = await redisClient.smembers(
            `room:${roomCode}:returned_players`
        );
        const returnedNames = new Set(returnedPlayers.map(normalisePlayerName));
        const expectedNames = players.map(player => normalisePlayerName(
            typeof player === 'object' ? player.name : player
        ));

        return {
            returnedPlayers,
            isEveryoneBack: expectedNames.length > 0 && expectedNames.every(
                name => returnedNames.has(name)
            )
        };
    }

    async function restoreOriginalHostForLobby(roomCode) {
        const room = await redisClient.hgetall(`room:${roomCode}`);
        if (!room || !room.players) return null;

        const players = JSON.parse(room.players || '[]');
        const originalHostName = room.creatorHost || room.host;
        const originalHostKey = normalisePlayerName(originalHostName);
        const originalHostExists = players.some(player => normalisePlayerName(
            typeof player === 'object' ? player.name : player
        ) === originalHostKey);

        if (!originalHostKey || !originalHostExists) return players;

        const updatedPlayers = players.map(player => {
            if (typeof player !== 'object') return player;
            return {
                ...player,
                isHost: normalisePlayerName(player.name) === originalHostKey
            };
        });

        await redisClient.hset(`room:${roomCode}`, 'host', originalHostName);
        await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(updatedPlayers));
        if (db) {
            try {
                await db.query(
                    `UPDATE room_players rp
                     INNER JOIN players p ON p.id = rp.player_id
                     SET rp.is_host = (p.player_name = ?)
                     WHERE rp.room_code = ?`,
                    [originalHostName, roomCode]
                );
            } catch (dbErr) {
                console.error('MySQL host restore failed:', dbErr);
            }
        }

        io.to(roomCode).emit('vk_host_changed', {
            newHost: originalHostName,
            message: `Lobiye dönüldü. Muhtarlık oda kurucusu ${originalHostName} kişisine geri verildi.`
        });
        io.to(roomCode).emit('vk_players_updated', updatedPlayers);

        return updatedPlayers;
    }

    async function finishGame(roomCode, winner, eliminatedPlayer) {
        const room = await redisClient.hgetall(`room:${roomCode}`);
        if (!room || room.status === 'finished') return false;

        await redisClient.hset(`room:${roomCode}`, 'status', 'finished');
        await saveGameWinnerToDb(roomCode, winner);

        io.to(roomCode).emit('vk_game_over', {
            winner,
            eliminatedPlayer,
            players: JSON.parse(room.players || '[]')
        });
        delete nightVotes[roomCode];
        return true;
    }

    async function resolveVotingIfReady(roomCode) {
        const roomData = await redisClient.hgetall(`room:${roomCode}`);
        if (
            !roomData ||
            roomData.status !== 'started' ||
            roomData.phase !== 'voting'
        ) return false;

        let players = JSON.parse(roomData.players || '[]');
        const alivePlayers = players.filter(player => player.isAlive !== false);
        const voteKey = `room:${roomCode}:vk_votes`;
        const lockKey = `room:${roomCode}:vk_locked_votes`;
        const currentVotes = await redisClient.hgetall(voteKey) || {};
        const lockedPlayers = await redisClient.smembers(lockKey) || [];
        const activePlayerNames = new Set(alivePlayers.map(player => normalisePlayerName(player.name)));
        const activeLocks = lockedPlayers.filter(name => activePlayerNames.has(normalisePlayerName(name)));

        if (alivePlayers.length === 0 || activeLocks.length < alivePlayers.length) return false;

        const voteCounts = {};
        alivePlayers.forEach(player => {
            voteCounts[player.name.trim()] = 0;
        });
        Object.entries(currentVotes).forEach(([voterName, targetName]) => {
            if (!activePlayerNames.has(normalisePlayerName(voterName)) || !targetName || targetName === 'skip') return;
            const targetKey = Object.keys(voteCounts).find(name =>
                normalisePlayerName(name) === normalisePlayerName(targetName)
            );
            if (targetKey) voteCounts[targetKey]++;
        });

        let eliminatedPlayerName = null;
        let eliminatedPlayerObj = null;
        let maxVotes = 0;
        let isTie = false;
        Object.entries(voteCounts).forEach(([playerName, count]) => {
            if (count > maxVotes) {
                maxVotes = count;
                eliminatedPlayerName = playerName;
                isTie = false;
            } else if (count === maxVotes && count > 0) {
                isTie = true;
            }
        });
        if (isTie) eliminatedPlayerName = null;

        let isVampire = false;
        if (eliminatedPlayerName) {
            players = players.map(player => {
                if (normalisePlayerName(player.name) !== normalisePlayerName(eliminatedPlayerName)) return player;
                eliminatedPlayerObj = player;
                isVampire = !!player.isVampire || String(player.role || '').toLowerCase().includes('vampir');
                return { ...player, isAlive: false };
            });
            players = await handleHostTransferIfNeeded(roomCode, players);

            if (db) {
                try {
                    await setRoomPlayerAlive(roomCode, eliminatedPlayerName, false);
                } catch (dbErr) {
                    console.error('❌ [MySQL Error - Elenen Oyuncu Güncellenemedi]:', dbErr);
                }
            }
        }

        await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(players));
        await redisClient.del(voteKey);
        await redisClient.del(lockKey);
        await redisClient.del(`room:${roomCode}:vk_bot_locked_votes`);

        const remainingAlive = players.filter(player => player.isAlive !== false);
        const evilCount = remainingAlive.filter(isEvilPlayer).length;
        const goodCount = remainingAlive.filter(player => !isEvilPlayer(player)).length;

        if (evilCount === 0) {
            await finishGame(roomCode, 'KÖYLÜLER', eliminatedPlayerName);
        } else if (evilCount >= goodCount) {
            await finishGame(roomCode, 'VAMPİRLER', eliminatedPlayerName);
        } else {
            // The vote is final. Keeping the room in the voting phase lets a
            // later disconnect start a second, stale bot vote.
            await redisClient.hmset(`room:${roomCode}`, {
                phase: 'day',
                isAfterNight: 'false'
            });
            const result = {
                eliminatedPlayer: eliminatedPlayerName,
                eliminatedRole: eliminatedPlayerObj ? eliminatedPlayerObj.role : null,
                isTie,
                isVampire,
                players
            };
            io.to(roomCode).emit('vk_voting_results', result);
        }
        io.to(roomCode).emit('vk_players_updated', players);
        return true;
    }

    function chooseRandomTarget(players, ownName, predicate = () => true) {
        const alivePlayers = players.filter(player => player.isAlive !== false);
        const candidates = alivePlayers.filter(player =>
            normalisePlayerName(player.name) !== normalisePlayerName(ownName) && predicate(player)
        );
        const pool = candidates.length > 0
            ? candidates
            : alivePlayers.filter(player => predicate(player));
        if (pool.length === 0) return null;
        return pool[Math.floor(Math.random() * pool.length)].name;
    }

    function isActiveBot(player) {
        return !!player && player.isBot === true;
    }

    function getRoleAction(player) {
        const role = String(player && player.role || '').toLocaleLowerCase('tr-TR');
        if (role.includes('vampir')) return 'vampire';
        if (role.includes('seri') || role.includes('katil')) return 'killer';
        if (role.includes('doktor')) return 'doctor';
        return 'math';
    }

    function isSharedNightAction(action) {
        return action === 'vampire' || action === 'killer' || action === 'doctor';
    }

    // When a real player can make a shared night decision, their replacement
    // bot stays silent. A bot acts only if it is the only available member of
    // that role's team.
    function isBotNightActionSuppressed(bot, alivePlayers) {
        const action = getRoleAction(bot);
        return isSharedNightAction(action) && alivePlayers.some(player =>
            !isActiveBot(player) && getRoleAction(player) === action
        );
    }

    function getNightActionParticipants(alivePlayers) {
        return alivePlayers.filter(player =>
            !isActiveBot(player) || !isBotNightActionSuppressed(player, alivePlayers)
        );
    }

    function getRelevantNightVotes(votes, participants) {
        const participantNames = new Set(participants.map(player =>
            normalisePlayerName(player.name)
        ));
        const filterActions = actions => Object.fromEntries(
            Object.entries(actions).filter(([playerName]) =>
                participantNames.has(normalisePlayerName(playerName))
            )
        );

        return {
            vampires: filterActions(votes.vampires),
            killers: filterActions(votes.killers),
            doctors: filterActions(votes.doctors),
            mathSolvedPlayers: votes.mathSolvedPlayers.filter(playerName =>
                participantNames.has(normalisePlayerName(playerName))
            )
        };
    }

    function chooseBotNightTarget(bot, alivePlayers, action, votes) {
        if (action === 'vampire') {
            // Mirror an existing vampire choice to avoid a team disagreement.
            const agreedTarget = Object.values(votes.vampires)[0];
            return agreedTarget || chooseRandomTarget(
                alivePlayers,
                bot.name,
                player => !isEvilPlayer(player)
            );
        }

        if (action === 'killer') {
            const agreedTarget = Object.values(votes.killers)[0];
            return agreedTarget || chooseRandomTarget(alivePlayers, bot.name);
        }

        if (action === 'doctor') {
            const threatenedTarget = Object.values(votes.vampires)[0] ||
                Object.values(votes.killers)[0];
            const threatenedPlayer = alivePlayers.find(player =>
                normalisePlayerName(player.name) === normalisePlayerName(threatenedTarget)
            );
            return threatenedPlayer ? threatenedPlayer.name :
                chooseRandomTarget(alivePlayers, null) || bot.name;
        }

        return null;
    }

    async function addBotVotes(roomCode) {
        const roomData = await redisClient.hgetall(`room:${roomCode}`);
        if (
            !roomData ||
            roomData.status !== 'started' ||
            roomData.phase !== 'voting'
        ) return;

        const players = JSON.parse(roomData.players || '[]');
        const alivePlayers = players.filter(player => player.isAlive !== false);
        const bots = alivePlayers.filter(isActiveBot);
        if (bots.length === 0) return;

        const voteKey = `room:${roomCode}:vk_votes`;
        const lockKey = `room:${roomCode}:vk_locked_votes`;
        const botLockKey = `room:${roomCode}:vk_bot_locked_votes`;
        const lockedPlayers = await redisClient.smembers(lockKey) || [];
        const lockedNames = new Set(lockedPlayers.map(normalisePlayerName));

        console.log(`🤖 [BOT OYLAMA] Oda: ${roomCode} | Aktif botlar: ${bots.map(bot => bot.name).join(', ')}`);

        for (const bot of bots) {
            if (lockedNames.has(normalisePlayerName(bot.name))) continue;

            // Bots always cast a locked pass vote. It has no elimination
            // weight, but it still lets the round complete without waiting for
            // a disconnected player.
            const target = 'skip';
            await redisClient.multi()
                .hset(voteKey, bot.name, target)
                .sadd(lockKey, bot.name)
                .sadd(botLockKey, bot.name)
                .exec();

            console.log(`✅ [BOT OYU ONAYLANDI] Oda: ${roomCode} | Bot: ${bot.name} | Hedef: ${target}`);
            io.to(roomCode).emit('vk_bot_vote_confirmed', {
                voterName: bot.name,
                targetName: target,
                locked: true
            });
        }

        const currentVotes = await redisClient.hgetall(voteKey) || {};
        const updatedLocks = await redisClient.smembers(lockKey) || [];
        io.to(roomCode).emit('vk_vote_status_updated', {
            votedCount: updatedLocks.length,
            totalPlayers: alivePlayers.length,
            lockedPlayers: updatedLocks
        });
        io.to(roomCode).emit('vk_vote_progress', {
            votedCount: updatedLocks.length,
            totalAlive: alivePlayers.length
        });
        await emitTeamVoteStatus(roomCode, players, currentVotes);
        await resolveVotingIfReady(roomCode);
    }

    function addBotNightActions(roomCode, players) {
        if (!nightVotes[roomCode]) return;
        // Callers may pass the full player list. A dead replacement must
        // never vote or perform a night action.
        const alivePlayers = players.filter(player => player.isAlive !== false);
        const bots = alivePlayers.filter(isActiveBot);
        if (bots.length === 0) return;

        for (const bot of bots) {
            if (isBotNightActionSuppressed(bot, alivePlayers)) {
                console.log(`🤫 [BOT GECE PAS] Oda: ${roomCode} | Bot: ${bot.name} | İnsan takım arkadaşı karar verecek.`);
                continue;
            }

            const action = getRoleAction(bot);
            const target = chooseBotNightTarget(bot, alivePlayers, action, nightVotes[roomCode]);

            if (action === 'vampire' && target) {
                nightVotes[roomCode].vampires[bot.name] = target;
            } else if (action === 'killer' && target) {
                nightVotes[roomCode].killers[bot.name] = target;
            } else if (action === 'doctor' && target) {
                nightVotes[roomCode].doctors[bot.name] = target;
            } else if (action === 'math' && !nightVotes[roomCode].mathSolvedPlayers.includes(bot.name)) {
                // The client creates villager questions locally.  This is the
                // same successful result as choosing the calculated answer.
                nightVotes[roomCode].mathSolvedPlayers.push(bot.name);
            }
        }
    }

    function emitNightActionChoices(roomCode) {
        const votes = nightVotes[roomCode];
        if (!votes) return;

        const formatSelections = (roleVotes) => {
            const selections = {};
            const counts = {};
            Object.entries(roleVotes || {}).forEach(([voter, selectedTarget]) => {
                const targetName = String(selectedTarget);
                if (!selections[targetName]) selections[targetName] = [];
                selections[targetName].push(voter);
                counts[targetName] = (counts[targetName] || 0) + 1;
            });
            return { selections, counts };
        };

        const vampireData = formatSelections(votes.vampires);
        const killerData = formatSelections(votes.killers);
        const doctorData = formatSelections(votes.doctors);

        io.to(roomCode).emit('vk_night_action_choices', {
            vampireSelections: vampireData.selections,
            vampireCounts: vampireData.counts,
            killerSelections: killerData.selections,
            killerCounts: killerData.counts,
            doctorSelections: doctorData.selections,
            doctorCounts: doctorData.counts
        });
    }

    async function advanceRoleRevealIfReady(roomCode, players) {
        const seenPlayers = await redisClient.smembers(
            `room:${roomCode}:roles_seen_players`
        ) || [];
        const seenNames = new Set(seenPlayers.map(normalisePlayerName));
        const everyoneHasSeenRole = players.length > 0 && players.every(player =>
            seenNames.has(normalisePlayerName(typeof player === 'object' ? player.name : player))
        );

        if (!everyoneHasSeenRole) return false;

        await redisClient.del(`room:${roomCode}:roles_seen_players`);
        await redisClient.hmset(`room:${roomCode}`, {
            phase: 'day',
            isAfterNight: 'false'
        });
        io.to(roomCode).emit('vk_all_roles_seen');
        io.to(roomCode).emit('vk_phase_changed', { phase: 'day' });
        return true;
    }
    async function resolveNightIfReady(roomCode) {
        const roomData = await redisClient.hgetall(`room:${roomCode}`);
        if (
            !roomData ||
            roomData.status !== 'started' ||
            roomData.phase !== 'night' ||
            !nightVotes[roomCode]
        ) return false;

        const players = JSON.parse(roomData.players || '[]');
        const alivePlayers = players.filter(player => player.isAlive !== false);
        const actionParticipants = getNightActionParticipants(alivePlayers);
        const votes = nightVotes[roomCode];
        const relevantVotes = getRelevantNightVotes(votes, actionParticipants);
        const totalActionsReceived =
            Object.keys(relevantVotes.vampires).length +
            Object.keys(relevantVotes.killers).length +
            Object.keys(relevantVotes.doctors).length +
            relevantVotes.mathSolvedPlayers.length;

        if (totalActionsReceived < actionParticipants.length) return false;

        const vampireChoices = Object.values(relevantVotes.vampires);
        const killerChoices = Object.values(relevantVotes.killers);
        const uniqueVampireTargets = [...new Set(vampireChoices)];
        const uniqueKillerTargets = [...new Set(killerChoices)];
        const totalVampires = actionParticipants.filter(player =>
            getRoleAction(player) === 'vampire'
        ).length;
        const totalKillers = actionParticipants.filter(player =>
            getRoleAction(player) === 'killer'
        ).length;

        if (totalVampires > 0 && vampireChoices.length === totalVampires && uniqueVampireTargets.length > 1) {
            io.to(roomCode).emit('night_action_error', {
                roleTarget: 'Vampir',
                message: '⚠️ Vampirler anlaşamadı! Ortak hedefi seçip kararını yeniden onayla.'
            });
            return true;
        }
        if (totalKillers > 0 && killerChoices.length === totalKillers && uniqueKillerTargets.length > 1) {
            io.to(roomCode).emit('night_action_error', {
                roleTarget: 'Seri Katil',
                message: '⚠️ Seri katiller anlaşamadı! Ortak hedef seçmelisiniz.'
            });
            return true;
        }

        const finalVampireTarget = uniqueVampireTargets[0] || null;
        const finalDoctorTarget = Object.values(relevantVotes.doctors)[0] || null;
        const finalKillerTarget = uniqueKillerTargets[0] || null;
        const deadTargetNames = new Set();
        if (finalKillerTarget) deadTargetNames.add(normalisePlayerName(finalKillerTarget));
        if (finalVampireTarget && normalisePlayerName(finalVampireTarget) !== normalisePlayerName(finalDoctorTarget)) {
            deadTargetNames.add(normalisePlayerName(finalVampireTarget));
        }

        const actualDeadNames = [];
        let updatedPlayers = players.map(player => {
            if (!deadTargetNames.has(normalisePlayerName(player.name))) return player;
            actualDeadNames.push(player.name);
            return { ...player, isAlive: false };
        });
        updatedPlayers = await handleHostTransferIfNeeded(roomCode, updatedPlayers);
        await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(updatedPlayers));

        if (db) {
            try {
                for (const deadName of actualDeadNames) {
                    await setRoomPlayerAlive(roomCode, deadName, false);
                }
            } catch (dbErr) {
                console.error('❌ [MySQL Error - Gece Ölüleri Güncellenemedi]:', dbErr);
            }
        }

        io.to(roomCode).emit('night_results', {
            deadPlayers: actualDeadNames,
            message: actualDeadNames.length > 0
                ? `Sabah oldu! Gece kurbanı / kurbanları: ${actualDeadNames.join(', ')} 💀`
                : 'Mucize! Doktor köyü korumayı başardı, gece kimse ölmedi. 🩺'
        });
        io.to(roomCode).emit('vk_players_updated', updatedPlayers);

        const remainingAlive = updatedPlayers.filter(player => player.isAlive !== false);
        const evilCount = remainingAlive.filter(isEvilPlayer).length;
        const goodCount = remainingAlive.filter(player => !isEvilPlayer(player)).length;
        if (evilCount === 0) {
            await finishGame(roomCode, 'KÖYLÜLER', actualDeadNames.join(', ') || 'Kötüler');
        } else if (evilCount >= goodCount) {
            await finishGame(roomCode, 'VAMPİRLER', actualDeadNames.join(', ') || 'Köy Kurbanı');
        } else {
            // Mark the completed night before removing its in-memory votes so
            // reconnecting players cannot reopen the same night.
            await redisClient.hmset(`room:${roomCode}`, {
                phase: 'day',
                isAfterNight: 'true'
            });
            delete nightVotes[roomCode];
        }
        return true;
    }

    async function handleHostTransferIfNeeded(roomCode, updatedPlayers) {
        const savedRoom = await redisClient.hgetall(`room:${roomCode}`);
        if (!savedRoom) return updatedPlayers;

        const currentHostKey = normalisePlayerName(savedRoom.host);
        const currentHostByRoom = updatedPlayers.find(player => {
            const name = typeof player === 'object' ? player.name : player;
            return normalisePlayerName(name) === currentHostKey;
        });
        const currentHost = currentHostByRoom || updatedPlayers.find(player =>
            typeof player === 'object' && player.isHost === true
        );

        if (currentHost && currentHost.isAlive !== false) return updatedPlayers;

        const alivePlayers = updatedPlayers.filter(player => player.isAlive !== false);
        if (alivePlayers.length === 0) return updatedPlayers;

        const humanPlayers = alivePlayers.filter(player => player.isBot !== true);
        const eligiblePlayers = humanPlayers.length > 0 ? humanPlayers : alivePlayers;
        const newHost = eligiblePlayers[
            Math.floor(Math.random() * eligiblePlayers.length)
        ];
        const newHostName = typeof newHost === 'object' ? newHost.name : newHost;
        const previousHostName = currentHost
            ? (typeof currentHost === 'object' ? currentHost.name : currentHost)
            : savedRoom.host;

        const reassignedPlayers = updatedPlayers.map(player => {
            if (typeof player !== 'object') return player;
            return {
                ...player,
                isHost: normalisePlayerName(player.name) === normalisePlayerName(newHostName)
            };
        });

        await redisClient.hset(`room:${roomCode}`, 'host', newHostName);
        await redisClient.hset(
            `room:${roomCode}`,
            'players',
            JSON.stringify(reassignedPlayers)
        );

        if (db) {
            try {
                await db.query(
                    `UPDATE room_players rp
                     INNER JOIN players p ON p.id = rp.player_id
                     SET rp.is_host = (p.player_name = ?)
                     WHERE rp.room_code = ?`,
                    [newHostName, roomCode]
                );
            } catch (dbErr) {
                console.error('MySQL host update failed:', dbErr);
            }
        }

        console.log(`👑 [MUHTAR DEĞİŞTİ] Eski Muhtar (${previousHostName}) öldü. Yeni Muhtar: ${newHostName}`);
        io.to(roomCode).emit('vk_host_changed', {
            newHost: newHostName,
            message: `👑 Muhtar ${previousHostName} hayatını kaybetti! Yeni muhtar: ${newHostName}`
        });
        io.to(roomCode).emit('vk_players_updated', reassignedPlayers);
        return reassignedPlayers;
    }

    async function saveGameWinnerToDb(roomCode, winnerTeam) {
        console.log(`🔍 [LOG - DB] saveGameWinnerToDb tetiklendi. Oda: ${roomCode}, Kazanan: ${winnerTeam}`);
        if (typeof db === 'undefined' || !db) {
            console.warn(`⚠️ [LOG - DB UYARI] db nesnesi tanımsız veya bağlantı yok! Kazanan MySQL'e yazılamadı.`);
            return;
        }
        try {
            const query = `UPDATE rooms SET game_status = 'finished', winner_team = ? WHERE room_code = ?`;
            const [result] = await db.query(query, [winnerTeam, roomCode]);
            console.log(`🏆 [MySQL] Oda ${roomCode} bitti. Kazanan kaydedildi. Etkilenen satır: ${result.affectedRows}`);
        } catch (err) {
            console.error("❌ [MySQL Error - Kazanan Kaydetme]:", err);
        }
    }

    function getRoleStatistic(role) {
        const value = String(role || '').toLocaleLowerCase('tr-TR');
        if (value.includes('vampir')) return 'vampir_count';
        if (value.includes('doktor')) return 'doktor_count';
        if (value.includes('seri') || value.includes('katil')) return 'serial_killer_count';
        return 'koylu_count';
    }

    // Oyuncu adı kalıcı profilin anahtarıdır. İleride giriş sistemi eklenirse
    // player_name yerine kullanıcı hesabının id'si kullanılmalıdır.
    async function ensurePlayerId(playerName, connection = db) {
        const cleanName = String(playerName || '').trim();
        if (!connection || !cleanName) return null;

        const [result] = await connection.query(
            `INSERT INTO players (player_name)
             VALUES (?)
             ON DUPLICATE KEY UPDATE
                id = LAST_INSERT_ID(id),
                last_seen_at = CURRENT_TIMESTAMP`,
            [cleanName]
        );
        return result.insertId;
    }

    async function saveRoomPlayerState(roomCode, playerName, role, isHost, isAlive, connection = db) {
        if (!connection) return null;

        // 🎯 Odanın MySQL'de var olduğundan emin oluyoruz; yoksa anında oluşturuyoruz
        await connection.query(
            `INSERT INTO rooms (room_code, game_status, game_mode, is_active)
            VALUES (?, 'waiting', 'Klasik', TRUE)
            ON DUPLICATE KEY UPDATE is_active = TRUE`,
            [roomCode]
        );

        const playerId = await ensurePlayerId(playerName, connection);
        if (!playerId) return null;

        await connection.query(
            `INSERT INTO room_players (room_code, player_id, current_role, is_host, is_alive)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                current_role = VALUES(current_role),
                is_host = VALUES(is_host),
                is_alive = VALUES(is_alive),
                joined_at = CURRENT_TIMESTAMP`,
            [roomCode, playerId, role, Boolean(isHost), Boolean(isAlive)]
        );
        return playerId;
    }

    async function recordRoleStatistic(roomCode, playerId, role, connection = db) {
        const roleColumn = getRoleStatistic(role);
        const roleCounts = {
            koylu_count: 0,
            vampir_count: 0,
            doktor_count: 0,
            serial_killer_count: 0
        };
        roleCounts[roleColumn] = 1;

        await connection.query(
            `INSERT INTO room_player_stats
                (room_code, player_id, koylu_count, vampir_count, doktor_count, serial_killer_count, total_games)
             VALUES (?, ?, ?, ?, ?, ?, 1)
             ON DUPLICATE KEY UPDATE
                koylu_count = koylu_count + VALUES(koylu_count),
                vampir_count = vampir_count + VALUES(vampir_count),
                doktor_count = doktor_count + VALUES(doktor_count),
                serial_killer_count = serial_killer_count + VALUES(serial_killer_count),
                total_games = total_games + 1,
                last_played_at = CURRENT_TIMESTAMP`,
            [
                roomCode,
                playerId,
                roleCounts.koylu_count,
                roleCounts.vampir_count,
                roleCounts.doktor_count,
                roleCounts.serial_killer_count
            ]
        );
    }

    async function setRoomPlayerAlive(roomCode, playerName, isAlive) {
        await db.query(
            `UPDATE room_players rp
             INNER JOIN players p ON p.id = rp.player_id
             SET rp.is_alive = ?
             WHERE rp.room_code = ? AND p.player_name = ?`,
            [Boolean(isAlive), roomCode, String(playerName || '').trim()]
        );
    }

    async function distributeAndSaveRoles(roomCode) {
        const savedRoom = await redisClient.hgetall(`room:${roomCode}`);
        if (!savedRoom || !savedRoom.players) {
            return { error: "Oda bulunamadı!" };
        }
        if (savedRoom.status === 'started') {
            return { error: "Oyun zaten devam ediyor." };
        }

        let players = JSON.parse(savedRoom.players || '[]');
        if (players.length < 3) {
            return { error: "Oyunu başlatmak için en az 3 oyuncu gereklidir!" };
        }

        let vampireCount = parseInt(savedRoom.vampireCount, 10);
        if (isNaN(vampireCount) || vampireCount < 1) vampireCount = 1;

        let doctorCount = parseInt(savedRoom.doctorCount, 10);
        if (isNaN(doctorCount) || doctorCount < 0) doctorCount = 0;

        let serialKillerCount = parseInt(savedRoom.serialKillerCount, 10);
        if (isNaN(serialKillerCount) || serialKillerCount < 0) serialKillerCount = 0;

        while ((vampireCount + doctorCount + serialKillerCount) >= players.length) {
            if (serialKillerCount > 0) serialKillerCount--;
            else if (doctorCount > 0) doctorCount--;
            else if (vampireCount > 1) vampireCount--;
            else break;
        }

        let karistirilmis = [...players];
        for (let i = karistirilmis.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [karistirilmis[i], karistirilmis[j]] = [karistirilmis[j], karistirilmis[i]];
        }

        const roleMap = {};
        let idx = 0;

        for (let i = 0; i < vampireCount && idx < karistirilmis.length; i++, idx++) {
            const pName = typeof karistirilmis[idx] === 'object' ? karistirilmis[idx].name : karistirilmis[idx];
            roleMap[pName] = { role: 'Vampir 🧛', isVampire: true };
        }

        for (let i = 0; i < doctorCount && idx < karistirilmis.length; i++, idx++) {
            const pName = typeof karistirilmis[idx] === 'object' ? karistirilmis[idx].name : karistirilmis[idx];
            roleMap[pName] = { role: 'Doktor 🩺', isVampire: false };
        }

        for (let i = 0; i < serialKillerCount && idx < karistirilmis.length; i++, idx++) {
            const pName = typeof karistirilmis[idx] === 'object' ? karistirilmis[idx].name : karistirilmis[idx];
            roleMap[pName] = { role: 'Seri Katil 🔪', isVampire: false };
        }

        while (idx < karistirilmis.length) {
            const pName = typeof karistirilmis[idx] === 'object' ? karistirilmis[idx].name : karistirilmis[idx];
            roleMap[pName] = { role: 'Köylü 🧑‍🌾', isVampire: false };
            idx++;
        }

        const updatedPlayers = players.map(p => {
            const pName = typeof p === 'object' ? p.name : p;
            const assigned = roleMap[pName] || { role: 'Köylü 🧑‍🌾', isVampire: false };

            return {
                name: pName,
                gender: typeof p === 'object' ? (p.gender || 'male') : 'male',
                isHost: typeof p === 'object' ? !!p.isHost : false,
                role: assigned.role,
                isVampire: assigned.isVampire,
                isAlive: true
            };
        });

        if (db) {
            let connection;
            try {
                connection = await db.getConnection();
                await connection.beginTransaction();
                for (const p of updatedPlayers) {
                    const playerId = await saveRoomPlayerState(
                        roomCode, p.name, p.role, p.isHost, p.isAlive, connection
                    );
                    await recordRoleStatistic(roomCode, playerId, p.role, connection);
                }
                await connection.query(
                    `UPDATE rooms SET game_status = 'playing', winner_team = NULL WHERE room_code = ?`,
                    [roomCode]
                );
                await connection.commit();
            } catch (dbErr) {
                if (connection) await connection.rollback();
                console.error('MySQL role persistence failed:', dbErr);
                return { error: 'Oyun istatistikleri kaydedilemedi. Lütfen tekrar dene.' };
            } finally {
                if (connection) connection.release();
            }
        }

        await redisClient.hset(`room:${roomCode}`, 'status', 'started');
        await redisClient.hset(`room:${roomCode}`, 'phase', 'role_reveal');
        await redisClient.hset(`room:${roomCode}`, 'isAfterNight', 'false');
        await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(updatedPlayers));

        return { success: true, players: updatedPlayers };
    }

    io.on('connection', (socket) => {

        socket.on('vk_create_room', async (data) => {
            const { roomCode, hostName, gender, vampireCount, doctorCount, serialKillerCount, villagerCount } = data;
            const initialPlayers = [{ name: hostName, gender: gender || 'male', isHost: true }];
            socket.data.vkRoomCode = roomCode;
            socket.data.vkPlayerName = normalisePlayerName(hostName);

            const roomData = {
                host: hostName,
                creatorHost: hostName,
                status: 'waiting',
                players: JSON.stringify(initialPlayers),
                gameMode: 'Klasik',
                category: 'Rastgele',
                impostorCount: (vampireCount !== undefined ? vampireCount : 1).toString(),
                vampireCount: (vampireCount !== undefined ? vampireCount : 1).toString(),
                doctorCount: (doctorCount !== undefined ? doctorCount : 0).toString(),
                serialKillerCount: (serialKillerCount !== undefined ? serialKillerCount : 0).toString(),
                villagerCount: (villagerCount !== undefined ? villagerCount : 4).toString()
            };

            await redisClient.hmset(`room:${roomCode}`, roomData);
            await redisClient.hset(
                `room:${roomCode}:vk_player_sockets`,
                normalisePlayerName(hostName),
                socket.id
            );
            await redisClient.expire(`room:${roomCode}`, 7200);
            await redisClient.sadd(`room:${roomCode}:returned_players`, hostName.trim());

            if (db) {
                try {
                    await db.query(
                        `INSERT INTO rooms
                            (room_code, game_status, game_mode, vampire_count, doctor_count, serial_killer_count, is_active)
                         VALUES (?, 'waiting', 'Klasik', ?, ?, ?, TRUE)
                         ON DUPLICATE KEY UPDATE
                            game_status = 'waiting',
                            winner_team = NULL,
                            vampire_count = VALUES(vampire_count),
                            doctor_count = VALUES(doctor_count),
                            serial_killer_count = VALUES(serial_killer_count),
                            is_active = TRUE`,
                        [roomCode, roomData.vampireCount, roomData.doctorCount, roomData.serialKillerCount]
                    );
                    await saveRoomPlayerState(roomCode, hostName, 'Köylü 🧑‍🌾', true, true);
                } catch (dbErr) {
                    console.error("❌ [MySQL Error - Oda Kurulamadı]:", dbErr);
                }
            }

            socket.join(roomCode);
            socket.emit('room_created', { success: true, roomCode });
            io.to(roomCode).emit('vk_players_updated', initialPlayers);

            const returnedPlayers = await redisClient.smembers(`room:${roomCode}:returned_players`);
            io.to(roomCode).emit('vk_lobby_status_updated', {
                totalPlayersCount: initialPlayers.length,
                returnedPlayers: returnedPlayers
            });
        });

        socket.on('vk_join_room', async (data) => {
            const { roomCode, playerName, gender } = data;
            const roomExists = await redisClient.exists(`room:${roomCode}`);
            if (!roomExists) {
                socket.emit('error_message', { message: '❌ Böyle bir oda bulunamadı.' });
                return;
            }

            const currentRoom = await redisClient.hgetall(`room:${roomCode}`);
            let rawPlayers = JSON.parse(currentRoom.players || '[]');

            let playerObjects = rawPlayers.map(p => {
                if (typeof p === 'string') {
                    return { name: p, gender: 'male', isHost: p === currentRoom.host };
                }
                return p;
            });

            const playerNameKey = normalisePlayerName(playerName);
            const existingPlayer = playerObjects.find(player =>
                normalisePlayerName(player.name) === playerNameKey
            );
            const isBotBeingReclaimed = currentRoom.status === 'started' &&
                existingPlayer && existingPlayer.isBot === true;
            const playerExists = !!existingPlayer;

            if (!playerExists) {
                playerObjects.push({
                    name: playerName,
                    gender: gender || 'male',
                    isHost: false,
                    isAlive: true
                });
            }
            if (isBotBeingReclaimed) {
                // Keep the original identity, role, and alive status.  Only
                // control changes from the temporary bot back to the player.
                playerObjects = playerObjects.map(player =>
                    normalisePlayerName(player.name) === playerNameKey
                        ? {
                            ...player,
                            name: playerName,
                            gender: gender || player.gender || 'male',
                            isBot: false,
                            botActivatedAt: null,
                            isAlive: player.isAlive !== false
                        }
                        : player
                );
                console.log(`✅ ${playerName} yeniden bağlandı; bot kontrolü kapatıldı.`);
            }

            if (db) {
                try {
                    const existingPlayer = playerObjects.find(player =>
                        normalisePlayerName(player.name) === normalisePlayerName(playerName)
                    );
                    await saveRoomPlayerState(
                        roomCode,
                        playerName,
                        existingPlayer && existingPlayer.role ? existingPlayer.role : 'Köylü 🧑‍🌾',
                        Boolean(existingPlayer && existingPlayer.isHost),
                        existingPlayer ? existingPlayer.isAlive !== false : true
                    );
                } catch (dbErr) {
                    console.error(`❌ [MySQL Error - Oyuncu Eklenemedi (${playerName})]:`, dbErr);
                }
            }

            await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(playerObjects));

            let releasedBotVote = false;
            if (isBotBeingReclaimed && currentRoom.phase === 'voting') {
                const botLockKey = `room:${roomCode}:vk_bot_locked_votes`;
                const hadBotVote = await redisClient.sismember(botLockKey, existingPlayer.name);
                if (hadBotVote) {
                    await redisClient.hdel(`room:${roomCode}:vk_votes`, existingPlayer.name);
                    await redisClient.srem(`room:${roomCode}:vk_locked_votes`, existingPlayer.name);
                    await redisClient.srem(botLockKey, existingPlayer.name);
                    releasedBotVote = true;
                }
            }

            socket.join(roomCode);
            socket.data.vkRoomCode = roomCode;
            socket.data.vkPlayerName = normalisePlayerName(playerName);
            await redisClient.hset(
                `room:${roomCode}:vk_player_sockets`,
                playerNameKey,
                socket.id
            );
            console.log(`🏃‍♂️ ${playerName} (${gender}), ${roomCode} odasına katıldı.`);

            if (releasedBotVote) {
                const alivePlayers = playerObjects.filter(player => player.isAlive !== false);
                const currentVotes = await redisClient.hgetall(`room:${roomCode}:vk_votes`) || {};
                const lockedPlayers = await redisClient.smembers(`room:${roomCode}:vk_locked_votes`) || [];
                const activeNames = new Set(alivePlayers.map(player => normalisePlayerName(player.name)));
                const activeLocks = lockedPlayers.filter(name => activeNames.has(normalisePlayerName(name)));

                io.to(roomCode).emit('vk_vote_status_updated', {
                    votedCount: activeLocks.length,
                    totalPlayers: alivePlayers.length,
                    lockedPlayers: activeLocks
                });
                io.to(roomCode).emit('vk_vote_progress', {
                    votedCount: activeLocks.length,
                    totalAlive: alivePlayers.length
                });
                await emitTeamVoteStatus(roomCode, playerObjects, currentVotes);
            }

            if (currentRoom.status === 'started') {
                socket.emit('vk_game_state', {
                    roomCode,
                    status: currentRoom.status,
                    phase: currentRoom.phase || 'day',
                    players: playerObjects,
                    isHost: normalisePlayerName(currentRoom.host) === playerNameKey,
                    isAfterNight: currentRoom.isAfterNight === 'true'
                });
            }

            if (isBotBeingReclaimed) {
                if (db && existingPlayer.isAlive !== false) {
                    try {
                        await setRoomPlayerAlive(roomCode, playerName, true);
                    } catch (dbErr) {
                        console.error('❌ [MySQL Error - Yeniden Bağlanan Oyuncu Güncellenemedi]:', dbErr);
                    }
                }
                io.to(roomCode).emit('vk_player_reconnected', {
                    playerName,
                    message: `${playerName} yeniden bağlandı; bot devreden çıktı.`
                });
            }
            io.to(roomCode).emit('room_updated', {
                roomCode,
                players: playerObjects,
                host: currentRoom.host
            });

            io.to(roomCode).emit('vk_players_updated', playerObjects);

            const { returnedPlayers, isEveryoneBack } = await getLobbyReturnStatus(roomCode, playerObjects);
            io.to(roomCode).emit('vk_lobby_status_updated', {
                totalPlayersCount: playerObjects.length,
                returnedPlayers: returnedPlayers
            });
            io.to(roomCode).emit('lobby_return_status', {
                returnedPlayers: returnedPlayers,
                isEveryoneBack: isEveryoneBack
            });
        });

        socket.on('vk_player_returned_to_lobby', async (data) => {
            const { roomCode, playerName } = data;
            if (!roomCode || !playerName) return;
            const roomKey = `room:${roomCode}`;

            const cleanName = normalisePlayerName(playerName);
            await redisClient.sadd(`${roomKey}:returned_players`, cleanName);

            const roomData = await redisClient.hgetall(roomKey);
            let players = JSON.parse((roomData && roomData.players) || '[]');
            if (roomData && roomData.status === 'finished') {
                const bots = players.filter(player => player && player.isBot === true);
                if (bots.length > 0) {
                    // A bot is only temporary control for an existing player.
                    // Keep that player in the next lobby instead of removing
                    // their slot when the completed hand is cleaned up.
                    players = players.map(player =>
                        player && player.isBot === true
                            ? { ...player, isBot: false, botActivatedAt: null, isAlive: true }
                            : player
                    );
                    await redisClient.hset(roomKey, 'players', JSON.stringify(players));
                    io.to(roomCode).emit('vk_players_updated', players);
                }
                await restoreOriginalHostForLobby(roomCode);
            }
            const { returnedPlayers, isEveryoneBack } = await getLobbyReturnStatus(roomCode, players);

            io.to(roomCode).emit('vk_lobby_status_updated', {
                totalPlayersCount: players.length,
                returnedPlayers: returnedPlayers
            });
            io.to(roomCode).emit('lobby_return_status', {
                returnedPlayers: returnedPlayers,
                isEveryoneBack: isEveryoneBack
            });
        });

        socket.on('vk_update_room_config', async (data) => {
            const { roomCode, vampireCount, doctorCount, serialKillerCount, villagerCount } = data;
            if (!roomCode) return;

            const roomKey = `room:${roomCode}`;
            const roomData = await redisClient.hgetall(roomKey);
            const requestingPlayer = normalisePlayerName(socket.data.vkPlayerName);
            if (!roomData || requestingPlayer !== normalisePlayerName(roomData.host)) {
                socket.emit('vk_room_config_error', {
                    message: 'Lobi ayarlarını yalnızca muhtar değiştirebilir.'
                });
                return;
            }
            if (roomData.status === 'started') {
                socket.emit('vk_room_config_error', {
                    message: 'Oyun başladıktan sonra lobi ayarları değiştirilemez.'
                });
                return;
            }

            const parseCount = (value, minimum) => Math.max(
                minimum,
                Math.min(20, Number.parseInt(value, 10) || 0)
            );
            const config = {
                vampireCount: parseCount(vampireCount, 1).toString(),
                doctorCount: parseCount(doctorCount, 0).toString(),
                serialKillerCount: parseCount(serialKillerCount, 0).toString(),
                villagerCount: parseCount(villagerCount, 0).toString()
            };
            await redisClient.hmset(roomKey, config);
            if (db) {
                try {
                    await db.query(
                        `UPDATE rooms
                         SET vampire_count = ?, doctor_count = ?, serial_killer_count = ?
                         WHERE room_code = ?`,
                        [config.vampireCount, config.doctorCount, config.serialKillerCount, roomCode]
                    );
                } catch (dbErr) {
                    console.error('❌ [MySQL Error - Oda Ayarları Güncellenemedi]:', dbErr);
                }
            }
            io.to(roomCode).emit('vk_room_config_updated', config);
        });

        socket.on('vk_start_game', async (data) => {
            const { roomCode } = data;
            if (!roomCode) return;

            const roomKey = `room:${roomCode}`;
            const roomData = await redisClient.hgetall(roomKey);
            if (!roomData || !roomData.players) {
                socket.emit('vk_start_game_error', { message: 'Oda verisi bulunamadı!' });
                return;
            }

            const requestingPlayer = normalisePlayerName(socket.data.vkPlayerName);
            if (!requestingPlayer || requestingPlayer !== normalisePlayerName(roomData.host)) {
                socket.emit('vk_start_game_error', {
                    message: 'Yeni oyunu yalnızca mevcut muhtar başlatabilir.'
                });
                return;
            }

            if (roomData.status === 'started') {
                socket.emit('vk_start_game_error', {
                    message: 'Oyun zaten devam ediyor.'
                });
                return;
            }

            const players = JSON.parse(roomData.players || '[]');
            const { isEveryoneBack } = await getLobbyReturnStatus(roomCode, players);
            if (!isEveryoneBack) {
                socket.emit('vk_start_game_error', {
                    message: 'Yeni oyun için tüm oyuncuların lobiye dönmesi bekleniyor!'
                });
                return;
            }

            if (players.length < 3) {
                socket.emit('vk_start_game_error', {
                    message: 'Oyunu başlatmak için en az 3 oyuncu gereklidir!'
                });
                return;
            }

            await redisClient.del(`${roomKey}:vk_votes`);
            await redisClient.del(`${roomKey}:vk_locked_votes`);
            await redisClient.del(`${roomKey}:vk_bot_locked_votes`);
            await redisClient.del(`${roomKey}:returned_players`);
            await redisClient.del(`${roomKey}:roles_seen_players`);
            delete nightVotes[roomCode];

            const result = await distributeAndSaveRoles(roomCode);

            if (result.error) {
                socket.emit('vk_start_game_error', { message: result.error });
                return;
            }

            nightVotes[roomCode] = {
                vampires: {},
                killers: {},
                doctors: {},
                mathSolvedPlayers: []
            };

            io.to(roomCode).emit('vk_game_started', {
                players: result.players,
                timestamp: Date.now()
            });

            io.to(roomCode).emit('vk_players_updated', result.players);
            io.to(roomCode).emit('vk_phase_changed', { phase: 'role_reveal' });
        });

        socket.on('vk_player_role_seen', async (data) => {
            const { roomCode, playerName } = data;
            if (!roomCode || !playerName) return;

            const roomKey = `room:${roomCode}`;
            const cleanName = normalisePlayerName(playerName);
            const socketPlayerKey = normalisePlayerName(socket.data.vkPlayerName);
            if (!socketPlayerKey || socketPlayerKey !== cleanName) return;

            const roomData = await redisClient.hgetall(roomKey);
            if (
                !roomData ||
                !roomData.players ||
                roomData.status !== 'started' ||
                roomData.phase !== 'role_reveal'
            ) return;

            await redisClient.sadd(`${roomKey}:roles_seen_players`, cleanName);

            let players = JSON.parse(roomData.players || '[]');
            const seenPlayers = await redisClient.smembers(`${roomKey}:roles_seen_players`) || [];

            if (seenPlayers.length >= players.length) {
                await redisClient.del(`${roomKey}:roles_seen_players`);
                await redisClient.hmset(roomKey, {
                    phase: 'day',
                    isAfterNight: 'false'
                });
                io.to(roomCode).emit('vk_all_roles_seen');
                io.to(roomCode).emit('vk_phase_changed', { phase: 'day' });
            }
        });

        socket.on('vk_get_players', async (data) => {
            const { roomCode } = data;
            const currentRoom = await redisClient.hgetall(`room:${roomCode}`);
            if (currentRoom && currentRoom.players) {
                const rawPlayers = JSON.parse(currentRoom.players);
                let playerObjects = rawPlayers.map(p => {
                    if (typeof p === 'string') {
                        return { name: p, gender: 'male', isHost: p === currentRoom.host };
                    }
                    return p;
                });
                socket.emit('vk_players_updated', playerObjects);
            }
        });

        socket.on('vk_get_host_status', async (data) => {
            const roomCode = data && data.roomCode;
            if (!roomCode) return;
            const roomData = await redisClient.hgetall(`room:${roomCode}`);
            if (!roomData) return;

            socket.emit('vk_host_status', {
                host: roomData.host,
                isHost: normalisePlayerName(socket.data.vkPlayerName) ===
                    normalisePlayerName(roomData.host)
            });
        });

        socket.on('vk_get_team_vote_status', async (data) => {
            const { roomCode } = data || {};
            if (!roomCode) return;
            const roomData = await redisClient.hgetall(`room:${roomCode}`);
            if (!roomData || !roomData.players) return;
            const players = JSON.parse(roomData.players || '[]');
            const currentVotes = await redisClient.hgetall(`room:${roomCode}:vk_votes`) || {};
            await emitTeamVoteStatus(roomCode, players, currentVotes);
        });

        socket.on('submit_night_action', async (data) => {
            const { roomCode, playerName, target } = data;

            if (!roomCode || !playerName) return;

            const roomData = await redisClient.hgetall(`room:${roomCode}`);
            if (
                !roomData ||
                roomData.status !== 'started' ||
                roomData.phase !== 'night'
            ) {
                socket.emit('night_action_error', {
                    message: 'Gece aksiyonlari yalnizca gece fazinda yapilabilir.'
                });
                return;
            }

            const players = JSON.parse(roomData.players || '[]');
            const playerKey = normalisePlayerName(playerName);
            const socketPlayerKey = normalisePlayerName(socket.data.vkPlayerName);
            const actingPlayer = players.find(player =>
                normalisePlayerName(typeof player === 'object' ? player.name : player) === playerKey
            );

            if (!actingPlayer || !socketPlayerKey || playerKey !== socketPlayerKey || actingPlayer.isAlive === false) {
                socket.emit('night_action_error', {
                    message: 'Bu gece eylemini gerçekleştiremezsin.'
                });
                return;
            }

            if (!nightVotes[roomCode]) {
                nightVotes[roomCode] = {
                    vampires: {},
                    killers: {},
                    doctors: {},
                    mathSolvedPlayers: []
                };
            }

            const alivePlayers = players.filter(p => p.isAlive !== false);

            const rStr = String(actingPlayer.role || '').toLowerCase();
            const targetKey = normalisePlayerName(target);
            const validTarget = alivePlayers.some(player =>
                normalisePlayerName(typeof player === 'object' ? player.name : player) === targetKey
            );

            if (!rStr.includes('köylü') && !validTarget) {
                socket.emit('night_action_error', {
                    message: 'Geçerli ve hayatta olan bir oyuncu seçmelisin.'
                });
                return;
            }

            if (rStr.includes('vampir')) {
                nightVotes[roomCode].vampires[actingPlayer.name] = target;
            } else if (rStr.includes('seri') || rStr.includes('katil')) {
                nightVotes[roomCode].killers[actingPlayer.name] = target;
            } else if (rStr.includes('doktor')) {
                nightVotes[roomCode].doctors[actingPlayer.name] = target;
            } else {
                if (!nightVotes[roomCode].mathSolvedPlayers.includes(actingPlayer.name)) {
                    nightVotes[roomCode].mathSolvedPlayers.push(actingPlayer.name);
                }
            }

            addBotNightActions(roomCode, players);
            emitNightActionChoices(roomCode);

            if (await resolveNightIfReady(roomCode)) return;

            const actionParticipants = getNightActionParticipants(alivePlayers);
            const relevantVotes = getRelevantNightVotes(nightVotes[roomCode], actionParticipants);
            socket.emit('action_confirmed', {
                message: 'Kararın onaylandı, diğer oyuncuların işlemleri tamamlanması bekleniyor...'
            });

            const totalActivePlayers = actionParticipants.length;
            const totalActionsReceived =
                Object.keys(relevantVotes.vampires).length +
                Object.keys(relevantVotes.killers).length +
                Object.keys(relevantVotes.doctors).length +
                relevantVotes.mathSolvedPlayers.length;

            io.to(roomCode).emit('night_progress_update', {
                completedCount: totalActionsReceived,
                totalCount: totalActivePlayers
            });

        });

        socket.on('vk_change_phase', async (data) => {
            const { roomCode, nextPhase } = data;

            const savedRoom = await redisClient.hgetall(`room:${roomCode}`);
            const requestingPlayer = normalisePlayerName(socket.data.vkPlayerName);
            const currentHost = normalisePlayerName(savedRoom && savedRoom.host);

            if (!savedRoom || !requestingPlayer || requestingPlayer !== currentHost) {
                socket.emit('vk_phase_error', {
                    message: 'Faz geçişlerini yalnızca güncel muhtar yönetebilir.'
                });
                return;
            }

            if (savedRoom.status === 'finished') {
                return;
            }

            await redisClient.hset(`room:${roomCode}`, 'phase', nextPhase);
            if (nextPhase === 'day') {
                await redisClient.hset(`room:${roomCode}`, 'isAfterNight', 'true');
            }

            if (nextPhase === 'night') {
                nightVotes[roomCode] = {
                    vampires: {},
                    killers: {},
                    doctors: {},
                    mathSolvedPlayers: []
                };
                io.to(roomCode).emit('vk_phase_changed', { phase: 'night' });

                const phasePlayers = JSON.parse(savedRoom.players || '[]');
                addBotNightActions(roomCode, phasePlayers);
                emitNightActionChoices(roomCode);
                await resolveNightIfReady(roomCode);
                return;
            }

            if (nextPhase === 'voting') {
                io.to(roomCode).emit('vk_navigate_to_voting');
                const phasePlayers = JSON.parse(savedRoom.players || '[]');
                await emitTeamVoteStatus(roomCode, phasePlayers, {});
                await addBotVotes(roomCode);
            } else {
                io.to(roomCode).emit('vk_phase_changed', { phase: nextPhase });
            }
        });

    socket.on('vk_submit_vote', async (data) => {
                const { roomCode, voterName, votedTargetName, votedFor, isLocking } = data;
                const actualTarget = votedTargetName || votedFor;

                if (!roomCode || !voterName) return;

                const roomData = await redisClient.hgetall(`room:${roomCode}`);
                if (
                    !roomData ||
                    roomData.status !== 'started' ||
                    roomData.phase !== 'voting'
                ) {
                    socket.emit('vk_vote_error', {
                        message: 'Oylar yalnizca oylama fazinda kullanilabilir.'
                    });
                    return;
                }

                let players = JSON.parse(roomData.players || '[]');
                const voterKey = normalisePlayerName(voterName);
                const socketPlayerKey = normalisePlayerName(socket.data.vkPlayerName);
                const voter = players.find(player =>
                    normalisePlayerName(typeof player === 'object' ? player.name : player) === voterKey
                );
                const alivePlayers = players.filter(p => p.isAlive !== false);

                if (!voter || voter.isAlive === false || !socketPlayerKey || voterKey !== socketPlayerKey) {
                    socket.emit('vk_vote_error', { message: 'Oy kullanma yetkin bulunmuyor.' });
                    return;
                }

                const targetIsValid = actualTarget === 'skip' || alivePlayers.some(player =>
                    normalisePlayerName(typeof player === 'object' ? player.name : player) === normalisePlayerName(actualTarget)
                );
                if (!targetIsValid) {
                    socket.emit('vk_vote_error', { message: 'Geçerli, hayatta olan bir oyuncuya oy vermelisin.' });
                    return;
                }

                const voteKey = `room:${roomCode}:vk_votes`;
                const lockKey = `room:${roomCode}:vk_locked_votes`;

                // Oyuncu kilitlemişse oyunu değiştiremez
                const lockedPlayers = await redisClient.smembers(lockKey) || [];
                if (lockedPlayers.map(normalisePlayerName).includes(voterKey)) return;

                if (actualTarget) {
                    await redisClient.hset(voteKey, voter.name, actualTarget);
                }

                if (isLocking) {
                    await redisClient.sadd(lockKey, voter.name);
                }

                const currentVotes = await redisClient.hgetall(voteKey) || {};
                const updatedLockedPlayers = await redisClient.smembers(lockKey) || [];

                // 🎯 Anlık oy sayılarını hesaplama
                const voteCounts = {};
                Object.values(currentVotes).forEach(targetName => {
                    if (targetName && targetName !== 'skip') {
                        const target = String(targetName);
                        voteCounts[target] = (voteCounts[target] || 0) + 1;
                    }
                });

                // 🎯 İstemcilere anlık durumu gönder
                io.to(roomCode).emit('vk_vote_status_updated', {
                    votedCount: updatedLockedPlayers.length,
                    totalPlayers: alivePlayers.length,
                    lockedPlayers: updatedLockedPlayers,
                    voteCounts: voteCounts
                });

                io.to(roomCode).emit('vk_vote_progress', {
                    votedCount: updatedLockedPlayers.length,
                    totalAlive: alivePlayers.length
                });

                await emitTeamVoteStatus(roomCode, players, currentVotes);

                // 🎯 Oylamayı sonuçlandır (Eğer kilitlenen oy sayısı canlı oyuncu sayısına ulaştıysa)
                const isVotingResolved = await resolveVotingIfReady(roomCode);
                if (isVotingResolved) return;
            });

        socket.on('disconnect', async () => {
            const roomCode = socket.data.vkRoomCode;
            const playerName = socket.data.vkPlayerName;
            if (!roomCode || !playerName) return;

            const roomKey = `room:${roomCode}`;
            const roomData = await redisClient.hgetall(roomKey);
            if (!roomData || !roomData.players) return;

            let players = JSON.parse(roomData.players || '[]');
            const playerKey = normalisePlayerName(playerName);
            const activeSocketId = await redisClient.hget(
                `${roomKey}:vk_player_sockets`,
                playerKey
            );
            // Ignore a late disconnect from an older socket after the player
            // has already reconnected with a newer one.
            if (activeSocketId && activeSocketId !== socket.id) return;
            await redisClient.hdel(`${roomKey}:vk_player_sockets`, playerKey);

            const disconnectedPlayer = players.find(player =>
                normalisePlayerName(typeof player === 'object' ? player.name : player) === normalisePlayerName(playerName)
            );
            if (!disconnectedPlayer) return;

            let botPlayer = null;
            if (roomData.status === 'started') {
                // The bot retains the player's name, role, and place in the
                // round.  That lets the exact same player reclaim control on
                // reconnect without changing votes or action bookkeeping.
                players = players.map(player => {
                    if (normalisePlayerName(typeof player === 'object' ? player.name : player) !== playerKey) {
                        return player;
                    }
                    const playerRecord = typeof player === 'object' ? player : { name: player };
                    botPlayer = {
                        ...playerRecord,
                        isBot: true,
                        botActivatedAt: Date.now(),
                        isAlive: playerRecord.isAlive !== false
                    };
                    console.log(`🤖 [BOT DEVREDE] Oda: ${roomCode} | Oyuncu: ${botPlayer.name} | Faz: ${roomData.phase}`);
                    return botPlayer;
                });
            } else {
                const markedPlayers = players.map(player =>
                    normalisePlayerName(typeof player === 'object' ? player.name : player) === playerKey
                        ? { ...player, isAlive: false }
                        : player
                );
                const withNewHost = await handleHostTransferIfNeeded(roomCode, markedPlayers);
                players = withNewHost.filter(player =>
                    normalisePlayerName(typeof player === 'object' ? player.name : player) !== playerKey
                );
            }

            await redisClient.hset(roomKey, 'players', JSON.stringify(players));
            await redisClient.srem(`${roomKey}:returned_players`, playerKey);

            if (db && roomData.status !== 'started') {
                try {
                    await setRoomPlayerAlive(roomCode, disconnectedPlayer.name, false);
                } catch (dbErr) {
                    console.error('❌ [MySQL Error - Bağlantısı Kopan Oyuncu Güncellenemedi]:', dbErr);
                }
            }
            // Do not clear votes, night actions, or mark the database player
            // dead: the bot is continuing the same in-game character.

            io.to(roomCode).emit('vk_player_disconnected', {
                playerName: disconnectedPlayer.name,
                botName: botPlayer ? botPlayer.name : null,
                message: botPlayer
                    ? `${disconnectedPlayer.name} bağlantısını kaybetti; karakterini yapay zeka botu devraldı.`
                    : `${disconnectedPlayer.name} oyundan ayrıldı; oylama güncellendi.`
            });
            io.to(roomCode).emit('vk_players_updated', players);

            if (roomData.status === 'started') {
                if (roomData.phase === 'role_reveal' && botPlayer) {
                    await redisClient.sadd(
                        `${roomKey}:roles_seen_players`,
                        normalisePlayerName(botPlayer.name)
                    );
                    await advanceRoleRevealIfReady(roomCode, players);
                } else if (roomData.phase === 'voting') {
                    await addBotVotes(roomCode);
                } else if (roomData.phase === 'night') {
                    addBotNightActions(roomCode, players);
                    emitNightActionChoices(roomCode);
                    await resolveNightIfReady(roomCode);
                }
                await resolveVotingIfReady(roomCode);
            }

            const { returnedPlayers, isEveryoneBack } = await getLobbyReturnStatus(roomCode, players);
            io.to(roomCode).emit('vk_lobby_status_updated', {
                totalPlayersCount: players.length,
                returnedPlayers
            });
            io.to(roomCode).emit('lobby_return_status', {
                returnedPlayers,
                isEveryoneBack
            });
        });

    });

    app.post('/api/vk/start-game', async (req, res) => {
        try {
            const { roomCode } = req.body;
            const result = await distributeAndSaveRoles(roomCode);

            if (result.error) {
                return res.status(400).json({ error: result.error });
            }

            const updatedPlayers = result.players;

            io.to(roomCode).emit('vk_game_started', { players: updatedPlayers });
            io.to(roomCode).emit('vk_players_source', updatedPlayers);
            io.to(roomCode).emit('vk_players_updated', updatedPlayers);

            return res.json({
                status: "success",
                players: updatedPlayers
            });

        } catch (error) {
            console.error("Oyunu ilerletirken hata oluştu:", error);
            return res.status(500).json({ error: "Sunucu hatası" });
        }
    });
};
