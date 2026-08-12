import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/throw_history.dart';
import '../services/result_randomizer.dart';

class CoinFlipComponent extends StatefulWidget {
  const CoinFlipComponent({super.key, required this.onFlipCompleted});

  final ValueChanged<CoinSide> onFlipCompleted;

  @override
  State<CoinFlipComponent> createState() => _CoinFlipComponentState();
}

class _CoinFlipComponentState extends State<CoinFlipComponent>
    with SingleTickerProviderStateMixin {
  final ResultRandomizer _randomizer = ResultRandomizer();
  late final AnimationController _controller;
  CoinSide _side = CoinSide.heads;
  double _startRotation = 0;
  double _targetRotation = 0;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
  }

  Future<void> _flip() async {
    if (_isFlipping) return;
    final nextSide = _randomizer.nextCoinSide();

    setState(() {
      _isFlipping = true;
      _startRotation = _targetRotation;
      final halfTurns = 8 + (nextSide == _side ? 0 : 1);
      _targetRotation = _startRotation + halfTurns * math.pi;
    });

    await _controller.forward(from: 0);
    if (!mounted) return;

    setState(() {
      _side = nextSide;
      _isFlipping = false;
    });
    widget.onFlipCompleted(nextSide);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = Curves.easeOutCubic.transform(_controller.value);
            final angle = _isFlipping
                ? _startRotation + (_targetRotation - _startRotation) * progress
                : _targetRotation;
            final faceDirection = math.cos(angle);
            final visibleSide = _isFlipping
                ? (faceDirection >= 0 ? CoinSide.heads : CoinSide.tails)
                : _side;
            final faceWidth = .06 + faceDirection.abs() * .94;

            return Transform.translate(
              offset: Offset(0, -math.sin(progress * math.pi) * 15),
              child: Transform.scale(
                alignment: Alignment.center,
                scaleX: faceWidth,
                child: _CoinFace(side: visibleSide),
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _isFlipping ? null : _flip,
          icon: const Icon(Icons.flip_rounded),
          label: Text(_isFlipping ? 'PARA HAVADA...' : 'PARAYI AT'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(210, 52),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _CoinFace extends StatelessWidget {
  const _CoinFace({required this.side});

  final CoinSide side;

  @override
  Widget build(BuildContext context) {
    final isHeads = side == CoinSide.heads;
    return Container(
      width: 152,
      height: 152,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isHeads
              ? const [Color(0xFFA774FF), Color(0xFF3EA8FF)]
              : const [Color(0xFFFFC45B), Color(0xFFFF6D48)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .6), width: 5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isHeads ? Icons.account_balance_rounded : Icons.star_rounded,
            size: 43,
          ),
          const SizedBox(height: 4),
          Text(
            side.label,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
