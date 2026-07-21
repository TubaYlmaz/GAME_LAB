import 'dart:math';
import 'package:flutter/material.dart';

class RoleRevealCard extends StatefulWidget {
  final String roleName;
  final String roleDescription;
  final Color roleColor;
  final VoidCallback onDismiss;

  const RoleRevealCard({
    super.key,
    required this.roleName,
    required this.roleDescription,
    required this.roleColor,
    required this.onDismiss,
  });

  @override
  State<RoleRevealCard> createState() => _RoleRevealCardState();
}

class _RoleRevealCardState extends State<RoleRevealCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggleCard,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final angle = _animation.value * pi;
                final isUnder90 = angle < (pi / 2);

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // 3D Perspektif
                    ..rotateY(angle),
                  alignment: Alignment.center,
                  child: isUnder90
                      ? _buildCardBack()
                      : Transform(
                          transform: Matrix4.identity()..rotateY(pi),
                          alignment: Alignment.center,
                          child: _buildCardFront(),
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Kart açıldığında beliren onay/hazır butonu
          AnimatedOpacity(
            opacity: _isFront ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.roleColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
              ),
              onPressed: _isFront ? widget.onDismiss : null,
              icon: const Icon(Icons.visibility_off, color: Colors.black),
              label: const Text(
                'ROLÜMÜ GİZLE VE BAŞLA',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // KARTIN ARKA YÜZÜ (GİZLİ DURUM)
  Widget _buildCardBack() {
    return Container(
      width: 250,
      height: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D2FF), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D2FF).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 60, color: Color(0xFF00D2FF)),
          const SizedBox(height: 16),
          const Text(
            'GİZLİ ROL',
            style: TextStyle(
              color: Color(0xFF00D2FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dokun ve rolünü gör',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // KARTIN ÖN YÜZÜ (ROL GÖSTERİMİ)
  Widget _buildCardFront() {
    return Container(
      width: 250,
      height: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.roleColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: widget.roleColor.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'KİMLİĞİN',
            style: TextStyle(
              color: widget.roleColor.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.roleName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.roleColor,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: widget.roleColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            widget.roleDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
