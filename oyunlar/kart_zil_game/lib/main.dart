import 'package:flutter/material.dart';

import 'screens/entry_screen.dart';
import 'screens/game_over_screen.dart';
import 'screens/game_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/round_result_screen.dart';
import 'services/sound_service.dart';
import 'services/socket_service.dart';
import 'widgets/rules_button.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KartZilApp());
}

class KartZilApp extends StatefulWidget {
  const KartZilApp({super.key});
  @override
  State<KartZilApp> createState() => _KartZilAppState();
}

class _KartZilAppState extends State<KartZilApp> with WidgetsBindingObserver {
  final service = KzSocketService.instance;
  String? _previousTurnPlayerId;
  bool _previousBellPressed = false;
  bool _soundStateReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    service.addListener(_handleGameSounds);
    service.connect();
  }

  @override
  void dispose() {
    service.removeListener(_handleGameSounds);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleGameSounds() {
    final state = service.state;
    if (state == null) {
      _previousTurnPlayerId = null;
      _previousBellPressed = false;
      _soundStateReady = false;
      return;
    }

    if (!_soundStateReady) {
      _previousTurnPlayerId = state.currentPlayerId;
      _previousBellPressed = state.bellPressed;
      _soundStateReady = true;
      return;
    }

    if (state.bellPressed &&
        !_previousBellPressed &&
        state.bellPlayerId != service.playerId) {
      KzSoundService.instance.playBell();
    }

    if (state.phase == 'playing' || state.phase == 'final_turn') {
      final me = state.players
          .where((player) => player.id == service.playerId)
          .firstOrNull;
      final turnJustBecameMine =
          state.currentPlayerId == service.playerId &&
          state.currentPlayerId != _previousTurnPlayerId;
      if (turnJustBecameMine && me?.eliminated == false) {
        KzSoundService.instance.playYourTurn();
      }
    }

    _previousTurnPlayerId = state.currentPlayerId;
    _previousBellPressed = state.bellPressed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) service.connect();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kart & Zil',
    debugShowCheckedModeBanner: false,
    builder: (context, child) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => KzSoundService.instance.unlock(),
      child: child!,
    ),
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C83DB),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF202844),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF30385D),
        foregroundColor: Color(0xFFF7F5FF),
      ),
      cardTheme: const CardThemeData(color: Color(0xFF354064)),
    ),
    home: AnimatedBuilder(
      animation: service,
      builder: (context, child) {
        final state = service.state;
        final Widget screen;
        if (state == null) {
          screen = KzEntryScreen();
        } else if (state.phase == 'lobby') {
          screen = KzLobbyScreen();
        } else if (state.phase == 'round_result') {
          screen = KzRoundResultScreen();
        } else if (state.phase == 'game_over') {
          screen = KzGameOverScreen();
        } else {
          screen = KzGameScreen();
        }
        return Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: .97, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(state?.phase ?? 'entry'),
                child: screen,
              ),
            ),
            const Positioned(
              left: 14,
              bottom: 14,
              child: SafeArea(child: KzRulesButton()),
            ),
          ],
        );
      },
    ),
  );
}
