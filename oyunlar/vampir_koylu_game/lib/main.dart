import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/entry_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const VampireVillagerApp());
}

class VampireVillagerApp extends StatelessWidget {
  const VampireVillagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vampir Köylü',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090919),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2FF),
          surface: Color(0xFF13132B),
        ),
      ),
      home: const EntryScreen(), // Uygulama doğruca Giriş Ekranı ile başlar
    );
  }
}
