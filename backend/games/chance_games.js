/**
 * Chance Games Socket.io listeners.
 * The client generates the result; this module validates, logs, and acknowledges it.
 */
module.exports = function registerChanceGames({ io }) {
    io.on('connection', (socket) => {
        socket.on('sp_record_action', (payload = {}, acknowledge) => {
            const reply = typeof acknowledge === 'function' ? acknowledge : () => {};
            const isPayloadValid =
                payload &&
                typeof payload === 'object' &&
                payload.game === 'chance_games' &&
                ['coin_flip', 'dice_roll'].includes(payload.action) &&
                payload.result &&
                typeof payload.result === 'object';

            if (!isPayloadValid) {
                const response = { ok: false, error: 'Invalid chance-game action.' };
                reply(response);
                socket.emit('sp_action_recorded', response);
                return;
            }

            const response = {
                ok: true,
                actionId: payload.actionId || null,
                recordedAt: new Date().toISOString(),
            };

            console.log('[Chance Games] Action recorded:', {
                socketId: socket.id,
                action: payload.action,
                result: payload.result,
                actionId: response.actionId,
            });

            reply(response);
            socket.emit('sp_action_recorded', response);
        });
    });
};
