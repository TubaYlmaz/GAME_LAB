import 'package:flutter/material.dart';
import 'screens/host_login_screen.dart';
import 'widgets/education_center_button.dart';

void main() {
  runApp(const ImpostorGameApp());
}

class ImpostorGameApp extends StatelessWidget {
  const ImpostorGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impostor Educational Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
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
      home: const HostLoginScreen(),
    );
  }
}
