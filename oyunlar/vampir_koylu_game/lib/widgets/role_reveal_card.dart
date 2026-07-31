import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class RoleRevealCard extends StatefulWidget {
  final String roleName;
  final String roleDescription;
  final Color roleColor;
  final List<String> teamMates;
  final VoidCallback onDismiss;
  final VoidCallback? onReadySubmitted;

  const RoleRevealCard({
    super.key,
    required this.roleName,
    required this.roleDescription,
    required this.roleColor,
    this.teamMates = const [],
    required this.onDismiss,
    this.onReadySubmitted,
  });

  @override
  State<RoleRevealCard> createState() => _RoleRevealCardState();
}

class _RoleRevealCardState extends State<RoleRevealCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  int _secondsLeft = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 3D Animasyon Tanımı (800ms yumuşak dönme)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    // Kart doğrudan ön yüzüne dönsün (otomatik açılış)
    _controller.forward();

    // 10 Saniyelik Otomatik Sayacı Başlat
    _startAutoCountdown();
  }

  void _startAutoCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        if (mounted) {
          setState(() {
            _secondsLeft--;
          });
        }
      } else {
        _timer?.cancel();
        _finishAndClose(); // 10 saniye bittiğinde kartı otomatik kapat
      }
    });
  }

  void _finishAndClose() {
    _timer?.cancel();

    if (widget.onReadySubmitted != null) {
      widget.onReadySubmitted!();
    }

    // Kartı yerel ekrandan temizle
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3D Çevrilen Kart
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final angle = _animation.value * pi;
              final isUnder90 = angle < (pi / 2);

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
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
          const SizedBox(height: 20),

          // Alt taraftaki Otomatik Süre Rozeti (Buton Değil, Bilgilendirme)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D2A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.roleColor.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.roleColor.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: widget.roleColor,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Oyun Başlıyor... ($_secondsLeft sn)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 260,
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D2FF), width: 2),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 60, color: Color(0xFF00D2FF)),
          SizedBox(height: 16),
          Text(
            'GİZLİ ROL',
            style: TextStyle(
              color: Color(0xFF00D2FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront() {
    return Container(
      width: 260,
      height: 380,
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
          const SizedBox(height: 12),
          Divider(color: widget.roleColor.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(
            widget.roleDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          if (widget.teamMates.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'TÜM VAMPİRLER:',
              style: TextStyle(
                color: widget.roleColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: widget.teamMates.map((mate) {
                return Chip(
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: -2,
                  ),
                  backgroundColor: widget.roleColor.withOpacity(0.2),
                  side: BorderSide(color: widget.roleColor.withOpacity(0.5)),
                  label: Text(
                    mate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}