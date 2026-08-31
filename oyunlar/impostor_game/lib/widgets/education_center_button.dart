import 'package:flutter/material.dart';
import '../utils/site_navigation.dart';

class EducationCenterButton extends StatelessWidget {
  const EducationCenterButton({super.key});

  @override
  Widget build(BuildContext context) => _IconTile(
    borderColor: const Color(0xFF00D2FF),
    onTap: goToEducationCenter,
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.borderColor, required this.onTap});
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Oyunlara dön',
    child: Material(
      color: const Color(0xFF19192E),
      elevation: 7,
      shadowColor: borderColor.withValues(alpha: .65),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1.4),
      ),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: borderColor.withValues(alpha: .18),
        splashColor: borderColor.withValues(alpha: .32),
        highlightColor: borderColor.withValues(alpha: .12),
        child: const Center(
          child: Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
        ),
      ),
    ),
  );
}
