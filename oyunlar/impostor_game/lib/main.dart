import 'package:flutter/material.dart';
import 'screens/host_login_screen.dart';
import 'widgets/education_center_button.dart';

void main() {
  runApp(const ImpostorGameApp());
}

final ValueNotifier<bool> _isEntryScreen = ValueNotifier<bool>(true);

class _GameRouteObserver extends NavigatorObserver {
  void _update(Route<dynamic>? route) {
    _isEntryScreen.value = route?.isFirst ?? true;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _update(newRoute);
  }
}

class ImpostorGameApp extends StatelessWidget {
  const ImpostorGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impostor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      navigatorObservers: [_GameRouteObserver()],
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: _isEntryScreen,
        builder: (context, isEntryScreen, _) => Stack(
          children: [
            child!,
            Positioned(
              top: 10,
              left: 10,
              width: 52,
              height: 52,
              child: const SafeArea(child: EducationCenterButton()),
            ),
          ],
        ),
      ),
      home: const HostLoginScreen(),
    );
  }
}
