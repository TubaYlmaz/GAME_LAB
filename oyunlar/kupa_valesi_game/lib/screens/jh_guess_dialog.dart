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
  static const _symbols = ['\u2665', '\u2660', '\u2666', '\u2663'];
  Timer? _ticker;
  String? _selected;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _locked = widget.initiallyLocked;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.cellEndsAt <= _serverNow) {
        _ticker?.cancel();
      }
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

  Color _symbolColor(String symbol) {
    return symbol == '\u2665' || symbol == '\u2666'
        ? const Color(0xFFFF426E)
        : const Color(0xFFE9EEF7);
  }

  @override
  Widget build(BuildContext context) {
    final expired = widget.cellEndsAt <= _serverNow;
    return Dialog(
      backgroundColor: const Color(0xFF141524),
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x88FF426E)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_rounded,
                color: Color(0xFFFF426E),
                size: 38,
              ),
              const SizedBox(height: 8),
              const Text(
                'H\u00DCCRE: SEMBOL\u00DCN\u00DC TAHM\u0130N ET',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                expired
                    ? 'S\u00FCre doldu; sonu\u00E7 bekleniyor.'
                    : 'Kalan s\u00FCre: ${remainingText(widget.cellEndsAt, nowMilliseconds: _serverNow)}',
                style: TextStyle(
                  color: expired
                      ? const Color(0xFFFFD166)
                      : const Color(0xFF77E6FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: _symbols.map((symbol) {
                  final selected = _selected == symbol;
                  return InkWell(
                    onTap: _locked || expired
                        ? null
                        : () => setState(() => _selected = symbol),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 104,
                      height: 104,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0x33FF426E)
                            : const Color(0xFF202238),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFF426E)
                              : const Color(0x55FFFFFF),
                          width: selected ? 3 : 1,
                        ),
                      ),
                      child: Text(
                        symbol,
                        style: TextStyle(
                          fontSize: 58,
                          color: _symbolColor(symbol),
                          height: 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              JhButton(
                label: _locked
                    ? 'OYUN K\u0130L\u0130TLEND\u0130'
                    : 'OYU K\u0130L\u0130TLE',
                icon: _locked ? Icons.lock : Icons.lock_open_rounded,
                enabled: _selected != null && !_locked && !expired,
                onPressed: _lockGuess,
              ),
              if (_locked) ...[
                const SizedBox(height: 10),
                const Text(
                  'Se\u00E7imin de\u011Fi\u015ftirilemez.',
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
