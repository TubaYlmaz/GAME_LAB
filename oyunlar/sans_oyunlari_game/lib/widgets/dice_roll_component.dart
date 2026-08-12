import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/result_randomizer.dart';

class DiceRollComponent extends StatefulWidget {
  const DiceRollComponent({super.key, required this.onRollCompleted});

  final ValueChanged<List<int>> onRollCompleted;

  @override
  State<DiceRollComponent> createState() => _DiceRollComponentState();
}

class _DiceRollComponentState extends State<DiceRollComponent>
    with SingleTickerProviderStateMixin {
  final ResultRandomizer _randomizer = ResultRandomizer();
  late final AnimationController _controller;
  int _diceCount = 1;
  List<int> _values = const [1];
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _roll() async {
    if (_isRolling) return;
    setState(() => _isRolling = true);
    await _controller.forward(from: 0);
    if (!mounted) return;

    final values = _randomizer.rollDice(diceCount: _diceCount);
    setState(() {
      _values = values;
      _isRolling = false;
    });
    widget.onRollCompleted(values);
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
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 1,
              label: Text('1 ZAR'),
              icon: Icon(Icons.looks_one_rounded),
            ),
            ButtonSegment(
              value: 2,
              label: Text('2 ZAR'),
              icon: Icon(Icons.looks_two_rounded),
            ),
          ],
          selected: {_diceCount},
          onSelectionChanged: _isRolling
              ? null
              : (selection) => setState(() {
                  _diceCount = selection.first;
                  _values = List<int>.filled(_diceCount, 1);
                }),
        ),
        const SizedBox(height: 30),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < _diceCount; index++) ...[
                  if (index > 0) const SizedBox(width: 18),
                  _DiceCube(
                    value: _values[index],
                    progress: _controller.value,
                    isRolling: _isRolling,
                    index: index,
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _isRolling ? null : _roll,
          icon: const Icon(Icons.casino_rounded),
          label: Text(_isRolling ? 'ZARLAR D\u00d6N\u00dcYOR...' : 'ZAR AT'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(190, 52),
            backgroundColor: const Color(0xFFFF6547),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _DiceCube extends StatelessWidget {
  const _DiceCube({
    required this.value,
    required this.progress,
    required this.isRolling,
    required this.index,
  });

  final int value;
  final double progress;
  final bool isRolling;
  final int index;

  @override
  Widget build(BuildContext context) {
    final spinProgress = isRolling ? progress : 0.0;
    final phase = (spinProgress * 18 + index * 2.7).floor();
    final visibleValue = isRolling ? (phase % 6) + 1 : value;
    final wobble = math.sin(spinProgress * math.pi * 14 + index) * 10;

    return Transform.translate(
      offset: Offset(wobble, math.cos(spinProgress * math.pi * 10 + index) * 7),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0022)
          ..rotateX(spinProgress * math.pi * 7 + index * .18)
          ..rotateY(spinProgress * math.pi * 8 + index * .32)
          ..rotateZ(spinProgress * math.pi * 4 + index * .14),
        child: Semantics(
          label: isRolling ? 'Zar donuyor' : '$value geldi',
          child: SizedBox(
            width: 124,
            height: 124,
            child: CustomPaint(painter: _DiceCubePainter(value: visibleValue)),
          ),
        ),
      ),
    );
  }
}

class _DiceCubePainter extends CustomPainter {
  const _DiceCubePainter({required this.value});

  final int value;

  static const _pipOffsets = <Offset>[
    Offset(.23, .23),
    Offset(.5, .23),
    Offset(.77, .23),
    Offset(.23, .5),
    Offset(.5, .5),
    Offset(.77, .5),
    Offset(.23, .77),
    Offset(.5, .77),
    Offset(.77, .77),
  ];

  static const _pipsByValue = <int, Set<int>>{
    1: {4},
    2: {0, 8},
    3: {0, 4, 8},
    4: {0, 2, 6, 8},
    5: {0, 2, 4, 6, 8},
    6: {0, 2, 3, 5, 6, 8},
  };

  @override
  void paint(Canvas canvas, Size size) {
    final primaryPair = value > 3 ? 7 - value : value;
    final remainingPairs = <int>[1, 2, 3]..remove(primaryPair);
    final sideValue = remainingPairs[0];
    final topValue = remainingPairs[1];

    final front = <Offset>[
      Offset(size.width * .16, size.height * .34),
      Offset(size.width * .72, size.height * .34),
      Offset(size.width * .72, size.height * .84),
      Offset(size.width * .16, size.height * .84),
    ];
    final top = <Offset>[
      front[0],
      Offset(size.width * .42, size.height * .12),
      Offset(size.width * .94, size.height * .12),
      front[1],
    ];
    final side = <Offset>[
      front[1],
      top[2],
      Offset(size.width * .94, size.height * .62),
      front[2],
    ];

    _paintFace(canvas, top, topValue, const Color(0xFFFFFCFA));
    _paintFace(canvas, side, sideValue, const Color(0xFFF4B1A0));
    _paintFace(
      canvas,
      front,
      value,
      const Color(0xFFFFF7F4),
      castsShadow: true,
    );
  }

  void _paintFace(
    Canvas canvas,
    List<Offset> vertices,
    int faceValue,
    Color color, {
    bool castsShadow = false,
  }) {
    final path = Path()
      ..moveTo(vertices[0].dx, vertices[0].dy)
      ..lineTo(vertices[1].dx, vertices[1].dy)
      ..lineTo(vertices[2].dx, vertices[2].dy)
      ..lineTo(vertices[3].dx, vertices[3].dy)
      ..close();
    if (castsShadow) {
      canvas.drawShadow(path, const Color(0x44000000), 8, false);
    }
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF9A81)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final pips = _pipsByValue[faceValue]!;
    final pipPaint = Paint()..color = const Color(0xFF3A2630);
    for (var index = 0; index < _pipOffsets.length; index++) {
      if (!pips.contains(index)) continue;
      canvas.drawCircle(
        _bilinearPoint(vertices, _pipOffsets[index]),
        7,
        pipPaint,
      );
    }
  }

  Offset _bilinearPoint(List<Offset> vertices, Offset fraction) {
    final top = Offset.lerp(vertices[0], vertices[1], fraction.dx)!;
    final bottom = Offset.lerp(vertices[3], vertices[2], fraction.dx)!;
    return Offset.lerp(top, bottom, fraction.dy)!;
  }

  @override
  bool shouldRepaint(covariant _DiceCubePainter oldDelegate) =>
      value != oldDelegate.value;
}
