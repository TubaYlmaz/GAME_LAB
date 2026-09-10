import 'package:flutter/material.dart';
import '../utils/site_navigation.dart';

class EducationCenterButton extends StatelessWidget {
  const EducationCenterButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Oyunlara dön',
    child: Material(
      color: const Color(0xFF3B342D),
      elevation: 9,
      shadowColor: const Color(0x88D9B96F),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD9B96F), width: 1.5),
      ),
      child: InkWell(
        onTap: goToEducationCenter,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: const Color(0x337F9877),
        splashColor: const Color(0x55D9B96F),
        child: const Center(
          child: Icon(
            Icons.grid_view_rounded,
            color: Color(0xFFF3D88E),
            size: 22,
          ),
        ),
      ),
    ),
  );
}
