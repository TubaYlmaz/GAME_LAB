import 'package:flutter/material.dart';

class KzGameLogo extends StatelessWidget {
  const KzGameLogo({super.key, this.width = 72, this.height = 48});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Stack(
      alignment: Alignment.center,
      children: [
        _card(-.42, -width * .30, const Color(0xFF4E73DF), '3'),
        _card(-.15, -width * .12, const Color(0xFFEF5350), '7'),
        _card(.15, width * .12, const Color(0xFFFFCA4B), '2'),
        _card(.42, width * .30, const Color(0xFF35AD78), '5'),
        Container(
          width: height * .76,
          height: height * .76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF202743),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x66FFCA4B), blurRadius: 10),
            ],
          ),
          child: Text('🔔', style: TextStyle(fontSize: height * .47)),
        ),
      ],
    ),
  );

  Widget _card(double angle, double offset, Color color, String value) =>
      Transform.translate(
        offset: Offset(offset, 2),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: width * .29,
            height: height * .78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white70),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: height * .25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
}
