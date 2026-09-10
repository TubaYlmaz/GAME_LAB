import 'package:flutter/material.dart';

class KzEducationCenterButton extends StatelessWidget {
  const KzEducationCenterButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 42,
    child: Semantics(
      button: true,
      label: 'Oyunlara dön',
      child: Material(
        color: const Color(0xFF263653),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: Color(0xFF6FD3D0)),
        ),
        child: InkWell(
          onTap: onPressed,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: const Color(0x336FD3D0),
          splashColor: const Color(0x556FD3D0),
          child: const Center(
            child: Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    ),
  );
}
