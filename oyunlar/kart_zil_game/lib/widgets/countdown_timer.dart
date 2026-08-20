import 'dart:async';

import 'package:flutter/material.dart';

class KzCountdown extends StatefulWidget {
  const KzCountdown({
    super.key,
    required this.deadline,
    required this.serverTime,
  });
  final int deadline, serverTime;
  @override
  State<KzCountdown> createState() => _KzCountdownState();
}

class _KzCountdownState extends State<KzCountdown> {
  Timer? timer;
  late int offset;
  @override
  void initState() {
    super.initState();
    offset = DateTime.now().millisecondsSinceEpoch - widget.serverTime;
    timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant KzCountdown old) {
    super.didUpdateWidget(old);
    if (old.serverTime != widget.serverTime) {
      offset = DateTime.now().millisecondsSinceEpoch - widget.serverTime;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left =
        ((widget.deadline - (DateTime.now().millisecondsSinceEpoch - offset)) /
                1000)
            .ceil()
            .clamp(0, 99);
    return Text(
      '$left sn',
      style: TextStyle(
        fontSize: left <= 5 ? 28 : 20,
        fontWeight: FontWeight.bold,
        color: left <= 5 ? Colors.redAccent : Colors.white,
      ),
    );
  }
}
