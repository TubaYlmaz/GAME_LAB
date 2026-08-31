import 'package:flutter/material.dart';

import '../services/socket_service.dart';
import '../utils/site_navigation.dart';
import '../widgets/education_center_button.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/game_logo.dart';
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
        toolbarHeight: 66,
        centerTitle: true,
        leadingWidth: 58,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF34456F), Color(0xFF534B7D), Color(0xFF355F78)],
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(7, 9, 3, 9),
          child: KzEducationCenterButton(onPressed: () => _goToGames(service)),
        ),
        title: const KzGameLogo(width: 112, height: 52),
        actions: [
          KzCountdown(
            deadline: state.turnDeadline,
            serverTime: state.serverTime,
          ),
          const SizedBox(width: 16),
          if (me?.isHost == true)
            IconButton.filledTonal(
              tooltip: 'Oyunu durdur',
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF9B73D1),
              ),
              onPressed: service.stopGame,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Oyundan çık',
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF9B73D1),
            ),
            onPressed: service.leave,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 12),
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
                                _TeamLives(
                                  lives:
                                      state.teams
                                          .where(
                                            (item) => item.id == team['teamId'],
                                          )
                                          .firstOrNull
                                          ?.lives ??
                                      0,
                                  livesLost: teamLoss('${team['teamId']}'),
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
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${player.eliminated ? '☠️ ' : ''}${player.name}${player.id == state.bellPlayerId ? ' 🔔' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (state.gameMode == 'team' &&
                                    player.teamId != null) ...[
                                  const SizedBox(width: 8),
                                  _TeamBadge(teamId: player.teamId!),
                                ],
                              ],
                            ),
                          ),
                          _PlayerScoreAndLives(
                            score: player.score ?? 0,
                            lives: player.lives,
                            livesLost: loss(player.id),
                            showLives: state.gameMode != 'team',
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

  Future<void> _goToGames(KzSocketService service) async {
    await service.leave();
    goToGamesPage();
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context) {
    final isBlue = teamId == 'blue';
    final color = isBlue ? const Color(0xFF4C8DFF) : const Color(0xFFA967D5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        isBlue ? '🔵 MAVİ' : '🟣 MOR',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TeamLives extends StatelessWidget {
  const _TeamLives({required this.lives, required this.livesLost});

  final int lives;
  final int livesLost;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < lives; index++)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Icon(Icons.favorite, color: Color(0xFFFF4057), size: 18),
        ),
      if (livesLost > 0) ...[
        const SizedBox(width: 7),
        Text(
          '-$livesLost CAN',
          style: const TextStyle(
            color: Color(0xFFFF4057),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ],
  );
}

class _PlayerScoreAndLives extends StatelessWidget {
  const _PlayerScoreAndLives({
    required this.score,
    required this.lives,
    required this.livesLost,
    required this.showLives,
  });

  final int score;
  final int lives;
  final int livesLost;
  final bool showLives;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$score puan'),
      if (showLives) ...[
        const SizedBox(width: 7),
        for (var index = 0; index < lives; index++)
          const Padding(
            padding: EdgeInsets.only(left: 1),
            child: Icon(Icons.favorite, color: Color(0xFFFF4057), size: 15),
          ),
        if (livesLost > 0) ...[
          const SizedBox(width: 7),
          Text(
            '-$livesLost',
            style: const TextStyle(
              color: Color(0xFFFF4057),
              fontWeight: FontWeight.w900,
            ),
          ),
          const Icon(Icons.favorite, color: Color(0xFFFF4057), size: 15),
        ],
      ],
    ],
  );
}
