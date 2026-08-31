import 'dart:js_interop';

import 'package:web/web.dart' as web;

class KzSoundService {
  KzSoundService._();

  static final instance = KzSoundService._();
  web.AudioContext? _context;

  Future<void> unlock() async => _readyContext();

  Future<web.AudioContext?> _readyContext() async {
    final context = _context ??= web.AudioContext();
    if (context.state == 'suspended') {
      try {
        await context.resume().toDart;
      } catch (_) {
        return null;
      }
    }
    return context;
  }

  Future<void> playBell() async {
    final context = await _readyContext();
    if (context == null) return;
    final now = context.currentTime;
    for (final offset in [0.0, .42, .84, 1.26]) {
      _tone(
        context,
        frequency: 880,
        start: now + offset,
        duration: .34,
        volume: .2,
      );
      _tone(
        context,
        frequency: 1320,
        start: now + offset,
        duration: .25,
        volume: .11,
      );
    }
  }

  Future<void> playYourTurn() async {
    final context = await _readyContext();
    if (context == null) return;
    final now = context.currentTime;
    _tone(context, frequency: 523, start: now, duration: .12, volume: .11);
    _tone(
      context,
      frequency: 784,
      start: now + .13,
      duration: .18,
      volume: .13,
    );
  }

  void _tone(
    web.AudioContext context, {
    required num frequency,
    required num start,
    required num duration,
    required num volume,
  }) {
    final oscillator = context.createOscillator();
    final gain = context.createGain();
    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(frequency, start);
    gain.gain.setValueAtTime(volume, start);
    gain.gain.exponentialRampToValueAtTime(.001, start + duration);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start(start);
    oscillator.stop(start + duration);
  }
}
