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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1,
            colors: [Color(0xFF7587B3), Color(0xFF5B557B), Color(0xFF28314D)],
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 90)),
                      const Text('KAZANAN', style: TextStyle(fontSize: 24)),
                      Text(
                        winnerTeam?.name ?? winner?.name ?? 'Kazanan yok',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: service.restart,
                        icon: const Icon(Icons.meeting_room),
                        label: const Text('LOBİYE DÖN'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: service.leave,
                        icon: const Icon(Icons.logout),
                        label: const Text('OYUNDAN ÇIK'),
                      ),
                    ],
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
