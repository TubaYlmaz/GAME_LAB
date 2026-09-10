import 'package:flutter/material.dart';

class JhBackground extends StatelessWidget {
  const JhBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF211B18), Color(0xFF3A2924), Color(0xFF263029)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -80,
            top: -90,
            child: _Glow(color: Color(0x44D9826B), size: 280),
          ),
          const Positioned(
            left: -110,
            bottom: -100,
            child: _Glow(color: Color(0x448FA58B), size: 300),
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

class JhSymbolMark extends StatelessWidget {
  const JhSymbolMark({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .14),
      decoration: BoxDecoration(
        color: const Color(0xFF49372F),
        borderRadius: BorderRadius.circular(size * .25),
        border: Border.all(color: const Color(0x99E7C98A)),
        boxShadow: const [
          BoxShadow(color: Color(0x443A5541), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: const [
          FittedBox(
            child: Text('☀', style: TextStyle(color: Color(0xFFE7C98A))),
          ),
          FittedBox(
            child: Text('☾', style: TextStyle(color: Color(0xFF9CAF96))),
          ),
          FittedBox(
            child: Text('★', style: TextStyle(color: Color(0xFFD9826B))),
          ),
          FittedBox(
            child: Text('☁', style: TextStyle(color: Color(0xFFF4EBDD))),
          ),
        ],
      ),
    );
  }
}

class JhPanel extends StatelessWidget {
  const JhPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xEE352B26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x66F4EBDD)),
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
    this.color = const Color(0xFFD9826B),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = enabled ? color : const Color(0xFF6D6760);
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label, textAlign: TextAlign.center),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: active,
        foregroundColor: const Color(0xFF211B18),
        disabledBackgroundColor: active.withValues(alpha: .45),
        disabledForegroundColor: const Color(0xAAF4EBDD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

String remainingText(int endAt, {int? nowMilliseconds}) {
  final now = nowMilliseconds ?? DateTime.now().millisecondsSinceEpoch;
  final seconds = ((endAt - now) / 1000).ceil().clamp(0, 999).toInt();
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
