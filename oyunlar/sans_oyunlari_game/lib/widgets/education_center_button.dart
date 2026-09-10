import 'package:flutter/material.dart';
import '../utils/site_navigation.dart';

class EducationCenterButton extends StatelessWidget {
  const EducationCenterButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Oyunlara dön',
    child: Material(
      color: const Color(0xFFFFF8EF),
      elevation: 9,
      shadowColor: const Color(0x77D97560),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD97560), width: 1.5),
      ),
      child: InkWell(
        onTap: goToEducationCenter,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: const Color(0x22D97560),
        splashColor: const Color(0x44D97560),
        child: const Center(
          child: Icon(
            Icons.grid_view_rounded,
            color: Color(0xFFD06F5B),
            size: 22,
          ),
        ),
      ),
    ),
  );
}
