import 'package:flutter/material.dart';

import 'screens/chance_game_screen.dart';
import 'widgets/education_center_button.dart';

class ChanceGamesApp extends StatelessWidget {
  const ChanceGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '\u015eans Oyunlar\u0131',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Stack(
        children: [
          child!,
          const Positioned(
            top: 10,
            left: 10,
            width: 52,
            height: 52,
            child: SafeArea(child: EducationCenterButton()),
          ),
        ],
      ),
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
