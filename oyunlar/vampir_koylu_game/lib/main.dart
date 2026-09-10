import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/entry_screen.dart';
import 'screens/role_gallery_screen.dart';
import 'services/socket_service.dart';
import 'widgets/education_center_button.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const VampireVillagerApp());
}

class VampireVillagerApp extends StatefulWidget {
  const VampireVillagerApp({super.key});

  @override
  State<VampireVillagerApp> createState() => _VampireVillagerAppState();
}

class _VampireVillagerAppState extends State<VampireVillagerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isBackgrounded =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    SocketService().notifyAppLifecycle(isBackgrounded);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vampir Köylü',
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
        brightness: Brightness.dark,
        fontFamilyFallback: const ['NotoEmoji'],
        scaffoldBackgroundColor: const Color(0xFF090919),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2FF),
          surface: Color(0xFF13132B),
        ),
      ),
      home: Uri.base.queryParameters['roles'] == '1'
          ? const RoleGalleryScreen()
          : const EntryScreen(),
    );
  }
}
