import 'package:flutter/material.dart';

import 'screens/entry_screen.dart';
import 'screens/game_over_screen.dart';
import 'screens/game_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/round_result_screen.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    service.connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) service.connect();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kart & Zil',
    debugShowCheckedModeBanner: false,
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
