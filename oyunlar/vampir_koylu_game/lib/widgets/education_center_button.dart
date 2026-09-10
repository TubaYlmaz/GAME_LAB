import 'package:flutter/material.dart';
import '../utils/site_navigation.dart';

class EducationCenterButton extends StatelessWidget {
  const EducationCenterButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Oyunlara dön',
    child: Material(
      color: const Color(0xFF4A1822),
      elevation: 9,
      shadowColor: const Color(0x889A4454),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE7B5A2), width: 1.5),
      ),
      child: InkWell(
        onTap: goToEducationCenter,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: const Color(0x33E7B5A2),
        splashColor: const Color(0x55E7B5A2),
        child: const Center(
          child: Icon(
            Icons.grid_view_rounded,
            color: Color(0xFFFFE7DC),
            size: 22,
          ),
        ),
      ),
    ),
  );
}
