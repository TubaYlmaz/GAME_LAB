import 'dart:async';

import 'package:flutter/material.dart';

import '../services/jh_socket_service.dart';
import '../widgets/jh_ui.dart';

class JhGuessDialog extends StatefulWidget {
  const JhGuessDialog({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.cellEndsAt,
    required this.serverTimeOffsetMs,
    required this.initiallyLocked,
  });
  final String roomCode;
  final String playerName;
  final int cellEndsAt;
  final int serverTimeOffsetMs;
  final bool initiallyLocked;

  @override
  State<JhGuessDialog> createState() => _JhGuessDialogState();
}

class _JhGuessDialogState extends State<JhGuessDialog> {
  static const _symbols = ['☀', '☾', '★', '☁'];
  static const _names = {'☀': 'Güneş', '☾': 'Ay', '★': 'Yıldız', '☁': 'Bulut'};
  Timer? _ticker;
  String? _selected;
  String? _openingSymbol;
  late bool _locked;
  bool _doorOpen = false;

  @override
  void initState() {
    super.initState();
    _locked = widget.initiallyLocked;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.cellEndsAt <= _serverNow) _ticker?.cancel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _serverNow =>
      DateTime.now().millisecondsSinceEpoch + widget.serverTimeOffsetMs;

  void _lockGuess() {
    if (_selected == null || _locked) return;
    JhSocketService.instance.socket?.emit('jh_submit_guess', {
      'roomCode': widget.roomCode,
      'playerName': widget.playerName,
      'guessSymbol': _selected,
      'isLocking': true,
    });
    setState(() => _locked = true);
  }

  Color _symbolColor(String value) => switch (value) {
    '☀' => const Color(0xFFE7C98A),
    '☾' => const Color(0xFF9CAF96),
    '★' => const Color(0xFFD9826B),
    _ => const Color(0xFFF4EBDD),
  };

  void _openDoor(String symbol) {
    if (_locked || widget.cellEndsAt <= _serverNow) return;
    setState(() {
      _openingSymbol = symbol;
      _selected = null;
      _doorOpen = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 720), () {
      if (!mounted || _openingSymbol != symbol) return;
      setState(() {
        _selected = symbol;
        _doorOpen = true;
      });
    });
  }

  Widget _symbolDoor(String symbol, bool expired) {
    final open = _selected == symbol;
    final opening = _openingSymbol == symbol;
    return InkWell(
      onTap: _locked || expired ? null : () => _openDoor(symbol),
      borderRadius: BorderRadius.circular(15),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: opening ? 1 : 0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) => AnimatedScale(
          scale: opening ? 1.035 : 1,
          duration: const Duration(milliseconds: 500),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF171D18),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: open ? const Color(0xFF9CAF96) : const Color(0xFF9B765F),
                width: open ? 3 : 2,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 10),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Transform.scale(
                    scale: .72 + (value * .28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          symbol,
                          style: TextStyle(
                            color: _symbolColor(symbol),
                            fontSize: 36,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          open ? '${_names[symbol]} SEÇİLDİ' : 'İÇERİ GİR',
                          style: const TextStyle(
                            color: Color(0xFFF4EBDD),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!open)
                  Positioned.fill(
                    child: Transform(
                      alignment: Alignment.centerLeft,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .0014)
                        ..rotateY(-1.36 * value),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6F5142),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0xFF9B765F)),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    symbol,
                                    style: TextStyle(
                                      color: _symbolColor(symbol),
                                      fontSize: 30,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    _names[symbol]!,
                                    style: const TextStyle(
                                      color: Color(0xFFF4EBDD),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE7C98A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secretRoom(bool expired) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _symbols.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisExtent: 108,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemBuilder: (_, index) => _symbolDoor(_symbols[index], expired),
  );

  @override
  Widget build(BuildContext context) {
    final expired = widget.cellEndsAt <= _serverNow;
    return Dialog(
      backgroundColor: const Color(0xFF2B2420),
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x99D9826B)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.meeting_room_rounded,
                color: Color(0xFFE7C98A),
                size: 38,
              ),
              const SizedBox(height: 8),
              const Text(
                'GİZLİ ODA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Dört kapıdan birini aç ve gizli sembolünü tahmin et.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                expired
                    ? 'Süre doldu; sonuç bekleniyor.'
                    : 'Kalan süre: ${remainingText(widget.cellEndsAt, nowMilliseconds: _serverNow)}',
                style: TextStyle(
                  color: expired
                      ? const Color(0xFFE7C98A)
                      : const Color(0xFF9CAF96),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              _secretRoom(expired),
              const SizedBox(height: 18),
              JhButton(
                label: _locked ? 'SEMBOL KİLİTLENDİ' : 'SEMBOLÜ KİLİTLE',
                icon: _locked ? Icons.lock : Icons.lock_open_rounded,
                enabled: _doorOpen && _selected != null && !_locked && !expired,
                onPressed: _lockGuess,
              ),
              if (_locked) ...[
                const SizedBox(height: 10),
                const Text(
                  'Seçimin değiştirilemez.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
