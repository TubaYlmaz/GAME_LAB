import 'package:flutter/material.dart';

import '../services/socket_service.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/playing_card.dart';

class KzRoundResultScreen extends StatelessWidget {
  const KzRoundResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = KzSocketService.instance;
    final state = service.state!;
    final me = state.players.where((p) => p.id == service.playerId).firstOrNull;
    final penalties = (state.result?['penalties'] as List? ?? const [])
        .whereType<Map>();
    final teamScores = (state.result?['teamScores'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final teamPenalties = (state.result?['teamPenalties'] as List? ?? const [])
        .whereType<Map>();
    int teamLoss(String id) =>
        (teamPenalties
                    .where((penalty) => penalty['teamId'] == id)
                    .firstOrNull?['livesLost']
                as num?)
            ?.toInt() ??
        0;
    int loss(String id) =>
        (penalties.where((p) => p['playerId'] == id).firstOrNull?['livesLost']
                as num?)
            ?.toInt() ??
        0;
    final sorted = [...state.players]
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tur Sonucu'),
        actions: [
          KzCountdown(
            deadline: state.turnDeadline,
            serverTime: state.serverTime,
          ),
          const SizedBox(width: 16),
          if (me?.isHost == true)
            IconButton(
              tooltip: 'Oyunu durdur',
              onPressed: service.stopGame,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          IconButton(
            tooltip: 'Oyundan çık',
            onPressed: service.leave,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF64577E), Color(0xFF303A5C), Color(0xFF4D7580)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'ELLER AÇILDI',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            if (teamScores.isNotEmpty) ...[
              Row(
                children: teamScores
                    .map(
                      (team) => Expanded(
                        child: Card(
                          color: team['teamId'] == 'blue'
                              ? const Color(0xFF496FA8)
                              : const Color(0xFF765A9C),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Text(
                                  team['teamId'] == 'blue'
                                      ? '🔵 MAVİ TAKIM'
                                      : '🟣 MOR TAKIM',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${team['score'] ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Text('TOPLAM PUAN'),
                                const SizedBox(height: 5),
                                Text(
                                  '${'♥' * (state.teams.where((item) => item.id == team['teamId']).firstOrNull?.lives ?? 0)}${teamLoss('${team['teamId']}') > 0 ? '  -${teamLoss('${team['teamId']}')} CAN' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFB3BE),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              if (teamScores.length == 2 &&
                  teamScores[0]['score'] == teamScores[1]['score'])
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Takımlar eşit • Bu tur kimse can kaybetmedi',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            ...sorted.map(
              (player) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${player.eliminated ? '☠️ ' : ''}${player.name}${player.id == state.bellPlayerId ? ' 🔔' : ''}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            state.gameMode == 'team'
                                ? '${player.score ?? 0} puan'
                                : '${player.score ?? 0} puan  ${'❤️' * player.lives}${loss(player.id) > 0 ? '  -${loss(player.id)} ❤️' : ''}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: player.cards
                            .map(
                              (card) =>
                                  KzPlayingCard(card: card, compact: true),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Yeni tur otomatik başlayacak.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
