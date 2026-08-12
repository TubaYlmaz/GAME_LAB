import 'package:flutter/material.dart';

import '../screens/chance_game_screen.dart';

class ChanceGameCard extends StatelessWidget {
  const ChanceGameCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Semantics(
        button: true,
        label: '\u015eans Oyunlar\u0131n\u0131 A\u00e7',
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ChanceGameScreen()),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF19182D),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF37335F)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _DiagonalDividerPainter()),
                ),
                const Positioned(
                  top: 28,
                  left: 26,
                  child: _CardSection(
                    title: 'YAZI\nTURA',
                    icon: Icons.monetization_on_rounded,
                    colors: [Color(0xFF9C6BFF), Color(0xFF32B8FF)],
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
                const Positioned(
                  right: 26,
                  bottom: 28,
                  child: _CardSection(
                    title: 'ZAR\nAT',
                    icon: Icons.casino_rounded,
                    colors: [Color(0xFFFF4E7A), Color(0xFFFFA12F)],
                    alignment: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.icon,
    required this.colors,
    required this.alignment,
  });

  final String title;
  final IconData icon;
  final List<Color> colors;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              LinearGradient(colors: colors).createShader(bounds),
          child: Icon(icon, size: 48, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: alignment == CrossAxisAlignment.end
              ? TextAlign.right
              : TextAlign.left,
          style: TextStyle(
            fontSize: 19,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            foreground: Paint()
              ..shader = LinearGradient(
                colors: colors,
              ).createShader(const Rect.fromLTWH(0, 0, 160, 48)),
          ),
        ),
      ],
    );
  }
}

class _DiagonalDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF9270FF), Color(0xFFFF7348)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.5;

    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
