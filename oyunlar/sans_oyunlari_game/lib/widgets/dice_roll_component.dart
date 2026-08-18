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
      duration: const Duration(milliseconds: 1400),
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
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = Curves.easeOutCubic.transform(_controller.value);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _diceCount; index++) ...[
                    if (index > 0) const SizedBox(width: 24),
                    _DiceCube3D(
                      targetValue: _values[index],
                      progress: progress,
                      isRolling: _isRolling,
                      index: index,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _isRolling ? null : _roll,
          icon: const Icon(Icons.casino_rounded),
          label: Text(_isRolling ? 'ZARLAR DÖNÜYOR...' : 'ZAR AT'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(190, 48),
            backgroundColor: const Color(0xFFFF523B),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _DiceCube3D extends StatelessWidget {
  const _DiceCube3D({
    required this.targetValue,
    required this.progress,
    required this.isRolling,
    required this.index,
  });

  final int targetValue;
  final double progress;
  final bool isRolling;
  final int index;

  static const double cubeSize = 92.0;
  static const double halfSize = cubeSize / 2.0;

  @override
  Widget build(BuildContext context) {
    if (!isRolling) {
      return Semantics(
        label: '$targetValue geldi',
        child: Container(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: _DiceFaceView(value: targetValue, size: cubeSize),
        ),
      );
    }

    final (targetRotX, targetRotY) = _getTargetRotation(targetValue);

    final spinsX = 4 + index * 2;
    final spinsY = 6 + index * 2;
    final spinsZ = 2 + index;

    final rotX = isRolling
        ? (1.0 - progress) * (spinsX * math.pi * 2 + index * 0.5) + targetRotX
        : targetRotX;
    final rotY = isRolling
        ? (1.0 - progress) * (spinsY * math.pi * 2 + index * 0.7) + targetRotY
        : targetRotY;
    final rotZ = isRolling
        ? (1.0 - progress) * (spinsZ * math.pi * 2 + index * 0.3)
        : 0.0;

    final jumpHeight = isRolling ? math.sin(progress * math.pi) * 35.0 : 0.0;
    final wobbleX = isRolling ? math.sin(progress * math.pi * 5 + index) * 18.0 : 0.0;

    final shadowScale = 1.0 - (isRolling ? math.sin(progress * math.pi) * 0.4 : 0.0);
    final shadowOpacity = 0.4 - (isRolling ? math.sin(progress * math.pi) * 0.25 : 0.0);

    // Compute depth z' for each face to depth-sort in the stack
    final cosX = math.cos(rotX);
    final sinX = math.sin(rotX);
    final cosY = math.cos(rotY);
    final sinY = math.sin(rotY);

    final faceDepths = <_FaceData>[
      _FaceData(val: 1, depth: halfSize * cosY * cosX, transform: Matrix4.identity()..translate(0.0, 0.0, halfSize)),
      _FaceData(val: 6, depth: -halfSize * cosY * cosX, transform: Matrix4.identity()..translate(0.0, 0.0, -halfSize)..rotateY(math.pi)),
      _FaceData(val: 2, depth: halfSize * sinX, transform: Matrix4.identity()..translate(0.0, -halfSize, 0.0)..rotateX(-math.pi / 2)),
      _FaceData(val: 5, depth: -halfSize * sinX, transform: Matrix4.identity()..translate(0.0, halfSize, 0.0)..rotateX(math.pi / 2)),
      _FaceData(val: 3, depth: halfSize * sinY * cosX, transform: Matrix4.identity()..translate(halfSize, 0.0, 0.0)..rotateY(math.pi / 2)),
      _FaceData(val: 4, depth: -halfSize * sinY * cosX, transform: Matrix4.identity()..translate(-halfSize, 0.0, 0.0)..rotateY(-math.pi / 2)),
    ]..sort((a, b) => a.depth.compareTo(b.depth));

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ground Shadow
        Positioned(
          bottom: 12,
          child: Transform.scale(
            scale: shadowScale,
            child: Container(
              width: cubeSize * 0.9,
              height: 18,
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
        // 3D Cube Container
        Transform.translate(
          offset: Offset(wobbleX, -jumpHeight),
          child: Semantics(
            label: isRolling ? 'Zar dönüyor' : '$targetValue geldi',
            child: SizedBox(
              width: cubeSize,
              height: cubeSize,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018)
                  ..rotateX(rotX)
                  ..rotateY(rotY)
                  ..rotateZ(rotZ),
                child: Stack(
                  children: [
                    for (final face in faceDepths)
                      Transform(
                        alignment: Alignment.center,
                        transform: face.transform,
                        child: _DiceFaceView(value: face.val, size: cubeSize),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  (double, double) _getTargetRotation(int val) {
    return switch (val) {
      1 => (0.0, 0.0),
      6 => (0.0, math.pi),
      2 => (math.pi / 2, 0.0),
      5 => (-math.pi / 2, 0.0),
      3 => (0.0, -math.pi / 2),
      4 => (0.0, math.pi / 2),
      _ => (0.0, 0.0),
    };
  }
}

class _FaceData {
  _FaceData({required this.val, required this.depth, required this.transform});
  final int val;
  final double depth;
  final Matrix4 transform;
}

class _DiceFaceView extends StatelessWidget {
  const _DiceFaceView({required this.value, required this.size});

  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFB),
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF4ECE6),
          ],
        ),
        border: Border.all(color: const Color(0xFFD6C7BB), width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DicePipPainter(value: value),
      ),
    );
  }
}

class _DicePipPainter extends CustomPainter {
  const _DicePipPainter({required this.value});

  final int value;

  static const _pipPositions = <Offset>[
    Offset(.26, .26), // 0: Top-Left
    Offset(.50, .26), // 1: Top-Center
    Offset(.74, .26), // 2: Top-Right
    Offset(.26, .50), // 3: Mid-Left
    Offset(.50, .50), // 4: Center
    Offset(.74, .50), // 5: Mid-Right
    Offset(.26, .74), // 6: Bot-Left
    Offset(.50, .74), // 7: Bot-Center
    Offset(.74, .74), // 8: Bot-Right
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
    final pips = _pipsByValue[value] ?? {};
    final isOne = value == 1;

    final pipColor = isOne ? const Color(0xFFE53935) : const Color(0xFF2C222E);
    final pipPaint = Paint()..color = pipColor;
    final pipRadius = isOne ? size.width * 0.12 : size.width * 0.075;

    for (final idx in pips) {
      final pos = _pipPositions[idx];
      final center = Offset(size.width * pos.dx, size.height * pos.dy);
      canvas.drawCircle(center, pipRadius, pipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DicePipPainter oldDelegate) =>
      value != oldDelegate.value;
}