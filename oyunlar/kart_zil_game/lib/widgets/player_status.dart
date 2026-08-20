import 'package:flutter/material.dart';

import '../models/player_model.dart';

class KzPlayerStatus extends StatelessWidget {
  const KzPlayerStatus({super.key, required this.player, required this.isTurn});
  final KzPlayer player;
  final bool isTurn;
  @override
  Widget build(BuildContext context) => Card(
    color: isTurn ? const Color(0xFF243B62) : const Color(0xFF171B2E),
    child: ListTile(
      dense: true,
      leading: CircleAvatar(
        child: Text(player.name.isEmpty ? '?' : player.name[0].toUpperCase()),
      ),
      title: Text(
        '${player.eliminated ? '☠️ ' : ''}${player.name}${player.isHost ? ' 👑' : ''}',
      ),
      subtitle: Text(
        player.eliminated
            ? 'Elendi • izliyor'
            : '${'❤️' * player.lives} • ${player.cardCount} kart${player.ready ? ' • Hazır' : ''}',
      ),
      trailing: Text(player.connected ? (isTurn ? 'SIRA' : '') : 'Çevrimdışı'),
    ),
  );
}
