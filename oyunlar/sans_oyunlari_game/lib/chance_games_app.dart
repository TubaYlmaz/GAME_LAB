import 'package:flutter/material.dart';

import 'screens/chance_game_screen.dart';
import 'widgets/education_center_button.dart';

class ChanceGamesApp extends StatelessWidget {
  const ChanceGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zar & Yazı-Tura',
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
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD97560),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4EEE5),
      ),
      home: const ChanceGameScreen(),
    );
  }
}
