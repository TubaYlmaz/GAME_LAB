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

    const roomKey = code => `room:${code}`;
    const cleanCode = value => String(value || '').trim().toUpperCase();
    const cleanName = value => String(value || '').trim();
    const nameKey = value => cleanName(value).toLocaleLowerCase('tr-TR');
    const isValidCode = code => /^[A-Z0-9]{4,8}$/.test(code);
    const isValidName = name => name.length >= 2 && name.length <= 24;
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
        const players = parsePlayers(room).map(player => ({
            name: player.name,
            gender: player.gender || 'male',
            isHost: player.isHost === true,
            isAlive: player.isAlive !== false
        }));
        io.to(roomCode).emit('jh_room_updated', {
            roomCode,
            host: room.host,
            status: room.status || 'waiting',
            players
        });
    }

    async function emitState(socket, roomCode, existingRoom) {
        const room = existingRoom || await redisClient.hgetall(roomKey(roomCode));
        if (!room || room.game !== GAME_ID) return;
        const players = parsePlayers(room);
        const alive = players.filter(player => player.isAlive !== false);
        const [readyPlayers, lockedPlayers] = await Promise.all([
            redisClient.smembers(`room:${roomCode}:jh_ready`),
            redisClient.smembers(`room:${roomCode}:jh_locked_guesses`)
        ]);
        socket.emit('jh_game_state', {
            roomCode,
            status: room.status || 'waiting',
            phase: room.phase || 'lobby',
            round: Number(room.round || 0),
            discussionEndsAt: Number(room.discussionEndsAt || 0),
            cellEndsAt: Number(room.cellEndsAt || 0),
            readyPlayers,
            readyCount: readyPlayers.length,
            lockedPlayers,
            lockedCount: lockedPlayers.length,
            totalAlive: alive.length,
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

    async function beginDiscussion(roomCode, { initial = false } = {}) {
        const room = await redisClient.hgetall(roomKey(roomCode));
        if (!room || room.game !== GAME_ID || room.status !== 'started') return false;

        const round = initial ? 1 : Number(room.round || 0) + 1;
        const discussionEndsAt = Date.now() + DISCUSSION_MS;
        const players = randomiseSymbols(parsePlayers(room));
        await redisClient.multi()
            .hset(roomKey(roomCode), 'players', JSON.stringify(players))
            .hset(roomKey(roomCode), 'phase', 'discussion')
            .hset(roomKey(roomCode), 'round', String(round))
            .hset(roomKey(roomCode), 'discussionEndsAt', String(discussionEndsAt))
            .hset(roomKey(roomCode), 'cellEndsAt', '0')
            .del(`room:${roomCode}:jh_ready`)
            .del(`room:${roomCode}:jh_guesses`)
            .del(`room:${roomCode}:jh_locked_guesses`)
            .exec();

        setTimer(roomCode, 'discussion', discussionEndsAt - Date.now(), () => beginCell(roomCode, 'timer'));
        io.to(roomCode).emit('jh_phase_changed', { phase: 'discussion', round, discussionEndsAt });
        await broadcastState(roomCode);
        return true;
    }

    async function beginCell(roomCode, reason) {
        const room = await redisClient.hgetall(roomKey(roomCode));
        if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'discussion') return false;

        const cellEndsAt = Date.now() + CELL_MS;
        const active = timers.get(roomCode);
        if (active && active.discussion) clearTimeout(active.discussion);
        await redisClient.multi()
            .hset(roomKey(roomCode), 'phase', 'cell')
            .hset(roomKey(roomCode), 'cellEndsAt', String(cellEndsAt))
            .del(`room:${roomCode}:jh_guesses`)
            .del(`room:${roomCode}:jh_locked_guesses`)
            .exec();

        setTimer(roomCode, 'cell', cellEndsAt - Date.now(), () => evaluateRound(roomCode, 'timer'));
        io.to(roomCode).emit('jh_phase_changed', { phase: 'cell', cellEndsAt, reason });
        await broadcastState(roomCode);
        return true;
    }

    async function finishGame(roomCode, winner, eliminated) {
        const room = await redisClient.hgetall(roomKey(roomCode));
        if (!room || room.game !== GAME_ID || room.status === 'finished') return false;
        clearTimers(roomCode);
        const players = parsePlayers(room);
        await redisClient.multi()
            .hset(roomKey(roomCode), 'status', 'finished')
            .hset(roomKey(roomCode), 'phase', 'game_over')
            .hset(roomKey(roomCode), 'gameWinner', winner)
            .del(`room:${roomCode}:jh_ready`)
            .del(`room:${roomCode}:jh_guesses`)
            .del(`room:${roomCode}:jh_locked_guesses`)
            .exec();

        io.to(roomCode).emit('jh_game_over', {
            winner,
            eliminated,
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

    async function evaluateRound(roomCode, reason) {
        if (evaluating.has(roomCode)) return false;
        evaluating.add(roomCode);
        try {
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'cell') return false;

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
            await redisClient.multi()
                .hset(roomKey(roomCode), 'players', JSON.stringify(players))
                .hset(roomKey(roomCode), 'phase', 'result')
                .del(`room:${roomCode}:jh_ready`)
                .del(`room:${roomCode}:jh_guesses`)
                .del(`room:${roomCode}:jh_locked_guesses`)
                .exec();

            const jack = players.find(player => player.role === 'jack');
            const jackAlive = jack && jack.isAlive !== false;
            const innocentAlive = players.filter(player => player.role === 'innocent' && player.isAlive !== false).length;

            // Check the simultaneous-elimination case first.
            if (!jackAlive && innocentAlive === 0) {
                await finishGame(roomCode, 'DRAW', eliminated);
            } else if (!jackAlive) {
                await finishGame(roomCode, 'INNOCENTS', eliminated);
            } else if (innocentAlive === 0) {
                await finishGame(roomCode, 'JACK', eliminated);
            } else {
                const resultEndsAt = Date.now() + RESULT_MS;
                await redisClient.hset(roomKey(roomCode), 'resultEndsAt', String(resultEndsAt));
                io.to(roomCode).emit('jh_round_result', {
                    eliminated,
                    round: Number(room.round || 1),
                    reason,
                    resultEndsAt
                });
                await broadcastState(roomCode);
                setTimer(roomCode, 'result', RESULT_MS, async () => {
                    const current = await redisClient.hgetall(roomKey(roomCode));
                    if (current && current.status === 'started' && current.phase === 'result') {
                        await beginDiscussion(roomCode);
                    }
                });
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
            socket.join(roomCode);
            socket.data.jhRoomCode = roomCode;
            socket.data.jhPlayerName = knownPlayer ? knownPlayer.name : playerName;
            socket.data.jhGender = knownPlayer ? (knownPlayer.gender || gender) : gender;
            socket.emit('jh_room_joined', { roomCode, playerName: socket.data.jhPlayerName });
            await emitLobby(roomCode);
            await emitState(socket, roomCode);
        });

        socket.on('jh_get_state', async data => {
            const roomCode = cleanCode(data && data.roomCode) || socket.data.jhRoomCode;
            if (roomCode && roomCode === socket.data.jhRoomCode) await emitState(socket, roomCode);
        });

        socket.on('jh_start_game', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID) return error(socket, 'Oda bulunamad\u0131.');
            if (room.host !== socket.data.jhPlayerName) return error(socket, 'Oyunu yaln\u0131zca kurucu ba\u015flatabilir.');
            if (room.status !== 'waiting') return error(socket, 'Oyun zaten ba\u015flat\u0131ld\u0131.');
            const players = parsePlayers(room);
            if (players.length < 2) return error(socket, 'Kupa Valesi i\u00E7in en az 2 oyuncu gerekir.');

            const jackIndex = Math.floor(Math.random() * players.length);
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
                .hset(roomKey(roomCode), 'players', JSON.stringify(assigned))
                .del(`room:${roomCode}:jh_ready`)
                .del(`room:${roomCode}:jh_guesses`)
                .del(`room:${roomCode}:jh_locked_guesses`)
                .exec();
            io.to(roomCode).emit('jh_game_started', { roomCode });
            await beginDiscussion(roomCode, { initial: true });
        });

        socket.on('jh_ready_for_cell', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'discussion') return;
            const players = parsePlayers(room);
            const me = players.find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName));
            if (!me || me.isAlive === false) return;
            await redisClient.sadd(`room:${roomCode}:jh_ready`, me.name);
            const alive = players.filter(player => player.isAlive !== false);
            const readyPlayers = await redisClient.smembers(`room:${roomCode}:jh_ready`);
            io.to(roomCode).emit('jh_ready_status', { readyCount: readyPlayers.length, totalAlive: alive.length, readyPlayers });
            await broadcastState(roomCode);
            if (readyPlayers.length >= alive.length) await beginCell(roomCode, 'unanimous_ready');
        });

        socket.on('jh_submit_guess', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const claimedName = cleanName(data && data.playerName);
            const guessSymbol = String(data && data.guessSymbol || '');
            const isLocking = data && data.isLocking === true;
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'cell') return;
            if (claimedName && nameKey(claimedName) !== nameKey(socket.data.jhPlayerName)) {
                return error(socket, 'Yaln\u0131zca kendi tahmininizi g\u00F6nderebilirsiniz.');
            }
            const players = parsePlayers(room);
            const me = players.find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName));
            if (!me || me.isAlive === false) return;

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
                lockedPlayers
            });
            await broadcastState(roomCode);
            if (lockedPlayers.length >= alive.length) await evaluateRound(roomCode, 'all_locked');
        });

        socket.on('jh_return_to_lobby', async data => {
            const roomCode = cleanCode(data && data.roomCode);
            const room = await redisClient.hgetall(roomKey(roomCode));
            if (!room || room.game !== GAME_ID) return;
            clearTimers(roomCode);
            const players = parsePlayers(room).map(player => ({
                ...player,
                isAlive: true,
                role: null,
                symbol: null
            }));
            await redisClient.multi()
                .hset(roomKey(roomCode), 'status', 'waiting')
                .hset(roomKey(roomCode), 'phase', 'lobby')
                .hset(roomKey(roomCode), 'round', '0')
                .hset(roomKey(roomCode), 'players', JSON.stringify(players))
                .del(`room:${roomCode}:jh_ready`)
                .del(`room:${roomCode}:jh_guesses`)
                .del(`room:${roomCode}:jh_locked_guesses`)
                .exec();
            io.to(roomCode).emit('jh_lobby_reset', { roomCode });
            await emitLobby(roomCode);
            await broadcastState(roomCode);
        });
    });
};

