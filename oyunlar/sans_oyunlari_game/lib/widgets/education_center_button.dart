import 'package:flutter/material.dart';
import '../utils/site_navigation.dart';

class EducationCenterButton extends StatelessWidget {
  const EducationCenterButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Oyunlara dön',
    child: Material(
      color: const Color(0xFF19172C),
      elevation: 7,
      shadowColor: const Color(0xAAB99AFF),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFB99AFF), width: 1.4),
      ),
      child: InkWell(
        onTap: goToEducationCenter,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: const Color(0x33B99AFF),
        splashColor: const Color(0x55B99AFF),
        child: const Center(
          child: Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
        ),
      ),
    ),
  );
}
