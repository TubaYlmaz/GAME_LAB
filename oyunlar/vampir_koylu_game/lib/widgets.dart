import 'dart:math';
import 'package:flutter/material.dart';
import 'player_model.dart';

// ─── 1. Yıldızlar Efekti ────────────────────────────────────────────────────────
class StarField extends StatelessWidget {
  const StarField({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter(), child: const SizedBox.expand());
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 90; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.1 + 0.3;
      paint.color = Colors.white.withValues(
        alpha: rng.nextDouble() * 0.4 + 0.1,
      );
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── 2. Modern Cam Efektli (Glassmorphism) Buton ─────────────────────────────
class NeonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool enabled;
  final bool large;

  const NeonButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.enabled = true,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.3);
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: large ? 28 : 18,
          vertical: large ? 12 : 8,
        ),
        decoration: BoxDecoration(
          color: enabled
              ? effectiveColor.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? effectiveColor.withValues(alpha: 0.8)
                : Colors.white12,
            width: 1.2,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: effectiveColor, size: large ? 18 : 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontSize: large ? 13 : 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 3. Üst Bar (Modern Minimalist HUD) ──────────────────────────────────────
class TopBar extends StatelessWidget {
  final GamePhase phase;
  final int round;

  const TopBar({super.key, required this.phase, required this.round});

  @override
  Widget build(BuildContext context) {
    final phaseLabel = switch (phase) {
      GamePhase.night => '🌑  GECE EVRESİ',
      GamePhase.dayDiscussion => '☀️  GÜNDÜZ TARTIŞMASI',
      GamePhase.voting => '🗳️  OYLAMA EVRESİ',
    };
    final phaseColor = switch (phase) {
      GamePhase.night => const Color(0xFFA569BD),
      GamePhase.dayDiscussion => const Color(0xFFF39C12),
      GamePhase.voting => const Color(0xFF00D2FF),
    };

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F26).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_moon_outlined,
                color: Color(0xFF00D2FF),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Vampir Köylü',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: phaseColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: phaseColor.withValues(alpha: 0.6)),
            ),
            child: Text(
              phaseLabel,
              style: TextStyle(
                color: phaseColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          Text(
            'Tur $round',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4. Şık Oyun Günlüğü (Game Log) ──────────────────────────────────────────
class GameLogPanel extends StatelessWidget {
  final List<String> logs;
  final Size screenSize;

  const GameLogPanel({super.key, required this.logs, required this.screenSize});

  @override
  Widget build(BuildContext context) {
    final w = min(screenSize.width * 0.32, 280.0);
    return Container(
      width: w,
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1F).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, top: 8, bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.notes_rounded,
                  color: const Color(0xFF00D2FF).withValues(alpha: 0.8),
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  'OYUN AKIŞI',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              reverse: true,
              itemBuilder: (_, i) {
                final log = logs[logs.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    log,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 5. Modern Oyuncu Listesi Paneli ─────────────────────────────────────────
class PlayerStatusPanel extends StatelessWidget {
  final List<PlayerModel> players;
  final GamePhase phase;
  final String? selectedVoteTargetId;
  final ValueChanged<String?> onSelectTarget;

  const PlayerStatusPanel({
    super.key,
    required this.players,
    required this.phase,
    required this.selectedVoteTargetId,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1F).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  color: const Color(0xFF00D2FF).withValues(alpha: 0.8),
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  'KÖYLÜLER',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 4),
          ...players.map((p) => _buildRow(p)),
        ],
      ),
    );
  }

  Widget _buildRow(PlayerModel player) {
    final isVoteTarget = selectedVoteTargetId == player.id;
    final canVote = phase == GamePhase.voting && player.isAlive;

    return GestureDetector(
      onTap: canVote
          ? () => onSelectTarget(isVoteTarget ? null : player.id)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isVoteTarget
              ? const Color(0xFF00D2FF).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isVoteTarget ? const Color(0xFF00D2FF) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: player.isAlive ? player.avatarColor : Colors.white24,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                player.name,
                style: TextStyle(
                  color: player.isAlive
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white30,
                  fontSize: 11,
                  fontWeight: player.isAlive
                      ? FontWeight.w500
                      : FontWeight.normal,
                  decoration: player.isAlive
                      ? null
                      : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (!player.isAlive)
              const Text('🪦', style: TextStyle(fontSize: 10)),
            if (canVote && !isVoteTarget)
              Icon(
                Icons.touch_app_outlined,
                size: 12,
                color: const Color(0xFF00D2FF).withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }
}
