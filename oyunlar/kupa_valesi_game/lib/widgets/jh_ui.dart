import 'package:flutter/material.dart';

class JhBackground extends StatelessWidget {
  const JhBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF080914), Color(0xFF241023), Color(0xFF0C1728)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -80,
            top: -90,
            child: _Glow(color: Color(0x44FF426E), size: 280),
          ),
          const Positioned(
            left: -110,
            bottom: -100,
            child: _Glow(color: Color(0x3377E6FF), size: 300),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class JhPanel extends StatelessWidget {
  const JhPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xDD181A2C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x55FFFFFF)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24)],
      ),
      child: child,
    );
  }
}

class JhButton extends StatelessWidget {
  const JhButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.color = const Color(0xFFFF426E),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = enabled ? color : const Color(0xFF596070);
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label, textAlign: TextAlign.center),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: active,
        foregroundColor: Colors.white,
        disabledBackgroundColor: active.withValues(alpha: .45),
        disabledForegroundColor: Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .4),
      ),
    );
  }
}

String remainingText(int endAt) {
  final seconds = ((endAt - DateTime.now().millisecondsSinceEpoch) / 1000)
      .ceil()
      .clamp(0, 999)
      .toInt();
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
