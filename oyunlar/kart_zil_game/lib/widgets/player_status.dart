import 'package:flutter/material.dart';

import '../models/player_model.dart';

class KzPlayerStatus extends StatelessWidget {
  const KzPlayerStatus({
    super.key,
    required this.player,
    required this.isTurn,
    this.lobbyStyle = false,
  });
  final KzPlayer player;
  final bool isTurn;
  final bool lobbyStyle;
  @override
  Widget build(BuildContext context) => Card(
    elevation: lobbyStyle ? 0 : null,
    color: lobbyStyle
        ? const Color(0x38202743)
        : (isTurn ? const Color(0xFF243B62) : const Color(0xFF171B2E)),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: lobbyStyle
          ? const BorderSide(color: Color(0x55FFFFFF))
          : BorderSide.none,
    ),
    child: ListTile(
      dense: !lobbyStyle,
      contentPadding: lobbyStyle
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 5)
          : null,
      leading: CircleAvatar(
        backgroundColor: lobbyStyle ? const Color(0xFFFFCA4B) : null,
        foregroundColor: lobbyStyle ? const Color(0xFF202743) : null,
        child: Text(player.name.isEmpty ? '?' : player.name[0].toUpperCase()),
      ),
      title: Text(
        '${player.eliminated ? '☠️ ' : ''}${player.name}${player.isHost ? ' 👑' : ''}',
      ),
      subtitle: Text(
        lobbyStyle
            ? (player.connected
                  ? (player.ready ? 'Hazır' : 'Hazırlanıyor')
                  : 'Bağlantısı kesildi')
            : (player.eliminated
                  ? 'Elendi • izliyor'
                  : '${'❤️' * player.lives} • ${player.cardCount} kart${player.ready ? ' • Hazır' : ''}'),
      ),
      trailing: player.connected && !isTurn
          ? (lobbyStyle
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF82D8C6),
                  )
                : const SizedBox.shrink())
          : Text(player.connected ? 'SIRA' : 'Çevrimdışı'),
    ),
  );
}
