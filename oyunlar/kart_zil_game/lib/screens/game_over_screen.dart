import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/socket_service.dart';

class KzGameOverScreen extends StatefulWidget {
  const KzGameOverScreen({super.key});

  @override
  State<KzGameOverScreen> createState() => _KzGameOverScreenState();
}

class _KzGameOverScreenState extends State<KzGameOverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController confetti;

  @override
  void initState() {
    super.initState();
    confetti = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = KzSocketService.instance, state = service.state!;
    final winner = state.players
        .where((player) => player.id == state.winnerId)
        .firstOrNull;
    final winnerTeam = state.teams
        .where((team) => team.id == state.winnerTeamId)
        .firstOrNull;
    final ranking = [...state.players]
      ..sort((a, b) {
        final lifeOrder = b.lives.compareTo(a.lives);
        return lifeOrder != 0
            ? lifeOrder
            : (b.score ?? 0).compareTo(a.score ?? 0);
      });
    final winnerMembers = winnerTeam == null
        ? const <String>[]
        : state.players
              .where((player) => player.teamId == winnerTeam.id)
              .map((player) => player.name)
              .toList();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: [Color(0xFF5274EA), Color(0xFF594FC0), Color(0xFF292845)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: confetti,
                  builder: (context, child) =>
                      CustomPaint(painter: _ConfettiPainter(confetti.value)),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: .4, end: 1),
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: SingleChildScrollView(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 560),
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xEE354B91), Color(0xEE7650A8)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white38, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 28),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🏆',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 72, height: 1),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'OYUN TAMAMLANDI',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'KAZANAN',
                            style: TextStyle(
                              color: Color(0xFFFFCA4B),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            winnerTeam?.name ?? winner?.name ?? 'Kazanan yok',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFE39A),
                              fontSize: 50,
                              letterSpacing: .5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            winnerTeam != null
                                ? '${winnerTeam.name}, ${winnerTeam.lives} canla oyunu kazandı.'
                                : winner != null
                                ? '${winner.lives} canla oyunda kalan son oyuncu oldu.'
                                : 'Oyun kazanan olmadan tamamlandı.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if (winnerMembers.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              winnerMembers.join(' • '),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0x33202743),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'SON DURUM',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Text('${state.roundNumber} tur'),
                                  ],
                                ),
                                const Divider(),
                                for (
                                  var index = 0;
                                  index < ranking.length;
                                  index++
                                )
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 30,
                                          child: Text('${index + 1}.'),
                                        ),
                                        Expanded(
                                          child: Text(
                                            ranking[index].name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${ranking[index].score ?? 0} puan  •  ${ranking[index].lives} can',
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: service.restart,
                              icon: const Icon(Icons.meeting_room),
                              label: const Text('LOBİYE DÖN'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: service.leave,
                              icon: const Icon(Icons.logout),
                              label: const Text('OYUNDAN ÇIK'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);

  final double progress;

  static const colors = [
    Color(0xFFFFD166),
    Color(0xFF7BDFF2),
    Color(0xFFB2F7EF),
    Color(0xFFF7A9A8),
    Color(0xFFCDB4DB),
    Color(0xFFA7C7E7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < 72; index++) {
      final random = math.Random(index * 7919);
      final delayed = (progress + random.nextDouble()) % 1;
      final startX = size.width * (.15 + random.nextDouble() * .7);
      final spread = (random.nextDouble() - .5) * size.width * .55;
      final x = startX + spread * delayed + math.sin(delayed * 9 + index) * 14;
      final y = -20 + delayed * (size.height + 60);
      final paint = Paint()..color = colors[index % colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(delayed * math.pi * 5 + random.nextDouble());
      final width = 5 + random.nextDouble() * 7;
      final height = 8 + random.nextDouble() * 10;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
