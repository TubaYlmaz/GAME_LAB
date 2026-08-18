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
  CoinSide _startSide = CoinSide.heads;
  CoinSide _targetSide = CoinSide.heads;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  Future<void> _flip() async {
    if (_isFlipping) return;
    final nextSide = _randomizer.nextCoinSide();

    setState(() {
      _isFlipping = true;
      _startSide = _side;
      _targetSide = nextSide;
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
            // Number of half turns (pi rad): even if target == start, odd if target != start
            final isSame = _targetSide == _startSide;
            final halfTurns = isSame ? 10 : 11;
            final angle = _isFlipping ? progress * halfTurns * math.pi : 0.0;

            final cosVal = math.cos(angle);
            final isBackShowing = cosVal < 0;
            final visibleSide = _isFlipping
                ? (isBackShowing
                    ? (_startSide == CoinSide.heads ? CoinSide.tails : CoinSide.heads)
                    : _startSide)
                : _side;

            // Vertical translation for jump arc
            final jumpHeight = math.sin(progress * math.pi) * 35.0;
            final shadowScale = 1.0 - (math.sin(progress * math.pi) * 0.35);
            final shadowOpacity = 0.4 - (math.sin(progress * math.pi) * 0.2);

            return Stack(
              alignment: Alignment.center,
              children: [
                // Dynamic Ground Shadow
                Positioned(
                  bottom: 4,
                  child: Transform.scale(
                    scale: shadowScale,
                    child: Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: shadowOpacity),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Flipping 3D Coin
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  child: Transform.translate(
                    offset: Offset(0, -jumpHeight),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..rotateY(angle)
                        // If back face is facing camera, apply 180 Y flip so text/icon is right-side up
                        ..rotateY(isBackShowing ? math.pi : 0),
                      child: _CoinFace(side: visibleSide),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isFlipping ? null : _flip,
          icon: const Icon(Icons.flip_rounded),
          label: Text(_isFlipping ? 'PARA HAVADA...' : 'PARAYI AT'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(200, 48),
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
      width: 136,
      height: 136,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isHeads
              ? const [Color(0xFFB47CFF), Color(0xFF2C8CFF)]
              : const [Color(0xFFFFD05B), Color(0xFFFF523B)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .75), width: 4.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isHeads ? Icons.account_balance_rounded : Icons.star_rounded,
            size: 40,
            color: Colors.white,
          ),
          const SizedBox(height: 2),
          Text(
            side.label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}