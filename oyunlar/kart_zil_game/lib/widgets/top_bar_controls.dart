import 'package:flutter/material.dart';

const kzTopBarGradient = LinearGradient(
  colors: [Color(0xFF315EDB), Color(0xFF714FC2), Color(0xFF3478E3)],
);

class KzTopPanel extends StatelessWidget {
  const KzTopPanel({
    super.key,
    required this.text,
    this.onPressed,
    this.trailingIcon,
    this.tooltip,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final panel = Material(
      color: const Color(0xFF263653),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Color(0xFF6FD3D0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        hoverColor: const Color(0x226FD3D0),
        splashColor: const Color(0x446FD3D0),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, color: const Color(0xFF8FE2DF), size: 17),
              ],
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? panel : Tooltip(message: tooltip!, child: panel);
  }
}

class KzTopIconButton extends StatelessWidget {
  const KzTopIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 42,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF263653),
        side: const BorderSide(color: Color(0xFF6FD3D0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      icon: Icon(icon, size: 21),
    ),
  );
}
