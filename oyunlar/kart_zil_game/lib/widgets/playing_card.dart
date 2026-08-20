import 'package:flutter/material.dart';

import '../models/card_model.dart';

class KzPlayingCard extends StatelessWidget {
  const KzPlayingCard({
    super.key,
    required this.card,
    this.onTap,
    this.compact = false,
    this.mini = false,
    this.large = false,
  });
  final KzCard card;
  final VoidCallback? onTap;
  final bool compact;
  final bool mini;
  final bool large;

  static Color colorOf(String color) => switch (color) {
    'red' => const Color(0xFFE5484D),
    'yellow' => const Color(0xFFF5C542),
    'green' => const Color(0xFF30A46C),
    'purple' => const Color(0xFF8E4EC6),
    'orange' => const Color(0xFFF76B15),
    'pink' => const Color(0xFFE86AA6),
    _ => const Color(0xFF3E63DD),
  };

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 480),
    curve: Curves.easeOutBack,
    builder: (context, value, child) => Transform.translate(
      offset: Offset((1 - value) * 34, (1 - value) * -42),
      child: Transform.rotate(angle: (1 - value) * .14, child: child),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: mini ? 24 : (compact ? 46 : (large ? 80 : 68)),
        height: mini ? 34 : (compact ? 66 : (large ? 116 : 98)),
        decoration: BoxDecoration(
          color: colorOf(card.color),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white70, width: 2),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black38)],
        ),
        alignment: Alignment.center,
        child: Text(
          '${card.number}',
          style: TextStyle(
            fontSize: mini ? 12 : (compact ? 20 : (large ? 36 : 30)),
            fontWeight: FontWeight.w900,
            color: card.color == 'yellow' ? Colors.black : Colors.white,
          ),
        ),
      ),
    ),
  );
}
