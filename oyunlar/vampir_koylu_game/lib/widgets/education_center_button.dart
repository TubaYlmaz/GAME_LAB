import 'package:flutter/material.dart';
import '../utils/site_navigation.dart';

class EducationCenterButton extends StatelessWidget {
  const EducationCenterButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Oyunlara dön',
    child: Material(
      color: const Color(0xFF13132B),
      elevation: 7,
      shadowColor: const Color(0xAA00D2FF),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF00D2FF), width: 1.4),
      ),
      child: InkWell(
        onTap: goToEducationCenter,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: const Color(0x3300D2FF),
        splashColor: const Color(0x5500D2FF),
        child: const Center(
          child: Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
        ),
      ),
    ),
  );
}
