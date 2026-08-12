import 'package:flutter/material.dart';

import 'screens/chance_game_screen.dart';

class ChanceGamesApp extends StatelessWidget {
  const ChanceGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '\u015eans Oyunlar\u0131',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF10101D),
      ),
      home: const ChanceGameScreen(),
    );
  }
}
