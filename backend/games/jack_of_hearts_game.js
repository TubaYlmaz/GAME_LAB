module.exports = function ({ io, redisClient }) {
    const GAME_ID = 'jack_of_hearts';
    const DISCUSSION_MS = 180000;
    const CELL_MS = 20000;
    const RESULT_MS = 3000;
    const SYMBOLS = ['♥', '♠', '♦', '♣'];
    const MODES = new Set(['free', 'single', 'random']);
    const timers = new Map();
    const evaluating = new Set();
    const advancing = new Set();
    const roomKey = code => `room:${code}`;
    const readyKey = code => `room:${code}:jh_ready`;
    const guessesKey = code => `room:${code}:jh_guesses`;
    const locksKey = code => `room:${code}:jh_locked_guesses`;
    const notesKey = code => `room:${code}:jh_inspections`;
    const returnedKey = code => `room:${code}:jh_returned_to_lobby`;
    const codeOf = value => String(value || '').trim();
    const nameOf = value => String(value || '').trim();
    const nameKey = value => nameOf(value).toLocaleLowerCase('tr-TR');
    const validCode = code => /^\d{6}$/.test(code);
    const validName = name => name.length >= 2 && name.length <= 24;
    const validMode = value => MODES.has(value) ? value : 'free';
    const member = (socket, code) => socket.data.jhRoomCode === code;
    const matchId = () => `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    const error = (socket, message) => socket.emit('jh_error', { message });
    const playersOf = room => { try { const value = JSON.parse(room.players || '[]'); return Array.isArray(value) ? value : []; } catch (_) { return []; } };
    const notesOf = raw => { try { const value = JSON.parse(raw || '[]'); return Array.isArray(value) ? value.filter(item => Number.isInteger(Number(item.number)) && SYMBOLS.includes(item.symbol)).map(item => ({ number: Number(item.number), symbol: item.symbol })) : []; } catch (_) { return []; } };

    function clearTimers(code) {
        const active = timers.get(code);
        if (!active) return;
        Object.values(active).forEach(timer => clearTimeout(timer));
        timers.delete(code);
    }
    function timer(code, key, delay, task) {
        const active = timers.get(code) || {};
        if (active[key]) clearTimeout(active[key]);
        active[key] = setTimeout(() => { delete active[key]; task().catch(err => console.error('[JH]', err)); }, Math.max(0, delay));
        timers.set(code, active);
    }
    function shuffledNumbers() {
        const values = Array.from({ length: 99 }, (_, index) => index + 1);
        for (let index = values.length - 1; index > 0; index -= 1) {
            const swap = Math.floor(Math.random() * (index + 1));
            [values[index], values[swap]] = [values[swap], values[index]];
        }
        return values;
    }
    function deal(players) {
        const numbers = shuffledNumbers(); let index = 0;
        return players.map(player => player.isAlive === false
            ? { ...player, number: null, symbol: null }
            : { ...player, number: numbers[index++], symbol: SYMBOLS[Math.floor(Math.random() * SYMBOLS.length)] });
    }
    function randomNotes(players) {
        const alive = players.filter(player => player.isAlive !== false);
        return alive.map(player => {
            const targets = alive.filter(target => nameKey(target.name) !== nameKey(player.name));
            const target = targets[Math.floor(Math.random() * targets.length)];
            return [player.name, JSON.stringify([{ number: target.number, symbol: target.symbol }])];
        });
    }
    function publicPlayers(players, myName) {
        return players.map(player => ({ name: player.name, gender: player.gender || 'male', isHost: player.isHost === true, isAlive: player.isAlive !== false, isMe: nameKey(player.name) === nameKey(myName) }));
    }
    async function lobby(code) {
        const room = await redisClient.hgetall(roomKey(code));
        if (!room || room.game !== GAME_ID) return;
        const players = playersOf(room);
        const returned = new Set((await redisClient.smembers(returnedKey(code))).map(nameKey));
        const waiting = room.status === 'waiting' && room.phase === 'lobby';
        io.to(code).emit('jh_room_updated', {
            roomCode: code, host: room.host, status: room.status || 'waiting', phase: room.phase || 'lobby', inspectionMode: validMode(room.inspectionMode),
            players: players.map(player => ({ name: player.name, gender: player.gender || 'male', isHost: player.isHost === true, isAlive: player.isAlive !== false, isInLobby: waiting || returned.has(nameKey(player.name)) })),
            returnedPlayers: players.filter(player => returned.has(nameKey(player.name))).map(player => player.name),
            returnedCount: returned.size, totalPlayers: players.length, allPlayersReturned: waiting
        });
    }
    async function state(socket, code, knownRoom) {
        const room = knownRoom || await redisClient.hgetall(roomKey(code));
        if (!room || room.game !== GAME_ID) return;
        const players = playersOf(room);
        const me = players.find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName));
        const alive = players.filter(player => player.isAlive !== false);
        const [ready, locked, notes, returned] = await Promise.all([
            redisClient.smembers(readyKey(code)), redisClient.smembers(locksKey(code)),
            me ? redisClient.hget(notesKey(code), me.name) : Promise.resolve('[]'), redisClient.smembers(returnedKey(code))
        ]);
        socket.emit('jh_game_state', {
            roomCode: code, matchId: room.matchId || null, serverNow: Date.now(), status: room.status || 'waiting', phase: room.phase || 'lobby', round: Number(room.round || 0),
            inspectionMode: validMode(room.inspectionMode), discussionEndsAt: Number(room.discussionEndsAt || 0), cellEndsAt: Number(room.cellEndsAt || 0), resultEndsAt: Number(room.resultEndsAt || 0),
            gameWinner: room.gameWinner || null, winnerName: room.winnerName || null, winnerNumber: Number(room.winnerNumber || 0) || null, readyPlayers: ready, readyCount: ready.length, lockedPlayers: locked, lockedCount: locked.length,
            totalAlive: alive.length, returnedPlayers: returned, returnedCount: returned.length, totalPlayers: players.length, allPlayersReturned: room.status === 'waiting' && room.phase === 'lobby',
            myNumber: me && me.isAlive !== false ? Number(me.number || 0) : null,
            visibleNumbers: alive.filter(player => !me || nameKey(player.name) !== nameKey(me.name)).map(player => Number(player.number || 0)).filter(Boolean).sort((a, b) => a - b),
            inspectionNotes: notesOf(notes), players: publicPlayers(players, socket.data.jhPlayerName)
        });
    }
    async function broadcast(code, room) {
        const sockets = await io.in(code).fetchSockets();
        await Promise.all(sockets.filter(socket => socket.data.jhRoomCode === code).map(socket => state(socket, code, room)));
    }

    async function discussion(code, initial = false, expected = null) {
        if (advancing.has(`discussion:${code}`)) return false;
        advancing.add(`discussion:${code}`);
        try {
            const room = await redisClient.hgetall(roomKey(code));
            if (!room || room.game !== GAME_ID || room.status !== 'started' || (expected && room.matchId !== expected)) return false;
            if ((initial && room.phase !== 'setup') || (!initial && room.phase !== 'result')) return false;
            const players = deal(playersOf(room));
            const end = Date.now() + DISCUSSION_MS;
            const mode = validMode(room.inspectionMode);
            const automatic = mode === 'random' ? randomNotes(players) : [];
            const tx = redisClient.multi().hset(roomKey(code), 'players', JSON.stringify(players)).hset(roomKey(code), 'phase', 'discussion').hset(roomKey(code), 'round', String(initial ? 1 : Number(room.round || 0) + 1)).hset(roomKey(code), 'discussionEndsAt', String(end)).hset(roomKey(code), 'cellEndsAt', '0').hdel(roomKey(code), 'resultEndsAt').del(readyKey(code)).del(guessesKey(code)).del(locksKey(code)).del(notesKey(code));
            automatic.forEach(([name, raw]) => tx.hset(notesKey(code), name, raw));
            await tx.exec();
            timer(code, 'discussion', end - Date.now(), () => recover(code, room.matchId));
            io.to(code).emit('jh_phase_changed', { phase: 'discussion', round: initial ? 1 : Number(room.round || 0) + 1, inspectionMode: mode, discussionEndsAt: end, matchId: room.matchId, serverNow: Date.now() });
            await broadcast(code); return true;
        } finally { advancing.delete(`discussion:${code}`); }
    }
    async function cell(code, reason, expected = null) {
        if (advancing.has(`cell:${code}`)) return false;
        advancing.add(`cell:${code}`);
        try {
            const room = await redisClient.hgetall(roomKey(code));
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'discussion' || (expected && room.matchId !== expected)) return false;
            if (reason === 'timer' && Date.now() < Number(room.discussionEndsAt || 0)) return false;
            const end = Date.now() + CELL_MS;
            await redisClient.multi().hset(roomKey(code), 'phase', 'cell').hset(roomKey(code), 'cellEndsAt', String(end)).del(guessesKey(code)).del(locksKey(code)).exec();
            timer(code, 'cell', end - Date.now(), () => recover(code, room.matchId));
            io.to(code).emit('jh_phase_changed', { phase: 'cell', cellEndsAt: end, matchId: room.matchId, reason, serverNow: Date.now() });
            await broadcast(code); return true;
        } finally { advancing.delete(`cell:${code}`); }
    }
    async function finish(code, winner, winnerName, winnerNumber, eliminated, expected) {
        const room = await redisClient.hgetall(roomKey(code));
        if (!room || room.game !== GAME_ID || room.status === 'finished' || (expected && room.matchId !== expected)) return false;
        clearTimers(code);
        await redisClient.multi().hset(roomKey(code), 'status', 'finished').hset(roomKey(code), 'phase', 'game_over').hset(roomKey(code), 'gameWinner', winner).hset(roomKey(code), 'winnerName', winnerName || '').hset(roomKey(code), 'winnerNumber', winnerNumber ? String(winnerNumber) : '').del(readyKey(code)).del(guessesKey(code)).del(locksKey(code)).del(returnedKey(code)).exec();
        io.to(code).emit('jh_game_over', { winner, winnerName: winnerName || null, winnerNumber: winnerNumber || null, eliminated, matchId: room.matchId, serverNow: Date.now() });
        await broadcast(code); return true;
    }
    async function evaluate(code, reason, expected = null) {
        if (evaluating.has(code)) return false;
        evaluating.add(code);
        try {
            const room = await redisClient.hgetall(roomKey(code));
            if (!room || room.game !== GAME_ID || room.status !== 'started' || room.phase !== 'cell' || (expected && room.matchId !== expected)) return false;
            if (reason === 'timer' && Date.now() < Number(room.cellEndsAt || 0)) return false;
            const guesses = await redisClient.hgetall(guessesKey(code));
            const locked = new Set((await redisClient.smembers(locksKey(code))).map(nameKey));
            const eliminated = [];
            const players = playersOf(room).map(player => {
                if (player.isAlive === false || (locked.has(nameKey(player.name)) && guesses[player.name] === player.symbol)) return player;
                eliminated.push({ name: player.name, gender: player.gender || 'male', reason: locked.has(nameKey(player.name)) ? 'wrong_guess' : 'afk' });
                return { ...player, isAlive: false, number: null, symbol: null };
            });
            const survivors = players.filter(player => player.isAlive !== false);
            const end = Date.now() + RESULT_MS;
            await redisClient.multi().hset(roomKey(code), 'players', JSON.stringify(players)).hset(roomKey(code), 'phase', 'result').hset(roomKey(code), 'resultEndsAt', String(end)).del(readyKey(code)).del(guessesKey(code)).del(locksKey(code)).exec();
            if (!survivors.length) return finish(code, 'NONE', null, null, eliminated, room.matchId);
            if (survivors.length === 1) return finish(code, 'PLAYER', survivors[0].name, Number(survivors[0].number || 0) || null, eliminated, room.matchId);
            timer(code, 'result', end - Date.now(), () => recover(code, room.matchId));
            io.to(code).emit('jh_round_result', { eliminated, matchId: room.matchId, round: Number(room.round || 1), reason, resultEndsAt: end });
            await broadcast(code); return true;
        } finally { evaluating.delete(code); }
    }
    async function recover(code, expected = null) {
        const room = await redisClient.hgetall(roomKey(code));
        if (!room || room.game !== GAME_ID || room.status !== 'started' || (expected && room.matchId !== expected)) return false;
        const now = Date.now();
        if (room.phase === 'setup') return discussion(code, true, room.matchId);
        if (room.phase === 'discussion') return now >= Number(room.discussionEndsAt || 0) ? cell(code, 'timer', room.matchId) : (timer(code, 'discussion', Number(room.discussionEndsAt) - now, () => recover(code, room.matchId)), false);
        if (room.phase === 'cell') return now >= Number(room.cellEndsAt || 0) ? evaluate(code, 'timer', room.matchId) : (timer(code, 'cell', Number(room.cellEndsAt) - now, () => recover(code, room.matchId)), false);
        if (room.phase === 'result') return now >= Number(room.resultEndsAt || 0) ? discussion(code, false, room.matchId) : (timer(code, 'result', Number(room.resultEndsAt) - now, () => recover(code, room.matchId)), false);
        return false;
    }

    io.on('connection', socket => {
        socket.on('jh_create_room', async data => {
            const code = codeOf(data && data.roomCode); const name = nameOf(data && data.playerName); const gender = data && data.gender === 'female' ? 'female' : 'male'; const inspectionMode = validMode(String(data && data.inspectionMode || '').trim().toLowerCase());
            if (!validCode(code) || !validName(name)) return error(socket, 'Geçerli bir oda kodu ve 2-24 karakterlik isim girin.');
            if (await redisClient.exists(roomKey(code))) return error(socket, 'Bu oda kodu zaten kullanılıyor.');
            const players = [{ name, gender, isHost: true, isAlive: true, number: null, symbol: null }];
            await redisClient.multi().hmset(roomKey(code), { game: GAME_ID, host: name, status: 'waiting', phase: 'lobby', round: '0', inspectionMode, players: JSON.stringify(players), createdAt: String(Date.now()) }).expire(roomKey(code), 14400).exec();
            socket.join(code); socket.data.jhRoomCode = code; socket.data.jhPlayerName = name; socket.data.jhGender = gender;
            socket.emit('jh_room_created', { roomCode: code, host: name }); await lobby(code);
        });
        socket.on('jh_join_room', async data => {
            const code = codeOf(data && data.roomCode); const name = nameOf(data && data.playerName); const gender = data && data.gender === 'female' ? 'female' : 'male'; const inspectionMode = validMode(String(data && data.inspectionMode || '').trim().toLowerCase());
            const room = await redisClient.hgetall(roomKey(code));
            if (!room || room.game !== GAME_ID) return error(socket, 'Oda bulunamadı.');
            if (!validName(name)) return error(socket, 'İsim 2-24 karakter olmalıdır.');
            const players = playersOf(room); const known = players.find(player => nameKey(player.name) === nameKey(name));
            if (!known && room.status !== 'waiting') return error(socket, 'Oyun başladı; yeni oyuncu alınmıyor.');
            if (!known && players.length >= 99) return error(socket, 'Bu odada en fazla 99 oyuncu olabilir.');
            if (!known) { players.push({ name, gender, isHost: false, isAlive: true, number: null, symbol: null }); await redisClient.hset(roomKey(code), 'players', JSON.stringify(players)); }
            if (socket.data.jhRoomCode && socket.data.jhRoomCode !== code) socket.leave(socket.data.jhRoomCode);
            socket.join(code); socket.data.jhRoomCode = code; socket.data.jhPlayerName = known ? known.name : name; socket.data.jhGender = known ? known.gender : gender;
            socket.emit('jh_room_joined', { roomCode: code, playerName: socket.data.jhPlayerName }); await recover(code, room.matchId); await lobby(code); await state(socket, code);
        });
        socket.on('jh_get_state', async data => { const code = codeOf(data && data.roomCode) || socket.data.jhRoomCode; if (code && member(socket, code)) { await recover(code); await state(socket, code); } });
        socket.on('jh_update_settings', async data => {
            const code = codeOf(data && data.roomCode); const room = await redisClient.hgetall(roomKey(code)); const mode = String(data && data.inspectionMode || '').trim().toLowerCase();
            if (!member(socket, code)) return error(socket, 'Bu oda için yetkiniz yok.');
            if (!room || room.game !== GAME_ID || room.status !== 'waiting' || room.phase !== 'lobby') return error(socket, 'Ayarlar yalnızca lobide değiştirilebilir.');
            if (room.host !== socket.data.jhPlayerName) return error(socket, 'Ayarları yalnızca kurucu değiştirebilir.');
            if (!MODES.has(mode)) return error(socket, 'Geçersiz inceleme modu.');
            await redisClient.hset(roomKey(code), 'inspectionMode', mode); await lobby(code); await broadcast(code);
        });        socket.on('jh_leave_room', async data => {
            const code = codeOf(data && data.roomCode); const room = await redisClient.hgetall(roomKey(code));
            if (!member(socket, code)) return error(socket, 'Bu oda için yetkiniz yok.');
            if (!room || room.game !== GAME_ID || !['waiting', 'finished'].includes(room.status)) return error(socket, 'Oyun devam ederken odadan çıkamazsınız.');
            const leaving = socket.data.jhPlayerName;
            const players = playersOf(room).filter(player => nameKey(player.name) !== nameKey(leaving));
            if (!players.length) await redisClient.multi().del(roomKey(code)).del(readyKey(code)).del(guessesKey(code)).del(locksKey(code)).del(notesKey(code)).del(returnedKey(code)).exec();
            else {
                const host = players.some(player => nameKey(player.name) === nameKey(room.host)) ? room.host : players[0].name;
                const updated = players.map(player => ({ ...player, isHost: nameKey(player.name) === nameKey(host) }));
                await redisClient.multi().hset(roomKey(code), 'host', host).hset(roomKey(code), 'players', JSON.stringify(updated)).del(returnedKey(code)).exec();
            }
            socket.leave(code); socket.data.jhRoomCode = null; socket.data.jhPlayerName = null; socket.data.jhGender = null; socket.emit('jh_left_room', { roomCode: code });
            if (players.length) await lobby(code);
        });
        socket.on('jh_start_game', async data => {
            const code = codeOf(data && data.roomCode); const room = await redisClient.hgetall(roomKey(code));
            if (!member(socket, code) || !room || room.game !== GAME_ID) return error(socket, 'Oda bulunamadı veya yetkiniz yok.');
            if (room.host !== socket.data.jhPlayerName || room.status !== 'waiting') return error(socket, 'Oyunu yalnızca kurucu lobiden başlatabilir.');
            const players = playersOf(room); if (players.length < 2) return error(socket, 'Başlamak için en az 2 oyuncu gerekir.');
            const id = matchId(); clearTimers(code);
            await redisClient.multi().hset(roomKey(code), 'status', 'started').hset(roomKey(code), 'phase', 'setup').hset(roomKey(code), 'round', '0').hset(roomKey(code), 'matchId', id).hset(roomKey(code), 'players', JSON.stringify(players.map(player => ({ ...player, isAlive: true, number: null, symbol: null })))).hdel(roomKey(code), 'gameWinner', 'winnerName', 'winnerNumber', 'resultEndsAt').del(readyKey(code)).del(guessesKey(code)).del(locksKey(code)).del(notesKey(code)).del(returnedKey(code)).exec();
            io.to(code).emit('jh_game_started', { roomCode: code, matchId: id, serverNow: Date.now() }); await discussion(code, true, id);
        });
        socket.on('jh_ready_for_cell', async data => {
            const code = codeOf(data && data.roomCode); const room = await redisClient.hgetall(roomKey(code));
            if (!member(socket, code) || !room || room.game !== GAME_ID || room.phase !== 'discussion') return;
            if (Date.now() >= Number(room.discussionEndsAt || 0)) return recover(code, room.matchId);
            const me = playersOf(room).find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName));
            if (!me || me.isAlive === false) return error(socket, 'Elendiniz; yalnızca izleyebilirsiniz.');
            await redisClient.sadd(readyKey(code), me.name);
            const alive = playersOf(room).filter(player => player.isAlive !== false); const ready = await redisClient.smembers(readyKey(code));
            io.to(code).emit('jh_ready_status', { readyCount: ready.length, totalAlive: alive.length, readyPlayers: ready, matchId: room.matchId, serverNow: Date.now() }); await broadcast(code);
            if (ready.length >= alive.length) await cell(code, 'unanimous_ready', room.matchId);
        });
        socket.on('jh_inspect_number', async data => {
            const code = codeOf(data && data.roomCode); const targetNumber = Number(data && data.targetNumber); const room = await redisClient.hgetall(roomKey(code));
            if (!member(socket, code) || !room || room.game !== GAME_ID || room.phase !== 'discussion') return;
            if (Date.now() >= Number(room.discussionEndsAt || 0)) return recover(code, room.matchId);
            const me = playersOf(room).find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName));
            if (!me || me.isAlive === false) return error(socket, 'Elendiniz; inceleme yapamazsınız.');
            if (!Number.isInteger(targetNumber) || targetNumber === Number(me.number)) return error(socket, 'Geçersiz inceleme hedefi.');
            const target = playersOf(room).find(player => player.isAlive !== false && Number(player.number) === targetNumber);
            if (!target) return error(socket, 'Bu numara masada değil.');
            const mode = validMode(room.inspectionMode); if (mode === 'random') return error(socket, 'Rastgele modda hedefi sistem seçer.');
            const oldNotes = notesOf(await redisClient.hget(notesKey(code), me.name)); const existing = oldNotes.find(note => note.number === targetNumber);
            if (existing) return socket.emit('jh_inspection_result', { ...existing, matchId: room.matchId });
            if (mode === 'single' && oldNotes.length) return error(socket, 'Tek inceleme hakkınızı kullandınız.');
            const note = { number: targetNumber, symbol: target.symbol }; await redisClient.hset(notesKey(code), me.name, JSON.stringify([...oldNotes, note]));
            socket.emit('jh_inspection_result', { ...note, matchId: room.matchId }); await state(socket, code);
        });
        socket.on('jh_submit_guess', async data => {
            const code = codeOf(data && data.roomCode); const symbol = String(data && data.guessSymbol || ''); const lock = data && data.isLocking === true; const room = await redisClient.hgetall(roomKey(code));
            if (!member(socket, code) || !room || room.game !== GAME_ID || room.phase !== 'cell') return;
            if (Date.now() >= Number(room.cellEndsAt || 0)) return recover(code, room.matchId);
            const me = playersOf(room).find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName));
            if (!me || me.isAlive === false) return error(socket, 'Elendiniz; seçim yapamazsınız.');
            const locked = new Set((await redisClient.smembers(locksKey(code))).map(nameKey)); if (locked.has(nameKey(me.name))) return;
            if (symbol && !SYMBOLS.includes(symbol)) return error(socket, 'Geçersiz sembol seçimi.');
            if (symbol) await redisClient.hset(guessesKey(code), me.name, symbol);
            if (lock) { const selected = symbol || await redisClient.hget(guessesKey(code), me.name); if (!SYMBOLS.includes(selected)) return error(socket, 'Önce bir sembol seçin.'); await redisClient.sadd(locksKey(code), me.name); }
            const alive = playersOf(room).filter(player => player.isAlive !== false); const allLocked = await redisClient.smembers(locksKey(code));
            io.to(code).emit('jh_guess_status', { lockedCount: allLocked.length, totalAlive: alive.length, lockedPlayers: allLocked, matchId: room.matchId, serverNow: Date.now() }); await broadcast(code);
            if (allLocked.length >= alive.length) await evaluate(code, 'all_locked', room.matchId);
        });
        socket.on('jh_return_to_lobby', async data => {
            const code = codeOf(data && data.roomCode); const room = await redisClient.hgetall(roomKey(code));
            if (!member(socket, code) || !room || room.game !== GAME_ID || room.status !== 'finished') return;
            const players = playersOf(room); const me = players.find(player => nameKey(player.name) === nameKey(socket.data.jhPlayerName)); if (!me) return;
            await redisClient.sadd(returnedKey(code), me.name); const returned = new Set((await redisClient.smembers(returnedKey(code))).map(nameKey)); const all = players.every(player => returned.has(nameKey(player.name)));
            socket.emit('jh_lobby_returned', { roomCode: code, returnedPlayers: [...returned], returnedCount: returned.size, totalPlayers: players.length, allPlayersReturned: all });
            if (all) await redisClient.multi().hset(roomKey(code), 'status', 'waiting').hset(roomKey(code), 'phase', 'lobby').hset(roomKey(code), 'round', '0').hset(roomKey(code), 'players', JSON.stringify(players.map(player => ({ ...player, isAlive: true, number: null, symbol: null })))).hdel(roomKey(code), 'gameWinner', 'winnerName', 'winnerNumber', 'resultEndsAt', 'matchId').del(readyKey(code)).del(guessesKey(code)).del(locksKey(code)).del(notesKey(code)).del(returnedKey(code)).exec();
            await lobby(code); await broadcast(code);
        });
    });
};