import 'package:flutter/material.dart';

import '../models/card_model.dart';

class KzPlayingCard extends StatefulWidget {
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
    'cyan' => const Color(0xFF2AA9B8),
    'brown' => const Color(0xFF9A6B4F),
    'lime' => const Color(0xFF78A83B),
    _ => const Color(0xFF3E63DD),
  };

  @override
  State<KzPlayingCard> createState() => _KzPlayingCardState();
}

class _KzPlayingCardState extends State<KzPlayingCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 480),
    curve: Curves.easeOutBack,
    builder: (context, value, child) => Transform.translate(
      offset: Offset((1 - value) * 34, (1 - value) * -42),
      child: Transform.rotate(angle: (1 - value) * .14, child: child),
    ),
    child: AnimatedScale(
      scale: _pressed ? .94 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _pressed ? const Offset(0, -.06) : Offset.zero,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: widget.onTap == null
              ? null
              : (value) => setState(() => _pressed = value),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: widget.mini
                ? 20
                : (widget.compact ? 46 : (widget.large ? 80 : 68)),
            height: widget.mini
                ? 28
                : (widget.compact ? 66 : (widget.large ? 116 : 98)),
            decoration: BoxDecoration(
              color: KzPlayingCard.colorOf(widget.card.color),
              borderRadius: BorderRadius.circular(widget.mini ? 8 : 14),
              border: Border.all(
                color: Colors.white70,
                width: widget.mini ? 1 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: widget.mini ? 4 : (_pressed ? 14 : 8),
                  offset: _pressed ? const Offset(0, 8) : const Offset(0, 3),
                  color: Colors.black38,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${widget.card.number}',
              style: TextStyle(
                fontSize: widget.mini
                    ? 10
                    : (widget.compact ? 20 : (widget.large ? 36 : 30)),
                fontWeight: FontWeight.w900,
                color: widget.card.color == 'yellow'
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
