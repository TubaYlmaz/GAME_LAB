import 'package:flutter/material.dart';

class KzEducationCenterButton extends StatelessWidget {
  const KzEducationCenterButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: Semantics(
      button: true,
      label: 'Oyunlara dön',
      child: Material(
        color: const Color(0xFF30385D),
        elevation: 7,
        shadowColor: const Color(0xAA8DEBFF),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF8DEBFF), width: 1.4),
        ),
        child: InkWell(
          onTap: onPressed,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: const Color(0x338DEBFF),
          splashColor: const Color(0x558DEBFF),
          child: const Center(
            child: Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    ),
  );
}
