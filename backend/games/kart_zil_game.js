'use strict';

const crypto = require('crypto');
const { createDeck, deckConfig, shuffle, bestHand, scoreHand } = require('./kart_zil_engine');

module.exports = function kartZilGame({ io, redisClient }) {
    const PREFIX = 'kz';
    const TURN_MS = 45000;
    const FINAL_TURN_MS = 15000;
    const RESULT_MS = 8000;
    const HOST_GRACE_MS = 10000;
    const timers = new Map();
    const queues = new Map();
    const key = code => `${PREFIX}:room:${code}`;
    const cleanCode = value => String(value || '').trim().toUpperCase();
    const cleanName = value => String(value || '').trim().slice(0, 24);
    const cleanPlayerCount = value => {
        const count = Number(value);
        return Number.isInteger(count) && count >= 2 && count <= 10 ? count : null;
    };
    const cleanGameMode = value => value === 'team' ? 'team' : 'solo';
    const isTeamMode = state => state.gameMode === 'team';
    function setupTeams(state) {
        state.teams = [
            { id: 'blue', name: 'Mavi Takım', lives: 5 },
            { id: 'purple', name: 'Mor Takım', lives: 5 }
        ];
        state.players = shuffle(state.players);
        state.players.forEach((player, index) => { player.teamId = index % 2 === 0 ? 'blue' : 'purple'; });
    }
    const cardConfig = playerCount => {
        const config = deckConfig(playerCount);
        return {
            colorCount: config.colors.length,
            deckSize: config.deckSize
        };
    };
    const activePlayers = state => state.players.filter(player => !player.eliminated);
    const now = () => Date.now();

    function serialize(state) { return JSON.stringify(state); }
    async function load(code) {
        const raw = await redisClient.get(key(code));
        if (!raw) return null;
        try { return JSON.parse(raw); } catch (_) { return null; }
    }
    async function save(state) {
        state.updatedAt = now();
        await redisClient.set(key(state.roomCode), serialize(state), 'EX', 86400);
    }
    function locked(code, task) {
        const previous = queues.get(code) || Promise.resolve();
        const current = previous.catch(() => {}).then(task);
        const queued = current.finally(() => {
            if (queues.get(code) === queued) queues.delete(code);
        });
        queues.set(code, queued);
        return queued;
    }
    function setRoomTimer(code, deadline, callback) {
        if (timers.has(code)) clearTimeout(timers.get(code));
        const timer = setTimeout(callback, Math.max(0, deadline - now()));
        timers.set(code, timer);
    }
    function cancelTimer(code) {
        if (timers.has(code)) clearTimeout(timers.get(code));
        timers.delete(code);
    }
    function ackError(ack, message) {
        if (typeof ack === 'function') ack({ ok: false, error: message });
    }
    function member(socket, state) {
        return state.players.find(player => player.id === socket.data.kzPlayerId);
    }
    function publicState(state, viewerId) {
        const reveal = state.phase === 'round_result' || state.status === 'game_over';
        const viewer = state.players.find(player => player.id === viewerId);
        const spectatorCanSeeHands = viewer?.eliminated === true;
        const config = cardConfig(state.maxPlayers || state.players.length);
        return {
            roomCode: state.roomCode,
            status: state.status,
            phase: state.phase,
            hostPlayerId: state.hostPlayerId,
            currentPlayerId: state.currentPlayerId,
            turnDeadline: state.turnDeadline || 0,
            serverTime: now(),
            openCard: state.openCard || null,
            deckCount: state.deck.length,
            bell: state.bell,
            roundNumber: state.roundNumber,
            maxPlayers: state.maxPlayers || 10,
            colorCount: config.colorCount,
            deckSize: config.deckSize,
            winnerId: state.winnerId || null,
            winnerTeamId: state.winnerTeamId || null,
            gameMode: state.gameMode || 'solo',
            teams: state.teams || [],
            result: state.result || null,
            myScore: scoreHand(state.players.find(player => player.id === viewerId)?.hand || []),
            players: state.players.map(player => {
                const best = bestHand(player.hand);
                return {
                    id: player.id,
                    name: player.name,
                    lives: player.lives,
                    teamId: player.teamId || null,
                    ready: player.ready,
                    eliminated: player.eliminated,
                    connected: player.connected,
                    isHost: player.id === state.hostPlayerId,
                    cardCount: player.hand.length,
                    cards: reveal ? best.cards : (spectatorCanSeeHands || player.id === viewerId ? player.hand : undefined),
                    score: reveal || spectatorCanSeeHands ? best.score : undefined,
                    scoreType: reveal || spectatorCanSeeHands ? best.type : undefined
                };
            }),
            myPlayerId: viewerId,
            myCards: state.players.find(player => player.id === viewerId)?.hand || []
        };
    }
    async function broadcast(state) {
        const sockets = await io.in(`kz:${state.roomCode}`).fetchSockets();
        for (const socket of sockets) {
            if (socket.data.kzRoomCode === state.roomCode) {
                socket.emit('kz_game_state', publicState(state, socket.data.kzPlayerId));
            }
        }
    }
    function nextActiveId(state, fromId, allowedIds = null) {
        const active = activePlayers(state);
        if (!active.length) return null;
        const start = Math.max(0, active.findIndex(player => player.id === fromId));
        for (let step = 1; step <= active.length; step += 1) {
            const candidate = active[(start + step) % active.length];
            if (!allowedIds || allowedIds.includes(candidate.id)) return candidate.id;
        }
        return null;
    }
    function setTurn(state, playerId, duration) {
        state.currentPlayerId = playerId;
        state.turnStep = 'draw';
        state.turnDeadline = now() + duration;
    }
    function dealRound(state) {
        const active = activePlayers(state);
        state.deck = shuffle(createDeck(active.length));
        for (const player of state.players) player.hand = [];
        for (let count = 0; count < 4; count += 1) {
            for (const player of active) player.hand.push(state.deck.pop());
        }
        state.openCard = state.deck.pop();
        state.deckExhausted = false;
        state.bell = { pressed: false, playerId: null };
        state.finalTurnQueue = [];
        state.result = null;
        state.gameEndsAfterResult = false;
        state.winnerTeamId = null;
        state.roundNumber += 1;
        state.phase = 'playing';
        state.status = 'playing';
        const ordered = active.map(player => player.id);
        const index = state.roundStarterIndex % ordered.length;
        setTurn(state, ordered[index], TURN_MS);
        state.roundStarterIndex = (index + 1) % ordered.length;
    }
    async function finishRound(state) {
        const active = activePlayers(state);
        const scores = active.map(player => ({ playerId: player.id, score: scoreHand(player.hand) }));
        let penalties = [];
        let teamScores = null;
        let teamPenalties = null;
        if (isTeamMode(state)) {
            teamScores = state.teams.map(team => ({
                teamId: team.id,
                score: scores.filter(item => state.players.find(player => player.id === item.playerId)?.teamId === team.id).reduce((sum, item) => sum + item.score, 0)
            }));
            if (teamScores[0].score !== teamScores[1].score) {
                const losingTeamId = teamScores.reduce((lowest, item) => item.score < lowest.score ? item : lowest).teamId;
                const bellPlayer = state.players.find(player => player.id === state.bell.playerId);
                const livesLost = bellPlayer?.teamId === losingTeamId ? 2 : 1;
                const losingTeam = state.teams.find(team => team.id === losingTeamId);
                losingTeam.lives = Math.max(0, losingTeam.lives - livesLost);
                teamPenalties = [{ teamId: losingTeamId, livesLost }];
                if (losingTeam.lives === 0) {
                    for (const player of state.players.filter(item => item.teamId === losingTeamId)) player.eliminated = true;
                }
            }
        } else {
            const minimum = Math.min(...scores.map(item => item.score));
            penalties = scores.filter(item => item.score === minimum).map(item => ({
                playerId: item.playerId,
                teamId: null,
                livesLost: item.playerId === state.bell.playerId ? 2 : 1
            }));
            for (const penalty of penalties) {
                const player = state.players.find(item => item.id === penalty.playerId);
                player.lives = Math.max(0, player.lives - penalty.livesLost);
                player.eliminated = player.lives === 0;
            }
        }
        state.result = { scores, penalties, teamScores, teamPenalties, bellPlayerId: state.bell.playerId };
        state.phase = 'round_result';
        state.currentPlayerId = null;
        state.turnDeadline = now() + RESULT_MS;
        const survivors = activePlayers(state);
        const survivingTeams = isTeamMode(state) ? state.teams.filter(team => team.lives > 0) : [];
        if ((isTeamMode(state) && survivingTeams.length <= 1) || (!isTeamMode(state) && survivors.length <= 1)) {
            state.winnerId = isTeamMode(state) ? null : (survivors[0]?.id || null);
            state.winnerTeamId = isTeamMode(state) ? (survivingTeams[0]?.id || null) : null;
            state.gameEndsAfterResult = true;
        }
        await save(state);
        await broadcast(state);
        io.to(`kz:${state.roomCode}`).emit('kz_round_result', state.result);
        schedule(state);
    }
    async function advanceAfterDiscard(state, playerId) {
        if (state.phase === 'playing') {
            const next = nextActiveId(state, playerId);
            setTurn(state, next, TURN_MS);
        } else {
            state.finalTurnQueue = state.finalTurnQueue.filter(id => id !== playerId);
            if (!state.finalTurnQueue.length) return finishRound(state);
            setTurn(state, state.finalTurnQueue[0], FINAL_TURN_MS);
        }
        await save(state);
        await broadcast(state);
        io.to(`kz:${state.roomCode}`).emit('kz_turn_changed', { playerId: state.currentPlayerId, turnDeadline: state.turnDeadline, serverTime: now() });
        schedule(state);
    }
    async function timeout(code) {
        return locked(code, async () => {
            const state = await load(code);
            if (!state || !['playing', 'final_turn'].includes(state.phase) || state.turnDeadline > now()) return;
            const playerId = state.currentPlayerId;
            if (state.turnStep === 'discard') {
                const player = state.players.find(item => item.id === playerId);
                const drawn = player?.hand.pop();
                if (drawn) state.openCard = drawn;
                if (state.deckExhausted) return finishRound(state);
            } else if (state.deck.length) {
                state.openCard = state.deck.pop();
                if (!state.deck.length) {
                    state.deckExhausted = true;
                    return finishRound(state);
                }
            }
            await advanceAfterDiscard(state, playerId);
        });
    }
    async function nextRound(code) {
        return locked(code, async () => {
            const state = await load(code);
            if (!state || state.phase !== 'round_result') return;
            if (state.gameEndsAfterResult) {
                state.status = 'game_over';
                state.phase = 'game_over';
                state.turnDeadline = 0;
                await save(state);
                await broadcast(state);
                io.to(`kz:${code}`).emit('kz_game_over', publicState(state, null));
                return cancelTimer(code);
            }
            dealRound(state);
            await save(state);
            await broadcast(state);
            io.to(`kz:${code}`).emit('kz_new_round', { roundNumber: state.roundNumber });
            schedule(state);
        });
    }
    function schedule(state) {
        if (['playing', 'final_turn'].includes(state.phase)) {
            setRoomTimer(state.roomCode, state.turnDeadline, () => timeout(state.roomCode).catch(console.error));
        } else if (state.phase === 'round_result') {
            setRoomTimer(state.roomCode, state.turnDeadline, () => nextRound(state.roomCode).catch(console.error));
        } else cancelTimer(state.roomCode);
    }
    async function attach(socket, state, player) {
        socket.data.kzRoomCode = state.roomCode;
        socket.data.kzPlayerId = player.id;
        await socket.join(`kz:${state.roomCode}`);
    }

    io.on('connection', socket => {
        socket.on('kz_request_state', async () => {
            const code = socket.data.kzRoomCode;
            const state = code && await load(code);
            const player = state && member(socket, state);
            if (state && player) socket.emit('kz_game_state', publicState(state, player.id));
        });

        socket.on('kz_create_room', async (payload = {}, ack) => {
            const name = cleanName(payload.playerName);
            const maxPlayers = cleanPlayerCount(payload.playerCount);
            const gameMode = cleanGameMode(payload.gameMode);
            if (name.length < 2) return ackError(ack, 'Oyuncu adi 2-24 karakter olmali.');
            if (!maxPlayers) return ackError(ack, 'Oyuncu sayisi 2-10 arasinda olmali.');
            if (gameMode === 'team' && maxPlayers % 2 !== 0) return ackError(ack, 'Takim modu icin oyuncu sayisi cift olmali.');
            let code, player, state, reserved;
            do {
                code = String(crypto.randomInt(100000, 1000000));
                player = { id: crypto.randomUUID(), resumeToken: crypto.randomBytes(24).toString('hex'), name, lives: 3, ready: false, eliminated: false, connected: true, hand: [] };
                state = { roomCode: code, status: 'lobby', phase: 'lobby', hostPlayerId: player.id, maxPlayers, gameMode, teams: [], players: [player], deck: [], openCard: null, currentPlayerId: null, turnDeadline: 0, turnStep: 'draw', bell: { pressed: false, playerId: null }, finalTurnQueue: [], roundNumber: 0, roundStarterIndex: 0, winnerId: null, winnerTeamId: null, result: null, updatedAt: now() };
                reserved = await redisClient.set(key(code), serialize(state), 'EX', 86400, 'NX');
            } while (reserved !== 'OK');
            await attach(socket, state, player); await broadcast(state);
            if (typeof ack === 'function') ack({ ok: true, roomCode: code, playerId: player.id, resumeToken: player.resumeToken });
        });

        socket.on('kz_join_room', async (payload = {}, ack) => {
            const code = cleanCode(payload.roomCode);
            await locked(code, async () => {
                const state = await load(code);
                if (!state) return ackError(ack, 'Oda bulunamadi.');
                const resumed = state.players.find(player => player.id === payload.playerId && player.resumeToken === payload.resumeToken);
                if (resumed) {
                    resumed.connected = true;
                    await save(state); await attach(socket, state, resumed); await broadcast(state); schedule(state);
                    return typeof ack === 'function' && ack({ ok: true, roomCode: code, playerId: resumed.id, resumeToken: resumed.resumeToken, resumed: true });
                }
                const name = cleanName(payload.playerName);
                if (state.status !== 'lobby') return ackError(ack, 'Oyun basladi; sadece mevcut oyuncular devam edebilir.');
                if (state.players.length >= (state.maxPlayers || 10)) return ackError(ack, 'Oda dolu.');
                if (name.length < 2 || state.players.some(player => player.name.toLocaleLowerCase('tr-TR') === name.toLocaleLowerCase('tr-TR'))) return ackError(ack, 'Gecersiz veya kullanilan oyuncu adi.');
                const player = { id: crypto.randomUUID(), resumeToken: crypto.randomBytes(24).toString('hex'), name, lives: 3, ready: false, eliminated: false, connected: true, hand: [] };
                state.players.push(player); await save(state); await attach(socket, state, player); await broadcast(state);
                if (typeof ack === 'function') ack({ ok: true, roomCode: code, playerId: player.id, resumeToken: player.resumeToken });
            });
        });

        socket.on('kz_set_ready', async (payload = {}, ack) => {
            const code = socket.data.kzRoomCode;
            await locked(code, async () => {
                const state = await load(code); const player = state && member(socket, state);
                if (!player || state.phase !== 'lobby') return ackError(ack, 'Hazirlik degistirilemedi.');
                player.ready = payload.ready === true; await save(state); await broadcast(state);
                if (typeof ack === 'function') ack({ ok: true });
            });
        });

        socket.on('kz_start_game', async (_, ack) => {
            const code = socket.data.kzRoomCode;
            await locked(code, async () => {
                const state = await load(code); const player = state && member(socket, state);
                if (!player || player.id !== state.hostPlayerId || state.phase !== 'lobby') return ackError(ack, 'Sadece host baslatabilir.');
                const requiredPlayers = state.maxPlayers || state.players.length;
                if (state.players.length !== requiredPlayers || !state.players.every(item => item.ready && item.connected)) return ackError(ack, `${requiredPlayers} bagli oyuncunun tamami hazir olmali.`);
                if (isTeamMode(state) && requiredPlayers % 2 !== 0) return ackError(ack, 'Takim modu sadece cift oyuncu sayisiyla baslatilabilir.');
                for (const item of state.players) { item.lives = 3; item.eliminated = false; item.hand = []; }
                if (isTeamMode(state)) setupTeams(state); else { state.teams = []; for (const item of state.players) delete item.teamId; }
                state.roundNumber = 0; state.roundStarterIndex = crypto.randomInt(0, state.players.length); state.winnerId = null; state.winnerTeamId = null; dealRound(state);
                await save(state); await broadcast(state); schedule(state);
                io.to(`kz:${code}`).emit('kz_game_started', { roundNumber: state.roundNumber });
                if (typeof ack === 'function') ack({ ok: true });
            });
        });

        async function draw(payload, ack, takeOpen) {
            const code = socket.data.kzRoomCode;
            await locked(code, async () => {
                const state = await load(code); const player = state && member(socket, state);
                if (!player || player.eliminated || state.currentPlayerId !== player.id || !['playing', 'final_turn'].includes(state.phase) || state.turnStep !== 'draw') return ackError(ack, 'Bu kart alma islemi gecersiz.');
                if (state.bell.playerId === player.id) return ackError(ack, 'Zilcinin eli kilitli.');
                const card = takeOpen ? state.openCard : state.deck.pop();
                if (!card) return ackError(ack, 'Deste bos.');
                player.hand.push(card);
                if (takeOpen) state.openCard = null;
                if (!takeOpen && state.deck.length === 0) state.deckExhausted = true;
                state.turnStep = 'discard';
                await save(state); await broadcast(state);
                if (typeof ack === 'function') ack({ ok: true });
            });
        }
        socket.on('kz_draw_deck', (payload, ack) => draw(payload, ack, false));
        socket.on('kz_take_open_card', (payload, ack) => draw(payload, ack, true));

        socket.on('kz_discard_card', async (payload = {}, ack) => {
            const code = socket.data.kzRoomCode;
            await locked(code, async () => {
                const state = await load(code); const player = state && member(socket, state);
                if (!player || state.currentPlayerId !== player.id || state.turnStep !== 'discard' || !['playing', 'final_turn'].includes(state.phase)) return ackError(ack, 'Kart atma islemi gecersiz.');
                const index = player.hand.findIndex(card => card.id === payload.cardId);
                if (index < 0 || player.hand.length !== 5) return ackError(ack, 'Kart elinde bulunamadi.');
                state.openCard = player.hand.splice(index, 1)[0];
                if (typeof ack === 'function') ack({ ok: true });
                if (state.deckExhausted) return finishRound(state);
                await advanceAfterDiscard(state, player.id);
            });
        });

        socket.on('kz_press_bell', async (_, ack) => {
            const code = socket.data.kzRoomCode;
            await locked(code, async () => {
                const state = await load(code); const player = state && member(socket, state);
                if (!player || player.eliminated || state.phase !== 'playing' || state.bell.pressed || player.hand.length !== 4 || state.currentPlayerId !== player.id || state.turnStep !== 'draw') return ackError(ack, 'Zil sadece kendi siran basladiginda, kart cekmeden once kullanilabilir.');
                state.bell = { pressed: true, playerId: player.id };
                const ids = activePlayers(state).map(item => item.id);
                const queue = [];
                let cursor = player.id;
                for (let i = 1; i < ids.length; i += 1) { cursor = nextActiveId(state, cursor); if (cursor !== player.id) queue.push(cursor); }
                state.finalTurnQueue = queue;
                state.phase = 'final_turn';
                if (!queue.length) return finishRound(state);
                setTurn(state, queue[0], FINAL_TURN_MS);
                await save(state); await broadcast(state); schedule(state);
                io.to(`kz:${code}`).emit('kz_bell_pressed', { playerId: player.id, playerName: player.name });
                io.to(`kz:${code}`).emit('kz_final_turn_started', { queue, turnDeadline: state.turnDeadline });
                if (typeof ack === 'function') ack({ ok: true });
            });
        });

        socket.on('kz_restart_game', async (_, ack) => {
            const code = socket.data.kzRoomCode;
            await locked(code, async () => {
                const state = await load(code); const player = state && member(socket, state);
                if (!player || state.status !== 'game_over') return ackError(ack, 'Lobiye donulemedi.');
                state.players = state.players.filter(item => item.connected);
                if (!state.players.some(item => item.id === state.hostPlayerId)) state.hostPlayerId = state.players[0]?.id || null;
                state.status = 'lobby'; state.phase = 'lobby'; state.roundNumber = 0; state.roundStarterIndex = 0; state.winnerId = null; state.winnerTeamId = null; state.result = null; state.deck = []; state.openCard = null;
                for (const item of state.players) { item.lives = 3; item.eliminated = false; item.ready = false; item.hand = []; }
                state.teams = [];
                for (const item of state.players) delete item.teamId;
                await save(state); await broadcast(state); cancelTimer(code);
                if (typeof ack === 'function') ack({ ok: true });
            });
        });

        socket.on('kz_update_room_settings', async (payload = {}, ack) => {
            const code = socket.data.kzRoomCode;
            await locked(code, async () => {
                const state = await load(code); const player = state && member(socket, state);
                const maxPlayers = cleanPlayerCount(payload.playerCount);
                const gameMode = cleanGameMode(payload.gameMode ?? state?.gameMode);
                if (!player || player.id !== state.hostPlayerId || state.phase !== 'lobby') return ackError(ack, 'Oda ayarlarini sadece kurucu degistirebilir.');
                if (!maxPlayers || maxPlayers < state.players.length) return ackError(ack, `Oyuncu sayisi en az ${state.players.length} olmali.`);
                if (gameMode === 'team' && maxPlayers % 2 !== 0) return ackError(ack, 'Takim modu icin oyuncu sayisi cift olmali.');
                state.maxPlayers = maxPlayers;
                state.gameMode = gameMode;
                for (const item of state.players) item.ready = false;
                await save(state); await broadcast(state);
                if (typeof ack === 'function') ack({ ok: true });
            });
        });

        socket.on('kz_stop_game', async (_, ack) => {
            const code = socket.data.kzRoomCode;
            await locked(code, async () => {
                const state = await load(code); const player = state && member(socket, state);
                if (!player || player.id !== state.hostPlayerId || state.phase === 'lobby') return ackError(ack, 'Sadece kurucu devam eden oyunu durdurabilir.');
                state.status = 'lobby'; state.phase = 'lobby'; state.currentPlayerId = null; state.turnDeadline = 0; state.turnStep = 'draw'; state.deck = []; state.openCard = null; state.bell = { pressed: false, playerId: null }; state.finalTurnQueue = []; state.result = null;
                for (const item of state.players) { item.ready = false; item.hand = []; }
                cancelTimer(code); await save(state); await broadcast(state);
                if (typeof ack === 'function') ack({ ok: true });
            });
        });

        socket.on('kz_leave_room', async (_, ack) => {
            const code = socket.data.kzRoomCode;
            await locked(code, async () => {
                const state = await load(code); if (!state) return;
                const id = socket.data.kzPlayerId;
                const wasCurrentPlayer = state.currentPlayerId === id;
                state.players = state.players.filter(player => player.id !== id);
                state.finalTurnQueue = (state.finalTurnQueue || []).filter(playerId => playerId !== id);
                if (!state.players.length) { await redisClient.del(key(code)); cancelTimer(code); }
                else {
                    if (state.hostPlayerId === id) state.hostPlayerId = state.players.find(player => player.connected)?.id || state.players[0].id;
                    if (state.phase !== 'lobby') {
                        const active = activePlayers(state);
                        const survivingTeams = isTeamMode(state) ? state.teams.filter(team => state.players.some(player => player.teamId === team.id && !player.eliminated)) : [];
                        const gameEnded = isTeamMode(state) ? survivingTeams.length <= 1 : active.length <= 1;
                        if (gameEnded) {
                            state.status = 'game_over'; state.phase = 'game_over'; state.currentPlayerId = null; state.turnDeadline = 0;
                            state.winnerId = isTeamMode(state) ? null : (active[0]?.id || null);
                            state.winnerTeamId = isTeamMode(state) ? (survivingTeams[0]?.id || null) : null;
                            cancelTimer(code);
                        } else if (wasCurrentPlayer) {
                            const nextId = state.phase === 'final_turn' && state.finalTurnQueue.length ? state.finalTurnQueue[0] : active[0].id;
                            setTurn(state, nextId, state.phase === 'final_turn' ? FINAL_TURN_MS : TURN_MS);
                        }
                    }
                    await save(state); await broadcast(state); schedule(state);
                    io.to(`kz:${code}`).emit('kz_host_changed', { hostPlayerId: state.hostPlayerId });
                    if (state.phase === 'game_over') io.to(`kz:${code}`).emit('kz_game_over', publicState(state, null));
                }
                socket.leave(`kz:${code}`); delete socket.data.kzRoomCode; delete socket.data.kzPlayerId;
                if (typeof ack === 'function') ack({ ok: true });
            });
        });

        socket.on('disconnect', () => {
            const code = socket.data.kzRoomCode; const id = socket.data.kzPlayerId;
            if (!code || !id) return;
            locked(code, async () => {
                const state = await load(code); const player = state?.players.find(item => item.id === id);
                if (!player) return;
                player.connected = false; await save(state); await broadcast(state);
                if (state.hostPlayerId === id) setTimeout(() => locked(code, async () => {
                    const latest = await load(code); const host = latest?.players.find(item => item.id === id);
                    if (!latest || host?.connected || latest.hostPlayerId !== id) return;
                    const replacement = latest.players.find(item => item.connected && !item.eliminated) || latest.players.find(item => item.connected);
                    if (replacement) { latest.hostPlayerId = replacement.id; await save(latest); await broadcast(latest); io.to(`kz:${code}`).emit('kz_host_changed', { hostPlayerId: replacement.id }); }
                }), HOST_GRACE_MS);
            }).catch(console.error);
        });
    });
};
