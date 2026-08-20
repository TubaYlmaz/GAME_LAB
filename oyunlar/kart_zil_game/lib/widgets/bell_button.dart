import 'dart:math' as math;

import 'package:flutter/material.dart';

class KzBellButton extends StatefulWidget {
  const KzBellButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<KzBellButton> createState() => _KzBellButtonState();
}

class _KzBellButtonState extends State<KzBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.enabled,
    label: 'Zile bas',
    child: GestureDetector(
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final value = widget.enabled ? pulse.value : 0.0;
          return Transform.rotate(
            angle: widget.enabled ? math.sin(value * math.pi * 2) * .07 : 0,
            child: Transform.scale(
              scale: widget.enabled ? 1 + (value * .08) : .9,
              child: Opacity(
                opacity: widget.enabled ? 1 : .38,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2A2108).withValues(alpha: .72),
                    boxShadow: widget.enabled
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFB000)
                                  .withValues(alpha: .35 + (value * .35)),
                              blurRadius: 24 + (value * 16),
                              spreadRadius: 2 + (value * 4),
                            ),
                          ]
                        : const [],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Text('🔔', style: TextStyle(fontSize: 48)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
