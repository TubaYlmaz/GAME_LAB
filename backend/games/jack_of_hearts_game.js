/**
 * Alice in Borderland: Kupa Valesi (Jack of Hearts).
 *
 * Redis holds the authoritative room state. Timers never carry game state;
 * they only ask Redis to advance the currently active phase.
 */
module.exports = function ({ io, redisClient }) {
    const GAME_ID = 'jack_of_hearts';
    const DISCUSSION_MS = 180000;
    const CELL_MS = 20000;
    const RESULT_MS = 3000;
    const SYMBOLS = ['\u2665', '\u2660', '\u2666', '\u2663'];
    const timers = new Map();
    const evaluating = new Set();
    const advancingResults = new Set();
    const advancingDiscussions = new Set();
    const advancingCells = new Set();

    const roomKey = code => `room:${code}`;
    const returnedPlayersKey = code => `room:${code}:jh_returned_to_lobby`;
    const createMatchId = () => `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    const cleanCode = value => String(value || '').trim().toUpperCase();
    const cleanName = value => String(value || '').trim();
    const nameKey = value => cleanName(value).toLocaleLowerCase('tr-TR');
    const isValidCode = code => /^\d{6}$/.test(code);
    const isValidName = name => name.length >= 2 && name.length <= 24;
    const isRoomMember = (socket, roomCode) => socket.data.jhRoomCode === roomCode;
    const parsePlayers = room => {
        try {
            const players = JSON.parse(room.players || '[]');
            return Array.isArray(players) ? players : [];
        } catch (_) {
            return [];
        }
    };

    function clearTimers(roomCode) {
        const active = timers.get(roomCode);
        if (!active) return;
        Object.values(active).forEach(timer => timer && clearTimeout(timer));
        timers.delete(roomCode);
    }

    function setTimer(roomCode, key, delay, task) {
        const active = timers.get(roomCode) || {};
        if (active[key]) clearTimeout(active[key]);
        active[key] = setTimeout(() => {
            const latest = timers.get(roomCode);
            if (latest) delete latest[key];
            task().catch(error => console.error(`[JH] ${key} timer failed:`, error));
        }, Math.max(0, delay));
        timers.set(roomCode, active);
    }

    function publicPlayersFor(playerName, players) {
        const me = nameKey(playerName);
        return players.map(player => {
            const isMe = nameKey(player.name) === me;
            return {
                name: player.name,
                gender: player.gender || 'male',
                isHost: player.isHost === true,
                isAlive: player.isAlive !== false,
                // Zero knowledge: my own neck card is always hidden from me.
                symbol: isMe ? null : (player.symbol || null),
                // The Jack identity must never leak in normal state packets.
                role: isMe ? (player.role || null) : null
            };
        });
    }

    async function emitLobby(roomCode) {
        const room = await redisClient.hgetall(roomKey(roomCode));
        if (!room || room.game !== GAME_ID) return;
        const players = parsePlayers(room);
        const returned = new Set((await redisClient.smembers(returnedPlayersKey(roomCode))).map(nameKey));
        const returnedPlayers = players
            .filter(player => returned.has(nameKey(player.name)))
            .map(player => player.name);
        const lobbyIsReady = room.status === 'waiting' && room.phase === 'lobby';
        const publicPlayers = players.map(player => ({
            name: player.name,
            gender: player.gender || 'male',
            isHost: player.isHost === true,
            isAlive: player.isAlive !== false,
            isInLobby: lobbyIsReady || returned.has(nameKey(player.name))
        }));
        io.to(roomCode).emit('jh_room_updated', {
            roomCode,
            host: room.host,
            status: room.status || 'waiting',
            phase: room.phase || 'lobby',
            players: publicPlayers,
            returnedPlayers,
            returnedCount: returnedPlayers.length,
            totalPlayers: players.length,
            allPlayersReturned: lobbyIsReady
        });
    }

    async function emitState(socket, roomCode, existingRoom) {
        const room = existingRoom || await redisClient.hgetall(roomKey(roomCode));
        if (!room || room.game !== GAME_ID) return;
        const players = parsePlayers(room);
        const alive = players.filter(player => player.isAlive !== false);
        const [readyPlayers, lockedPlayers, returned] = await Promise.all([
            redisClient.smembers(`room:${roomCode}:jh_ready`),
            redisClient.smembers(`room:${roomCode}:jh_locked_guesses`),
            redisClient.smembers(returnedPlayersKey(roomCode))
        ]);
        const returnedNames = new Set(returned.map(nameKey));
        const returnedPlayers = players
            .filter(player => returnedNames.has(nameKey(player.name)))
            .map(player => player.name);
        socket.emit('jh_game_state', {
            roomCode,
            matchId: room.matchId || null,
            serverNow: Date.now(),
            status: room.status || 'waiting',
            phase: room.phase || 'lobby',
            round: Number(room.round || 0),
            discussionEndsAt: Number(room.discussionEndsAt || 0),
            cellEndsAt: Number(room.cellEndsAt || 0),
            resultEndsAt: Number(room.resultEndsAt || 0),
            gameWinner: room.gameWinner || null,
            readyPlayers,
            readyCount: readyPlayers.length,
            lockedPlayers,
            lockedCount: lockedPlayers.length,
            totalAlive: alive.length,
            returnedPlayers,
            returnedCount: returnedPlayers.length,
            totalPlayers: players.length,
            allPlayersReturned: room.status === 'waiting' && room.phase === 'lobby',
            players: publicPlayersFor(socket.data.jhPlayerName, players)
        });
    }

    async function broadcastState(roomCode, room) {
        const sockets = await io.in(roomCode).fetchSockets();
        await Promise.all(
            sockets
                .filter(socket => socket.data.jhRoomCode === roomCode)
                .map(socket => emitState(socket, roomCode, room))
        );
    }

    function randomiseSymbols(players) {
        return players.map(player => ({
            ...player,
            symbol: player.isAlive === false
                ? null
                : SYMBOLS[Math.floor(Math.random() * SYMBOLS.length)]
        }));
    }

    async function beginDiscussion(roomCode, { initial = false, expectedMatchId = null } = {}) {
        if (advancingDiscussions.has(roomCode)) return false;
        advancingDiscussions.add(roomCode);
        try {
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID || room.status !== 'started') return false;
            if (expectedMatchId && room.matchId !== expectedMatchId) return false;
            if (initial && room.phase !== 'setup') return false;
            if (!initial && room.phase !== 'result') return false;

            const round = initial ? 1 : Number(room.round || 0) + 1;
            const matchId = room.matchId;
            const discussionEndsAt = Date.now() + DISCUSSION_MS;
            const players = randomiseSymbols(parsePlayers(room));
            await redisClient.multi()
                .hset(roomKey(roomCode), 'players', JSON.stringify(players))
                .hset(roomKey(roomCode), 'phase', 'discussion')
                .hset(roomKey(roomCode), 'round', String(round))
                .hset(roomKey(roomCode), 'discussionEndsAt', String(discussionEndsAt))
                .hset(roomKey(roomCode), 'cellEndsAt', '0')
                .hdel(roomKey(roomCode), 'resultEndsAt')
                .del(`room:${roomCode}:jh_ready`)
                .del(`room:${roomCode}:jh_guesses`)
                .del(`room:${roomCode}:jh_locked_guesses`)
                .exec();

            setTimer(roomCode, 'discussion', discussionEndsAt - Date.now(), () =>
                recoverActivePhase(roomCode, matchId)
            );
            io.to(roomCode).emit('jh_phase_changed', {
                phase: 'discussion',
                round,
                discussionEndsAt,
                matchId,
                serverNow: Date.now()
            });
            await broadcastState(roomCode);
            return true;
        } finally {
            advancingDiscussions.delete(roomCode);
        }
    }

    async function advanceResult(roomCode, expectedMatchId = null) {
        if (advancingResults.has(roomCode)) return false;
        advancingResults.add(roomCode);
        try {
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'result') return false;
            if (expectedMatchId && room.matchId !== expectedMatchId) return false;

            const resultEndsAt = Number(room.resultEndsAt || 0);
            if (!Number.isFinite(resultEndsAt) || resultEndsAt <= 0) {
                return beginDiscussion(roomCode, { expectedMatchId: room.matchId });
            }
            const remaining = resultEndsAt - Date.now();
            if (remaining > 0) {
                setTimer(roomCode, 'result', remaining, () =>
                    recoverActivePhase(roomCode, room.matchId)
                );
                return false;
            }
            return beginDiscussion(roomCode, { expectedMatchId: room.matchId });
        } finally {
            advancingResults.delete(roomCode);
        }
    }

    async function recoverActivePhase(roomCode, expectedMatchId = null) {
        const room = await redisClient.hgetall(roomKey(roomCode));
        if (!room || room.game !== GAME_ID || room.status !== 'started') return false;
        if (expectedMatchId && room.matchId !== expectedMatchId) return false;

        const matchId = room.matchId;
        if (room.phase === 'setup') {
            return beginDiscussion(roomCode, { initial: true, expectedMatchId: matchId });
        }
        if (room.phase === 'discussion') {
            const remaining = Number(room.discussionEndsAt || 0) - Date.now();
            if (remaining > 0) {
                setTimer(roomCode, 'discussion', remaining, () =>
                    recoverActivePhase(roomCode, matchId)
                );
                return false;
            }
            return beginCell(roomCode, 'timer', matchId);
        }
        if (room.phase === 'cell') {
            const remaining = Number(room.cellEndsAt || 0) - Date.now();
            if (remaining > 0) {
                setTimer(roomCode, 'cell', remaining, () =>
                    recoverActivePhase(roomCode, matchId)
                );
                return false;
            }
            return evaluateRound(roomCode, 'timer', matchId);
        }
        if (room.phase === 'result') {
            return advanceResult(roomCode, matchId);
        }
        return false;
    }

    async function beginCell(roomCode, reason, expectedMatchId = null) {
        if (advancingCells.has(roomCode)) return false;
        advancingCells.add(roomCode);
        try {
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'discussion') return false;
            if (expectedMatchId && room.matchId !== expectedMatchId) return false;
            if (reason === 'timer' && Date.now() < Number(room.discussionEndsAt || 0)) return false;
            const matchId = room.matchId;

            const cellEndsAt = Date.now() + CELL_MS;
            const active = timers.get(roomCode);
            if (active && active.discussion) {
                clearTimeout(active.discussion);
                delete active.discussion;
            }
            await redisClient.multi()
                .hset(roomKey(roomCode), 'phase', 'cell')
                .hset(roomKey(roomCode), 'cellEndsAt', String(cellEndsAt))
                .del(`room:${roomCode}:jh_guesses`)
                .del(`room:${roomCode}:jh_locked_guesses`)
                .exec();

            setTimer(roomCode, 'cell', cellEndsAt - Date.now(), () =>
                recoverActivePhase(roomCode, matchId)
            );
            io.to(roomCode).emit('jh_phase_changed', {
                phase: 'cell',
                cellEndsAt,
                matchId,
                reason,
                serverNow: Date.now()
            });
            await broadcastState(roomCode);
            return true;
        } finally {
            advancingCells.delete(roomCode);
        }
    }

    async function finishGame(roomCode, winner, eliminated, expectedMatchId = null) {
        const room = await redisClient.hgetall(roomKey(roomCode));
        if (!room || room.game !== GAME_ID || room.status === 'finished') return false;
        if (expectedMatchId && room.matchId !== expectedMatchId) return false;
        clearTimers(roomCode);
        const players = parsePlayers(room);
        await redisClient.multi()
            .hset(roomKey(roomCode), 'status', 'finished')
            .hset(roomKey(roomCode), 'phase', 'game_over')
            .hset(roomKey(roomCode), 'gameWinner', winner)
            .del(`room:${roomCode}:jh_ready`)
            .del(`room:${roomCode}:jh_guesses`)
            .del(`room:${roomCode}:jh_locked_guesses`)
            .del(returnedPlayersKey(roomCode))
            .exec();

        io.to(roomCode).emit('jh_game_over', {
            winner,
            eliminated,
            matchId: room.matchId || null,
            serverNow: Date.now(),
            players: players.map(player => ({
                name: player.name,
                gender: player.gender || 'male',
                isHost: player.isHost === true,
                isAlive: player.isAlive !== false,
                role: player.role || 'innocent',
                symbol: player.symbol || null
            }))
        });
        await broadcastState(roomCode);
        return true;
    }

    async function evaluateRound(roomCode, reason, expectedMatchId = null) {
        if (evaluating.has(roomCode)) return false;
        evaluating.add(roomCode);
        try {
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'cell') return false;
            if (expectedMatchId && room.matchId !== expectedMatchId) return false;
            if (reason === 'timer' && Date.now() < Number(room.cellEndsAt || 0)) return false;
            const matchId = room.matchId;

            const guesses = await redisClient.hgetall(`room:${roomCode}:jh_guesses`);
            const locked = new Set((await redisClient.smembers(`room:${roomCode}:jh_locked_guesses`)).map(nameKey));
            const eliminated = [];
            const players = parsePlayers(room).map(player => {
                if (player.isAlive === false) return player;
                const isCorrect = locked.has(nameKey(player.name)) && guesses[player.name] === player.symbol;
                if (isCorrect) return player;
                eliminated.push({
                    name: player.name,
                    role: player.role || 'innocent',
                    symbol: player.symbol || null,
                    reason: locked.has(nameKey(player.name)) ? 'wrong_guess' : 'afk'
                });
                return { ...player, isAlive: false };
            });
            const resultEndsAt = Date.now() + RESULT_MS;
            const active = timers.get(roomCode);
            if (active && active.cell) {
                clearTimeout(active.cell);
                delete active.cell;
            }
            await redisClient.multi()
                .hset(roomKey(roomCode), 'players', JSON.stringify(players))
                .hset(roomKey(roomCode), 'phase', 'result')
                .hset(roomKey(roomCode), 'resultEndsAt', String(resultEndsAt))
                .del(`room:${roomCode}:jh_ready`)
                .del(`room:${roomCode}:jh_guesses`)
                .del(`room:${roomCode}:jh_locked_guesses`)
                .exec();

            const jack = players.find(player => player.role === 'jack');
            const jackAlive = jack && jack.isAlive !== false;
            const innocentAlive = players.filter(player => player.role === 'innocent' && player.isAlive !== false).length;

            // Check the simultaneous-elimination case first.
            if (!jackAlive && innocentAlive === 0) {
                await finishGame(roomCode, 'DRAW', eliminated, matchId);
            } else if (!jackAlive) {
                await finishGame(roomCode, 'INNOCENTS', eliminated, matchId);
            } else if (innocentAlive === 0) {
                await finishGame(roomCode, 'JACK', eliminated, matchId);
            } else {
                setTimer(roomCode, 'result', resultEndsAt - Date.now(), () =>
                    recoverActivePhase(roomCode, matchId)
                );
                io.to(roomCode).emit('jh_round_result', {
                    eliminated,
                    matchId,
                    round: Number(room.round || 1),
                    reason,
                    resultEndsAt
                });
                await broadcastState(roomCode);
            }
            return true;
        } finally {
            evaluating.delete(roomCode);
        }
    }

    const error = (socket, message) => socket.emit('jh_error', { message });

    io.on('connection', socket => {
        socket.on('jh_create_room', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const playerName = cleanName(data && data.playerName);
            const gender = data && data.gender === 'female' ? 'female' : 'male';
            if (!isValidCode(roomCode) || !isValidName(playerName)) {
                return error(socket, 'Ge\u00E7erli bir oda kodu ve 2-24 karakterlik isim girin.');
            }
            if (await redisClient.exists(roomKey(roomCode))) {
                return error(socket, 'Bu oda kodu zaten kullan\u0131l\u0131yor. Yeni bir kod deneyin.');
            }
            const players = [{ name: playerName, gender, isHost: true, isAlive: true, role: null, symbol: null }];
            await redisClient.multi()
                .hmset(roomKey(roomCode), {
                    game: GAME_ID,
                    host: playerName,
                    status: 'waiting',
                    phase: 'lobby',
                    round: '0',
                    players: JSON.stringify(players),
                    createdAt: String(Date.now())
                })
                .expire(roomKey(roomCode), 14400)
                .exec();
            socket.join(roomCode);
            socket.data.jhRoomCode = roomCode;
            socket.data.jhPlayerName = playerName;
            socket.data.jhGender = gender;
            socket.emit('jh_room_created', { roomCode, host: playerName });
            await emitLobby(roomCode);
        });

        socket.on('jh_join_room', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const playerName = cleanName(data && data.playerName);
            const gender = data && data.gender === 'female' ? 'female' : 'male';
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID) return error(socket, 'Oda bulunamad\u0131.');
            if (!isValidName(playerName)) return error(socket, '\u0130sim 2-24 karakter olmal\u0131d\u0131r.');

            const players = parsePlayers(room);
            const knownPlayer = players.find(player => nameKey(player.name) === nameKey(playerName));
            if (!knownPlayer && room.status !== 'waiting') {
                return error(socket, 'Oyun ba\u015flad\u0131; bu odaya yeni oyuncu al\u0131nm\u0131yor.');
            }
            if (!knownPlayer) {
                players.push({ name: playerName, gender, isHost: false, isAlive: true, role: null, symbol: null });
                await redisClient.hset(roomKey(roomCode), 'players', JSON.stringify(players));
            }
            if (socket.data.jhRoomCode && socket.data.jhRoomCode !== roomCode) {
                socket.leave(socket.data.jhRoomCode);
            }
            socket.join(roomCode);
            socket.data.jhRoomCode = roomCode;
            socket.data.jhPlayerName = knownPlayer ? knownPlayer.name : playerName;
            socket.data.jhGender = knownPlayer ? (knownPlayer.gender || gender) : gender;
            socket.emit('jh_room_joined', { roomCode, playerName: socket.data.jhPlayerName });
            await recoverActivePhase(roomCode, room.matchId || null);
            await emitLobby(roomCode);
            await emitState(socket, roomCode);
        });

        socket.on('jh_get_state', async data => {
            const roomCode = cleanCode(data && data.roomCode) || socket.data.jhRoomCode;
            if (roomCode && roomCode === socket.data.jhRoomCode) {
                await recoverActivePhase(roomCode);
                await emitState(socket, roomCode);
            }
        });
        socket.on('jh_leave_room', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!isRoomMember(socket, roomCode)) return error(socket, 'Bu oda için yetkiniz yok.');
            if (!room || room.game !== GAME_ID) return error(socket, 'Oda bulunamadı.');
            if (room.status !== 'waiting' && room.status !== 'finished') {
                return error(socket, 'Oyun devam ederken odadan çıkamazsınız.');
            }

            const leavingName = socket.data.jhPlayerName;
            const remainingPlayers = parsePlayers(room).filter(
                player => nameKey(player.name) !== nameKey(leavingName)
            );
            clearTimers(roomCode);
            if (remainingPlayers.length === 0) {
                await redisClient.multi()
                    .del(roomKey(roomCode))
                    .del(`room:${roomCode}:jh_ready`)
                    .del(`room:${roomCode}:jh_guesses`)
                    .del(`room:${roomCode}:jh_locked_guesses`)
                    .del(returnedPlayersKey(roomCode))
                    .exec();
            } else {
                const currentHost = remainingPlayers.find(
                    player => nameKey(player.name) === nameKey(room.host)
                );
                const nextHost = currentHost || remainingPlayers[0];
                const updatedPlayers = remainingPlayers.map(player => ({
                    ...player,
                    isHost: nameKey(player.name) === nameKey(nextHost.name)
                }));
                await redisClient.srem(returnedPlayersKey(roomCode), leavingName);
                const returned = new Set((await redisClient.smembers(returnedPlayersKey(roomCode))).map(nameKey));
                const allRemainingPlayersReturned =
                    room.status === 'finished' &&
                    updatedPlayers.every(player => returned.has(nameKey(player.name)));
                const transaction = redisClient.multi()
                    .hset(roomKey(roomCode), 'host', nextHost.name)
                    .hset(roomKey(roomCode), 'players', JSON.stringify(updatedPlayers));

                if (allRemainingPlayersReturned) {
                    const lobbyPlayers = updatedPlayers.map(player => ({
                        ...player,
                        isAlive: true,
                        role: null,
                        symbol: null
                    }));
                    transaction
                        .hset(roomKey(roomCode), 'status', 'waiting')
                        .hset(roomKey(roomCode), 'phase', 'lobby')
                        .hset(roomKey(roomCode), 'round', '0')
                        .hset(roomKey(roomCode), 'discussionEndsAt', '0')
                        .hset(roomKey(roomCode), 'cellEndsAt', '0')
                        .hset(roomKey(roomCode), 'players', JSON.stringify(lobbyPlayers))
                        .hdel(roomKey(roomCode), 'gameWinner', 'resultEndsAt', 'matchId')
                        .del(`room:${roomCode}:jh_ready`)
                        .del(`room:${roomCode}:jh_guesses`)
                        .del(`room:${roomCode}:jh_locked_guesses`)
                        .del(returnedPlayersKey(roomCode));
                } else if (room.status === 'waiting') {
                    transaction.del(returnedPlayersKey(roomCode));
                }
                await transaction.exec();
            }

            socket.leave(roomCode);
            socket.data.jhRoomCode = null;
            socket.data.jhPlayerName = null;
            socket.data.jhGender = null;
            socket.emit('jh_left_room', { roomCode });
            if (remainingPlayers.length > 0) {
                await emitLobby(roomCode);
                if (room.status === 'finished') await broadcastState(roomCode);
            }
        });
        socket.on('jh_start_game', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!isRoomMember(socket, roomCode)) return error(socket, 'Bu oda i\u00e7in yetkiniz yok.');
            if (!room || room.game !== GAME_ID) return error(socket, 'Oda bulunamad\u0131.');
            if (room.host !== socket.data.jhPlayerName) return error(socket, 'Oyunu yaln\u0131zca kurucu ba\u015flatabilir.');
            if (room.status !== 'waiting') return error(socket, 'Oyun zaten ba\u015flat\u0131ld\u0131.');
            const players = parsePlayers(room);
            if (players.length < 2) return error(socket, 'Kupa Valesi i\u00E7in en az 2 oyuncu gerekir.');

            const jackIndex = Math.floor(Math.random() * players.length);
            const matchId = createMatchId();
            const assigned = players.map((player, index) => ({
                ...player,
                isAlive: true,
                role: index === jackIndex ? 'jack' : 'innocent',
                symbol: null
            }));
            clearTimers(roomCode);
            await redisClient.multi()
                .hset(roomKey(roomCode), 'status', 'started')
                .hset(roomKey(roomCode), 'phase', 'setup')
                .hset(roomKey(roomCode), 'round', '0')
                .hset(roomKey(roomCode), 'matchId', matchId)
                .hset(roomKey(roomCode), 'players', JSON.stringify(assigned))
                .hdel(roomKey(roomCode), 'gameWinner', 'resultEndsAt')
                .del(`room:${roomCode}:jh_ready`)
                .del(`room:${roomCode}:jh_guesses`)
                .del(`room:${roomCode}:jh_locked_guesses`)
                .del(returnedPlayersKey(roomCode))
                .exec();
            io.to(roomCode).emit('jh_game_started', { roomCode, matchId, serverNow: Date.now() });
            await beginDiscussion(roomCode, { initial: true, expectedMatchId: matchId });
        });

        socket.on('jh_ready_for_cell', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!isRoomMember(socket, roomCode)) return error(socket, 'Bu oda i\u00e7in yetkiniz yok.');
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'discussion') return;
            if (Date.now() >= Number(room.discussionEndsAt || 0)) {
                await recoverActivePhase(roomCode, room.matchId);
                return;
            }
            const players = parsePlayers(room);
            const me = players.find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName));
            if (!me) return error(socket, 'Oyuncu bu odada bulunamadı.');
            if (me.isAlive === false) return error(socket, 'Elendiniz; yalnızca izleyebilirsiniz.');
            await redisClient.sadd(`room:${roomCode}:jh_ready`, me.name);
            const alive = players.filter(player => player.isAlive !== false);
            const readyPlayers = await redisClient.smembers(`room:${roomCode}:jh_ready`);
            io.to(roomCode).emit('jh_ready_status', { readyCount: readyPlayers.length, totalAlive: alive.length, readyPlayers, matchId: room.matchId || null, serverNow: Date.now() });
            await broadcastState(roomCode);
            if (readyPlayers.length >= alive.length) await beginCell(roomCode, 'unanimous_ready', room.matchId);
        });

        socket.on('jh_submit_guess', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const claimedName = cleanName(data && data.playerName);
            const guessSymbol = String(data && data.guessSymbol || '');
            const isLocking = data && data.isLocking === true;
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!isRoomMember(socket, roomCode)) return error(socket, 'Bu oda i\u00e7in yetkiniz yok.');
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'cell') return;
            if (Date.now() >= Number(room.cellEndsAt || 0)) {
                await recoverActivePhase(roomCode, room.matchId);
                return;
            }
            if (claimedName && nameKey(claimedName) !== nameKey(socket.data.jhPlayerName)) {
                return error(socket, 'Yaln\u0131zca kendi tahmininizi g\u00F6nderebilirsiniz.');
            }
            const players = parsePlayers(room);
            const me = players.find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName));
            if (!me) return error(socket, 'Oyuncu bu odada bulunamadı.');
            if (me.isAlive === false) return error(socket, 'Elendiniz; seçim yapamazsınız.');

            const guessesKey = `room:${roomCode}:jh_guesses`;
            const locksKey = `room:${roomCode}:jh_locked_guesses`;
            const locks = new Set((await redisClient.smembers(locksKey)).map(nameKey));
            if (locks.has(nameKey(me.name))) return;
            if (guessSymbol && !SYMBOLS.includes(guessSymbol)) return error(socket, 'Ge\u00E7ersiz sembol se\u00E7imi.');
            if (guessSymbol) await redisClient.hset(guessesKey, me.name, guessSymbol);
            if (isLocking) {
                const selected = guessSymbol || await redisClient.hget(guessesKey, me.name);
                if (!SYMBOLS.includes(selected)) return error(socket, '\u00D6nce bir sembol se\u00E7in.');
                await redisClient.sadd(locksKey, me.name);
            }

            const alive = players.filter(player => player.isAlive !== false);
            const lockedPlayers = await redisClient.smembers(locksKey);
            io.to(roomCode).emit('jh_guess_status', {
                lockedCount: lockedPlayers.length,
                totalAlive: alive.length,
                lockedPlayers,
                matchId: room.matchId || null,
                serverNow: Date.now()
            });
            await broadcastState(roomCode);
            if (lockedPlayers.length >= alive.length) await evaluateRound(roomCode, 'all_locked', room.matchId);
        });

        socket.on('jh_return_to_lobby', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!isRoomMember(socket, roomCode)) return error(socket, 'Bu oda i\u00e7in yetkiniz yok.');
            if (!room || room.game !== GAME_ID) return;
            if (room.status !== 'finished') return;

            const players = parsePlayers(room);
            const me = players.find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName));
            if (!me) return error(socket, 'Oyuncu bu odada bulunamad\u0131.');

            await redisClient.sadd(returnedPlayersKey(roomCode), me.name);
            const returned = new Set((await redisClient.smembers(returnedPlayersKey(roomCode))).map(nameKey));
            const returnedPlayers = players
                .filter(player => returned.has(nameKey(player.name)))
                .map(player => player.name);
            const allPlayersReturned = players.length > 0 && returnedPlayers.length === players.length;

            // Only the player who pressed the button changes screens now.
            // The room resets after every original player has returned.
            socket.emit('jh_lobby_returned', {
                roomCode,
                returnedPlayers,
                returnedCount: returnedPlayers.length,
                totalPlayers: players.length,
                allPlayersReturned
            });

            if (allPlayersReturned) {
                clearTimers(roomCode);
                const lobbyPlayers = players.map(player => ({
                    ...player,
                    isAlive: true,
                    role: null,
                    symbol: null
                }));
                await redisClient.multi()
                    .hset(roomKey(roomCode), 'status', 'waiting')
                    .hset(roomKey(roomCode), 'phase', 'lobby')
                    .hset(roomKey(roomCode), 'round', '0')
                    .hset(roomKey(roomCode), 'discussionEndsAt', '0')
                    .hset(roomKey(roomCode), 'cellEndsAt', '0')
                    .hset(roomKey(roomCode), 'players', JSON.stringify(lobbyPlayers))
                    .hdel(roomKey(roomCode), 'gameWinner', 'resultEndsAt', 'matchId')
                    .del(`room:${roomCode}:jh_ready`)
                    .del(`room:${roomCode}:jh_guesses`)
                    .del(`room:${roomCode}:jh_locked_guesses`)
                    .del(returnedPlayersKey(roomCode))
                    .exec();
            }
            await emitLobby(roomCode);
            await broadcastState(roomCode);
        });
    });
};

