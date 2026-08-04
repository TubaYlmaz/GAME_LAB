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

    // ==========================================
    // 👑 MUHTAR/HOST DEVİR YARDIMCISI (RASTGELE DEVİR)
    // ==========================================
    async function handleHostTransferIfNeeded(roomCode, updatedPlayers) {
        const savedRoom = await redisClient.hgetall(`room:${roomCode}`);
        if (!savedRoom) return updatedPlayers;

        const currentHostName = savedRoom.host;
        const currentHostPlayer = updatedPlayers.find(p => (typeof p === 'object' ? p.name : p) === currentHostName);

        if (currentHostPlayer && currentHostPlayer.isAlive === false) {
            const alivePlayers = updatedPlayers.filter(p => p.isAlive !== false);

            if (alivePlayers.length > 0) {
                const randomIndex = Math.floor(Math.random() * alivePlayers.length);
                const newHost = alivePlayers[randomIndex];
                const newHostName = typeof newHost === 'object' ? newHost.name : newHost;

                updatedPlayers.forEach(p => {
                    if (typeof p === 'object') {
                        p.isHost = (p.name === newHostName);
                    }
                });

                await redisClient.hset(`room:${roomCode}`, 'host', newHostName);
                console.log(`👑 [MUHTAR DEĞİŞTİ] Eski Muhtar (${currentHostName}) öldü. Yeni Muhtar Rastgele Seçildi: ${newHostName}`);

                io.to(roomCode).emit('vk_host_changed', {
                    newHost: newHostName,
                    message: `👑 Muhtar ${currentHostName} hayatını kaybetti! Yeni Muhtar rastgele seçildi: ${newHostName}`
                });
            }
        }
        return updatedPlayers;
    }

    // ==========================================
    // 💾 OYUN KAZANANINI VERİTABANINA KAYDETME YARDIMCISI
    // ==========================================
    async function saveGameWinnerToDb(roomCode, winnerTeam) {
        console.log(`🔍 [LOG - DB] saveGameWinnerToDb tetiklendi. Oda: ${roomCode}, Kazanan: ${winnerTeam}`);
        if (typeof db === 'undefined' || !db) {
            console.warn(`⚠️ [LOG - DB UYARI] db nesnesi tanımsız veya bağlantı yok! Kazanan MySQL'e yazılamadı.`);
            return;
        }
        try {
            const query = `UPDATE rooms SET game_status = 'finished', winner_team = ? WHERE room_code = ?`;
            console.log(`📝 [LOG - SQL] Çalıştırılıyor: ${query} | Parametreler: [${winnerTeam}, ${roomCode}]`);

            const [result] = await db.query(query, [winnerTeam, roomCode]);
            console.log(`🏆 [MySQL] Oda ${roomCode} bitti. Kazanan kaydedildi. Etkilenen satır: ${result.affectedRows}`);
        } catch (err) {
            console.error("❌ [MySQL Error - Kazanan Kaydetme]:", err);
        }
    }

    // ==========================================
    // 🛠️ ROL DAĞITIM VE KURALLAR YARDIMCISI
    // ==========================================
    async function distributeAndSaveRoles(roomCode) {
        console.log(`🔍 [LOG - ROL] distributeAndSaveRoles başladı. Oda: ${roomCode}`);
        const savedRoom = await redisClient.hgetall(`room:${roomCode}`);
        if (!savedRoom || !savedRoom.players) {
            console.warn(`⚠️ [LOG - ROL UYARI] Oda Redis'te bulunamadı veya oyuncu listesi boş! Oda: ${roomCode}`);
            return { error: "Oda bulunamadı!" };
        }

        let players = JSON.parse(savedRoom.players || '[]');
        console.log(`👥 [LOG - ROL] Dağıtım yapılacak oyuncu sayısı: ${players.length}`);

        if (players.length < 3) {
            console.warn(`⚠️ [LOG - ROL UYARI] Oyuncu sayısı yetersiz (<3): ${players.length}`);
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

        await redisClient.hset(`room:${roomCode}`, 'status', 'started');
        await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(updatedPlayers));
        console.log(`✅ [LOG - REDIS] Roller ve oyun durumu Redis'e kaydedildi.`);

        // 🎯 MySQL: Dağıtılan rolleri ve oyun durumunu güncelle (Log kontrollü)
        if (typeof db === 'undefined' || !db) {
            console.warn(`⚠️ [LOG - DB UYARI] db nesnesi tanımsız! Roller MySQL'e yazılamadı.`);
        } else {
            try {
                console.log(`📝 [LOG - SQL] Oyuncu rolleri MySQL'e işleniyor... Toplam oyuncu: ${updatedPlayers.length}`);
                for (const p of updatedPlayers) {
                    await db.query(
                        `INSERT INTO players (room_code, player_name, role, is_alive, is_host) 
                         VALUES (?, ?, ?, ?, ?)
                         ON DUPLICATE KEY UPDATE role = VALUES(role), is_alive = VALUES(is_alive), is_host = VALUES(is_host)`,
                        [roomCode, p.name, p.role, p.isAlive, p.isHost]
                    );
                }
                await db.query(`UPDATE rooms SET game_status = ? WHERE room_code = ?`, ['playing', roomCode]);
                console.log(`✅ [LOG - SQL] Tüm roller ve oda durumu ('playing') MySQL veritabanına başarıyla yazıldı.`);
            } catch (dbErr) {
                console.error("❌ [MySQL Error - Roller Yazılamadı]:", dbErr);
            }
        }

        return { success: true, players: updatedPlayers };
    }

    // ==========================================
    // 🚀 SOKET EVENT DİNLEYİCİLERİ
    // ==========================================
    io.on('connection', (socket) => {

        socket.on('vk_create_room', async (data) => {
            const { roomCode, hostName, gender, vampireCount, doctorCount, serialKillerCount, villagerCount } = data;
            console.log(`📥 [LOG - SOCKET] 'vk_create_room' alındı. Oda: ${roomCode}, Host: ${hostName}`);

            const initialPlayers = [{ name: hostName, gender: gender || 'male', isHost: true }];

            const roomData = {
                host: hostName,
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
            await redisClient.expire(`room:${roomCode}`, 7200);
            await redisClient.sadd(`room:${roomCode}:returned_players`, hostName.trim());
            console.log(`✅ [LOG - REDIS] Oda ${roomCode} için Redis kayıtları oluşturuldu.`);

            if (typeof db === 'undefined' || !db) {
                console.warn(`⚠️ [LOG - DB UYARI] db nesnesi tanımsız! Oda MySQL'e kaydedilemedi.`);
            } else {
                try {
                    console.log(`📝 [LOG - SQL] Oda ve Host MySQL'e kaydediliyor...`);
                    await db.query(
                        `INSERT INTO rooms (room_code, game_status) VALUES (?, ?)
                         ON DUPLICATE KEY UPDATE game_status = VALUES(game_status)`,
                        [roomCode, 'waiting']
                    );
                    await db.query(
                        `INSERT INTO players (room_code, player_name, role, is_host, is_alive) 
                         VALUES (?, ?, 'Köylü 🧑‍🌾', true, true)
                         ON DUPLICATE KEY UPDATE is_host = TRUE, is_alive = TRUE`,
                        [roomCode, hostName]
                    );
                    console.log(`✅ [LOG - SQL] Oda (${roomCode}) ve Host (${hostName}) başarıyla MySQL'e yazıldı.`);
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
            console.log(`📥 [LOG - SOCKET] 'vk_join_room' alındı. Oda: ${roomCode}, Oyuncu: ${playerName}`);

            const roomExists = await redisClient.exists(`room:${roomCode}`);
            if (!roomExists) {
                console.warn(`⚠️ [LOG - REDIS UYARI] Katılınmak istenen oda Redis'te bulunamadı! Oda: ${roomCode}`);
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

            const playerExists = playerObjects.some(p => p.name.trim().toLowerCase() === playerName.trim().toLowerCase());

            if (!playerExists) {
                playerObjects.push({
                    name: playerName,
                    gender: gender || 'male',
                    isHost: false,
                    isAlive: true
                });
                console.log(`➕ [LOG] Oyuncu listeye eklendi: ${playerName}`);
            } else {
                console.log(`ℹ️ [LOG] Oyuncu zaten listede varmış: ${playerName}`);
            }

            // MySQL Kaydı / Güncellemesi Her Durumda Garanti Edilir ve Loglanır
            if (typeof db === 'undefined' || !db) {
                console.warn(`⚠️ [LOG - DB UYARI] db nesnesi tanımsız! Oyuncu MySQL'e eklenemedi: ${playerName}`);
            } else {
                try {
                    console.log(`📝 [LOG - SQL] Oyuncu MySQL'e yazılıyor/güncelleniyor: ${playerName} (Oda: ${roomCode})`);
                    await db.query(
                        `INSERT INTO players (room_code, player_name, role, is_host, is_alive) 
                         VALUES (?, ?, 'Köylü 🧑‍🌾', false, true)
                         ON DUPLICATE KEY UPDATE player_name = VALUES(player_name)`,
                        [roomCode, playerName]
                    );
                    console.log(`✅ [LOG - SQL] Oyuncu başarıyla MySQL'e işlendi: ${playerName}`);
                } catch (dbErr) {
                    console.error(`❌ [MySQL Error - Oyuncu Eklenemedi (${playerName})]:`, dbErr);
                }
            }

            await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(playerObjects));

            socket.join(roomCode);
            console.log(`🏃‍♂️ ${playerName} (${gender}), ${roomCode} odasına katıldı.`);

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
            let players = JSON.parse(roomData.players || '[]');
            const { returnedPlayers, isEveryoneBack } = await getLobbyReturnStatus(roomCode, players);

            console.log(`🟢 [LOBİ FLAG] ${playerName} lobiye döndü. Hazır olanlar: ${returnedPlayers.length}/${players.length}`);

            io.to(roomCode).emit('vk_lobby_status_updated', {
                totalPlayersCount: players.length,
                returnedPlayers: returnedPlayers
            });
            io.to(roomCode).emit('lobby_return_status', {
                returnedPlayers: returnedPlayers,
                isEveryoneBack: isEveryoneBack
            });
        });

        // 🎯 KESİNTİSİZ VE GARANTİLİ YENİ EL BAŞLATMA
        socket.on('vk_start_game', async (data) => {
            const { roomCode } = data;
            if (!roomCode) return;

            console.log(`📥 [LOG - SOCKET] 'vk_start_game' tetiklendi. Oda: ${roomCode}`);
            const roomKey = `room:${roomCode}`;

            const roomData = await redisClient.hgetall(roomKey);
            if (!roomData || !roomData.players) {
                console.warn(`⚠️ [LOG - UYARI] Başlatılmak istenen odanın verisi Redis'te bulunamadı! Oda: ${roomCode}`);
                socket.emit('vk_start_game_error', { message: 'Oda verisi bulunamadı!' });
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

            // Every new round starts from a clean game state, then roles are shuffled again.
            await redisClient.del(`${roomKey}:vk_votes`);
            await redisClient.del(`${roomKey}:vk_locked_votes`);
            await redisClient.del(`${roomKey}:returned_players`);
            await redisClient.del(`${roomKey}:roles_seen_players`);
            delete nightVotes[roomCode];

            const result = await distributeAndSaveRoles(roomCode);

            if (result.error) {
                console.warn(`⚠️ [LOG - UYARI] Oyun başlatılamadı hatası: ${result.error}`);
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
            const cleanName = playerName.toString().trim().toLowerCase();

            await redisClient.sadd(`${roomKey}:roles_seen_players`, cleanName);

            const roomData = await redisClient.hgetall(roomKey);
            if (!roomData || !roomData.players) return;

            let players = JSON.parse(roomData.players || '[]');
            const seenPlayers = await redisClient.smembers(`${roomKey}:roles_seen_players`) || [];

            console.log(`🃏 [ROL ONAYI] Oda: ${roomCode} | Oyuncu: ${playerName} (${seenPlayers.length}/${players.length})`);

            if (seenPlayers.length >= players.length) {
                console.log(`🚀 [OYUN BAŞLIYOR] Tüm oyuncular rolünü onayladı! Kartlar kapatılıyor...`);
                await redisClient.del(`${roomKey}:roles_seen_players`);
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
        // ==========================================
        // 🌙 GECE AKSİYONLARI VE ZAFER KONTROLÜ
        // ==========================================
        socket.on('submit_night_action', async (data) => {
            const { roomCode, playerName, role, target } = data;

            if (!nightVotes[roomCode]) {
                nightVotes[roomCode] = {
                    vampires: {},
                    killers: {},
                    doctors: {},
                    mathSolvedPlayers: []
                };
            }

            const roomData = await redisClient.hgetall(`room:${roomCode}`);
            const players = JSON.parse(roomData.players || '[]');
            const alivePlayers = players.filter(p => p.isAlive !== false);

            const rStr = role ? role.toString().toLowerCase() : '';

            if (rStr.includes('vampir')) {
                nightVotes[roomCode].vampires[playerName] = target;
            } else if (rStr.includes('seri') || rStr.includes('katil')) {
                nightVotes[roomCode].killers[playerName] = target;
            } else if (rStr.includes('doktor')) {
                nightVotes[roomCode].doctors[playerName] = target;
            } else {
                if (!nightVotes[roomCode].mathSolvedPlayers.includes(playerName)) {
                    nightVotes[roomCode].mathSolvedPlayers.push(playerName);
                }
            }

            const vampireChoices = Object.values(nightVotes[roomCode].vampires);
            const uniqueVampireTargets = [...new Set(vampireChoices)];
            const totalVampiresInGame = alivePlayers.filter(p => p.role && p.role.toLowerCase().includes('vampir')).length;

            if (totalVampiresInGame > 0 && vampireChoices.length === totalVampiresInGame && uniqueVampireTargets.length > 1) {
                io.to(roomCode).emit('night_action_error', {
                    roleTarget: 'Vampir',
                    message: '⚠️ Vampirler anlaşamadı! Aynı kişiyi seçene kadar gece bitmeyecek.'
                });
                nightVotes[roomCode].vampires = {};
                return;
            }

            const killerChoices = Object.values(nightVotes[roomCode].killers);
            const uniqueKillerTargets = [...new Set(killerChoices)];
            const totalKillersInGame = alivePlayers.filter(p => p.role && (p.role.toLowerCase().includes('seri') || p.role.toLowerCase().includes('katil'))).length;

            if (totalKillersInGame > 0 && killerChoices.length === totalKillersInGame && uniqueKillerTargets.length > 1) {
                io.to(roomCode).emit('night_action_error', {
                    roleTarget: 'Seri Katil',
                    message: '⚠️ Seri katiller anlaşamadı! Ortak hedef seçmelisiniz.'
                });
                nightVotes[roomCode].killers = {};
                return;
            }

            socket.emit('action_confirmed', {
                message: 'Kararın onaylandı, diğer oyuncuların işlemleri tamamlanması bekleniyor...'
            });

            const totalActivePlayers = alivePlayers.length;
            const totalActionsReceived =
                Object.keys(nightVotes[roomCode].vampires).length +
                Object.keys(nightVotes[roomCode].killers).length +
                Object.keys(nightVotes[roomCode].doctors).length +
                nightVotes[roomCode].mathSolvedPlayers.length;

            io.to(roomCode).emit('night_progress_update', {
                completedCount: totalActionsReceived,
                totalCount: totalActivePlayers
            });

            if (totalActionsReceived >= totalActivePlayers) {
                const finalVampireTarget = uniqueVampireTargets[0] || null;
                const finalDoctorTarget = Object.values(nightVotes[roomCode].doctors)[0] || null;
                const finalKillerTarget = uniqueKillerTargets[0] || null;

                let rawDeadTargets = [];

                if (finalKillerTarget) {
                    rawDeadTargets.push(finalKillerTarget.toString().trim().toLowerCase());
                }

                if (finalVampireTarget && finalVampireTarget !== finalDoctorTarget) {
                    const cleanVampTarget = finalVampireTarget.toString().trim().toLowerCase();
                    if (!rawDeadTargets.includes(cleanVampTarget)) {
                        rawDeadTargets.push(cleanVampTarget);
                    }
                }

                let actualDeadNames = [];

                let updatedPlayers = players.map(p => {
                    const pNameClean = (typeof p === 'object' ? p.name : p).toString().trim().toLowerCase();
                    if (rawDeadTargets.includes(pNameClean)) {
                        actualDeadNames.push(typeof p === 'object' ? p.name : p);
                        return { ...p, isAlive: false };
                    }
                    return p;
                });

                updatedPlayers = await handleHostTransferIfNeeded(roomCode, updatedPlayers);
                await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(updatedPlayers));

                if (typeof db !== 'undefined' && db) {
                    try {
                        for (const deadName of actualDeadNames) {
                            await db.query(
                                'UPDATE players SET is_alive = FALSE WHERE room_code = ? AND player_name = ?',
                                [roomCode, deadName]
                            );
                        }
                    } catch (dbErr) {
                        console.error("❌ [MySQL Error - Ölenler Güncellenemedi]:", dbErr);
                    }
                }

                io.to(roomCode).emit('night_results', {
                    deadPlayers: actualDeadNames,
                    message: actualDeadNames.length > 0
                        ? `Sabah oldu! Gece kurbanı / kurbanları: ${actualDeadNames.join(', ')} 💀`
                        : "Mucize! Doktor köyü korumayı başardı, gece kimse ölmedi. 🩺"
                });
                io.to(roomCode).emit('vk_players_updated', updatedPlayers);

                // 🎯 YENİ KÖTÜ / İYİ SAVAŞI ZAFER HESAPLAMASI
                const updatedAlive = updatedPlayers.filter(p => p.isAlive !== false);
                const evilCount = updatedAlive.filter(p => isEvilPlayer(p)).length;
                const goodCount = updatedAlive.filter(p => !isEvilPlayer(p)).length;

                console.log(`🌅 [SABAH ZAFER KONTROLÜ] Oda: ${roomCode} | Kalan Kötü: ${evilCount} | Kalan İyi: ${goodCount}`);

                if (evilCount === 0) {
                    console.log(">>> EMIT GAME OVER (KÖYLÜLER KAZANDI)");
                    await saveGameWinnerToDb(roomCode, 'KÖYLÜLER');
                    await redisClient.hset(`room:${roomCode}`, 'status', 'finished');

                    io.to(roomCode).emit('vk_game_over', {
                        winner: 'KÖYLÜLER',
                        eliminatedPlayer: actualDeadNames.join(', ') || 'Kötüler'
                    });

                    delete nightVotes[roomCode];
                    return; // 🎯 <<< EN ÖNEMLİ SATIR (RETURN)
                } else if (evilCount >= goodCount) {
                    console.log(">>> EMIT GAME OVER (VAMPİRLER KAZANDI)");
                    await saveGameWinnerToDb(roomCode, 'VAMPİRLER');
                    await redisClient.hset(`room:${roomCode}`, 'status', 'finished');

                    io.to(roomCode).emit('vk_game_over', {
                        winner: 'VAMPİRLER',
                        eliminatedPlayer: actualDeadNames.join(', ') || 'Köy Kurbanı'
                    });

                    delete nightVotes[roomCode];
                    return; // 🎯 <<< EN ÖNEMLİ SATIR (RETURN)
                }

                delete nightVotes[roomCode];
            }
        });

        // ==========================================
        // 🔄 FAZ DEĞİŞİM DİNLENİCİSİ
        // ==========================================
        socket.on('vk_change_phase', async (data) => {
            const { roomCode, nextPhase } = data;

            // 🎯 ODA KONTROLÜ: Eğer oyun bittiyse (status === 'finished') faz değişimini tamamen kitle!
            const savedRoom = await redisClient.hgetall(`room:${roomCode}`);
            if (savedRoom && savedRoom.status === 'finished') {
                console.log(`⛔ [FAZ ENGLLENDİ] Oda ${roomCode} bittiği için "${nextPhase}" fazına geçiş isteği REDDEDİLDİ.`);
                return; // 🎯 <<< OYUN BİTTİYSE FAZ DEĞİŞTİRME RETURN'Ü
            }

            console.log(`🔄 [FAZ TETİKLENDİ] Oda: ${roomCode} | Faz: ${nextPhase}`);

            if (nextPhase === 'night') {
                nightVotes[roomCode] = {
                    vampires: {},
                    killers: {},
                    doctors: {},
                    mathSolvedPlayers: []
                };
            }

            if (nextPhase === 'voting') {
                console.log(">>> EMIT VOTING");
                io.to(roomCode).emit('vk_navigate_to_voting');
            } else {
                console.log(`>>> EMIT DAY / PHASE: ${nextPhase}`);
                io.to(roomCode).emit('vk_phase_changed', { phase: nextPhase });
            }
        });

        socket.on('vk_submit_vote', async (data) => {
            const { roomCode, voterName, votedTargetName, votedFor, isLocking } = data;
            const actualTarget = votedTargetName || votedFor;

            const voteKey = `room:${roomCode}:vk_votes`;
            const lockKey = `room:${roomCode}:vk_locked_votes`;

            if (actualTarget) {
                await redisClient.hset(voteKey, voterName, actualTarget);
            }

            if (isLocking) {
                await redisClient.sadd(lockKey, voterName);
            }

            const roomData = await redisClient.hgetall(`room:${roomCode}`);
            let players = JSON.parse(roomData.players || '[]');
            const alivePlayers = players.filter(p => p.isAlive !== false);

            const currentVotes = await redisClient.hgetall(voteKey) || {};
            const lockedPlayers = await redisClient.smembers(lockKey) || [];

            io.to(roomCode).emit('vk_vote_status_updated', {
                votedCount: lockedPlayers.length,
                totalPlayers: alivePlayers.length,
                currentVotes: currentVotes,
                lockedPlayers: lockedPlayers
            });

            io.to(roomCode).emit('vk_vote_progress', {
                votedCount: lockedPlayers.length,
                totalAlive: alivePlayers.length,
                currentVotes: currentVotes
            });

            if (lockedPlayers.length >= alivePlayers.length) {
                const voteCounts = {};
                alivePlayers.forEach(p => {
                    const pName = typeof p === 'object' ? p.name : p;
                    voteCounts[pName.trim()] = 0;
                });

                Object.entries(currentVotes).forEach(([voter, voted]) => {
                    if (voted && voted !== 'skip') {
                        const targetClean = voted.toString().trim();
                        const matchedKey = Object.keys(voteCounts).find(
                            k => k.toLowerCase() === targetClean.toLowerCase()
                        );
                        if (matchedKey) {
                            voteCounts[matchedKey]++;
                        }
                    }
                });

                let eliminatedPlayerName = null;
                let eliminatedPlayerObj = null;
                let maxVotes = 0;
                let isTie = false;

                Object.entries(voteCounts).forEach(([player, count]) => {
                    if (count > maxVotes) {
                        maxVotes = count;
                        eliminatedPlayerName = player;
                        isTie = false;
                    } else if (count === maxVotes && count > 0) {
                        isTie = true;
                    }
                });

                if (isTie) {
                    eliminatedPlayerName = null;
                }

                let isVampire = false;

                if (eliminatedPlayerName) {
                    players = players.map(p => {
                        const pName = typeof p === 'object' ? p.name : p;
                        if (pName && pName.toString().trim().toLowerCase() === eliminatedPlayerName.toString().trim().toLowerCase()) {
                            eliminatedPlayerObj = typeof p === 'object' ? p : { name: p, role: 'Köylü 🧑‍🌾' };
                            isVampire = !!eliminatedPlayerObj.isVampire || (eliminatedPlayerObj.role && eliminatedPlayerObj.role.toLowerCase().includes('vampir'));
                            return { ...eliminatedPlayerObj, isAlive: false };
                        }
                        return p;
                    });

                    players = await handleHostTransferIfNeeded(roomCode, players);
                    await redisClient.hset(`room:${roomCode}`, 'players', JSON.stringify(players));

                    // MySQL'de oylama ile elenen oyuncunun is_alive durumunu false yap (Log kontrollü)
                    if (typeof db === 'undefined' || !db) {
                        console.warn(`⚠️ [LOG - DB UYARI] db tanımsız! Elenen oyuncu MySQL'de güncellenemedi: ${eliminatedPlayerName}`);
                    } else {
                        try {
                            console.log(`📝 [LOG - SQL] Oylama ile elenen oyuncu MySQL'de güncelleniyor: ${eliminatedPlayerName}`);
                            await db.query(
                                'UPDATE players SET is_alive = FALSE WHERE room_code = ? AND player_name = ?',
                                [roomCode, eliminatedPlayerName]
                            );
                            console.log(`✅ [LOG - SQL] Elenen oyuncu MySQL'de güncellendi: ${eliminatedPlayerName}`);
                        } catch (dbErr) {
                            console.error("❌ [MySQL Error - Elenen Oyuncu Güncellenemedi]:", dbErr);
                        }
                    }
                }

                await redisClient.del(voteKey);
                await redisClient.del(lockKey);

                // 🎯 YENİ KÖTÜ / İYİ SAVAŞI ZAFER HESAPLAMASI
                const updatedAlive = players.filter(p => p.isAlive !== false);

                // Kötüler: Vampir + Seri Katil
                const evilCount = updatedAlive.filter(p => isEvilPlayer(p)).length;

                // İyiler: Doktor + Köylü
                const goodCount = updatedAlive.filter(p => !isEvilPlayer(p)).length;

                console.log(`📊 [VK OYLAMA SONUCU] Elenen: ${eliminatedPlayerName} | Kalan Kötü: ${evilCount} | Kalan İyi: ${goodCount}`);

                if (evilCount === 0) {
                    await saveGameWinnerToDb(roomCode, 'KÖYLÜLER');
                    io.to(roomCode).emit('vk_game_over', {
                        winner: 'KÖYLÜLER',
                        eliminatedPlayer: eliminatedPlayerName
                    });
                    return; // 🎯 Zafer ilan edildiyse oylama bitti, devam etme!
                } else if (evilCount >= goodCount) {
                    await saveGameWinnerToDb(roomCode, 'VAMPİRLER');
                    io.to(roomCode).emit('vk_game_over', {
                        winner: 'VAMPİRLER',
                        eliminatedPlayer: eliminatedPlayerName
                    });
                    return; // 🎯 Zafer ilan edildiyse oylama bitti, devam etme!
                } else {
                    io.to(roomCode).emit('vk_voting_results', {
                        eliminatedPlayer: eliminatedPlayerName,
                        eliminatedRole: eliminatedPlayerObj ? eliminatedPlayerObj.role : null,
                        isTie: isTie,
                        isVampire: isVampire,
                        players: players
                    });
                    io.to(roomCode).emit('vk_round_ended', {
                        eliminatedPlayer: eliminatedPlayerName,
                        eliminatedRole: eliminatedPlayerObj ? eliminatedPlayerObj.role : null,
                        isTie: isTie,
                        isVampire: isVampire,
                        players: players
                    });
                }

                io.to(roomCode).emit('vk_players_updated', players);
            }
        });

    });

    // ==========================================
    // 🏁 API ENDPOINT'LERİ
    // ==========================================
    app.post('/api/vk/start-game', async (req, res) => {
        try {
            const { roomCode } = req.body;
            console.log(`📥 [LOG - API] POST /api/vk/start-game çağrıldı. Oda: ${roomCode}`);
            const result = await distributeAndSaveRoles(roomCode);

            if (result.error) {
                return res.status(400).json({ error: result.error });
            }

            const updatedPlayers = result.players;

            io.to(roomCode).emit('vk_game_started', { players: updatedPlayers });
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
