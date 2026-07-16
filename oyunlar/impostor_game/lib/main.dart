import 'package:flutter/material.dart';
import 'screens/host_screen.dart';
import 'screens/host_login_screen.dart'; // 👈 EKSİK OLAN SATIR TAM OLARAK BU!
import 'screens/voting_screen.dart';

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
      home: const HostLoginScreen(), // Artık ilk olarak giriş ekranı açılacak!
    );
  }
}
