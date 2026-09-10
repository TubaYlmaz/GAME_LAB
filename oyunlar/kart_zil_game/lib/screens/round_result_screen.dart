import 'package:flutter/material.dart';

import '../services/socket_service.dart';
import '../utils/site_navigation.dart';
import '../widgets/education_center_button.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/game_logo.dart';
import '../widgets/playing_card.dart';
import '../widgets/top_bar_controls.dart';

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
    final bellPlayer = state.players
        .where((player) => player.id == state.bellPlayerId)
        .firstOrNull;
    final highestScore = sorted.isEmpty ? 0 : (sorted.first.score ?? 0);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        centerTitle: true,
        leadingWidth: 58,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: kzTopBarGradient),
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
            KzTopIconButton(
              tooltip: 'Oyunu durdur',
              onPressed: service.stopGame,
              icon: Icons.stop_circle_outlined,
            ),
          const SizedBox(width: 6),
          KzTopIconButton(
            tooltip: 'Oyundan çık',
            onPressed: service.leave,
            icon: Icons.logout,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5274EA), Color(0xFF594FC0), Color(0xFF292845)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF354B91), Color(0xFF7650A8)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD05A), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55FFD05A),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFD05A),
                        size: 31,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'TUR SONUCU',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sorted.isEmpty ? 'Tur tamamlandı' : 'TURUN LİDERİ',
                    style: const TextStyle(
                      color: Color(0xFFFFD98A),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sorted.firstOrNull?.name ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '$highestScore PUAN',
                    style: const TextStyle(
                      color: Color(0xFFFFD05A),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: _ResultSummary(
                          icon: Icons.flag_rounded,
                          label: 'TUR',
                          value: '${state.roundNumber}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ResultSummary(
                          icon: Icons.notifications_active_rounded,
                          label: 'ZİLE BASAN',
                          value: bellPlayer?.name ?? 'Yok',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
            ...sorted.indexed.map(
              (entry) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: loss(entry.$2.id) > 0
                    ? const Color(0xCC57364F)
                    : const Color(0xAA354064),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: entry.$2.id == sorted.firstOrNull?.id
                        ? const Color(0xFFFFD36A)
                        : loss(entry.$2.id) > 0
                        ? const Color(0xFFFF756B)
                        : Colors.white24,
                    width:
                        entry.$2.id == sorted.firstOrNull?.id ||
                            loss(entry.$2.id) > 0
                        ? 2
                        : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: entry.$1 == 0
                                  ? const Color(0xFFFFD05A)
                                  : Colors.white12,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${entry.$1 + 1}',
                              style: TextStyle(
                                color: entry.$1 == 0
                                    ? const Color(0xFF232A48)
                                    : Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${entry.$2.eliminated ? '☠️ ' : ''}${entry.$2.name}${entry.$2.id == state.bellPlayerId ? ' 🔔' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (state.gameMode == 'team' &&
                                    entry.$2.teamId != null) ...[
                                  const SizedBox(width: 8),
                                  _TeamBadge(teamId: entry.$2.teamId!),
                                ],
                              ],
                            ),
                          ),
                          _PlayerScoreAndLives(
                            score: entry.$2.score ?? 0,
                            lives: entry.$2.lives,
                            livesLost: loss(entry.$2.id),
                            showLives: state.gameMode != 'team',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: entry.$2.cards
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

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0x88202743),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFFFD36A), size: 20),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF8E3042),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF8B82)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.heart_broken_rounded,
                  color: Color(0xFFFFD1CD),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '-$livesLost CAN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ],
  );
}
