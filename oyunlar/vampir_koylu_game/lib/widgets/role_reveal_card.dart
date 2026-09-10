import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class RoleRevealCard extends StatefulWidget {
  final String roleName;
  final String roleDescription;
  final Color roleColor;
  final List<String> teamMates;
  final String teamMatesLabel;
  final VoidCallback onDismiss;
  final VoidCallback? onReadySubmitted;

  const RoleRevealCard({
    super.key,
    required this.roleName,
    required this.roleDescription,
    required this.roleColor,
    this.teamMates = const [],
    this.teamMatesLabel = 'EKİP ARKADAŞLARIN:',
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

  int _secondsLeft = 5;
  Timer? _timer;
  bool _isRevealed = false;

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

    // Rol gizli başlar. Oyuncu hazır olduğunda kendisi açar.
  }

  void _revealRole() {
    if (_isRevealed) return;
    setState(() {
      _isRevealed = true;
      _secondsLeft = 5;
    });
    _controller.forward();
    _startAutoCountdown();
  }

  void _startAutoCountdown() {
    _timer?.cancel();
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

    if (mounted) {
      setState(() {
        _isRevealed = false;
      });
      _controller.reverse();
    }

    // Kartı yerel ekrandan temizle veya oyun ekranına geç
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
          GestureDetector(
            onTap: _isRevealed ? null : _revealRole,
            child: AnimatedBuilder(
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
          ),
          const SizedBox(height: 20),

          if (!_isRevealed)
            SizedBox(
              width: 260,
              child: FilledButton.icon(
                onPressed: _revealRole,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('ROLÜMÜ GÖSTER'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE7B5A2),
                  foregroundColor: const Color(0xFF3A171F),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: 260,
              child: FilledButton.icon(
                onPressed: _finishAndClose,
                icon: const Icon(Icons.visibility_off_rounded),
                label: Text('ROLÜ GİZLE ($_secondsLeft sn)'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF251015),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: widget.roleColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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
        color: const Color(0xFF3A171F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7B5A2), width: 2),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 60, color: Color(0xFFE7B5A2)),
          SizedBox(height: 16),
          Text(
            'GİZLİ ROL',
            style: TextStyle(
              color: Color(0xFFE7B5A2),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Hazır olduğunda karta dokun',
            style: TextStyle(color: Colors.white70, fontSize: 13),
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
        color: const Color(0xFF251015),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.roleColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'KİMLİĞİN',
            style: TextStyle(
              color: widget.roleColor.withValues(alpha: 0.8),
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
          Divider(color: widget.roleColor.withValues(alpha: 0.3)),
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
              widget.teamMatesLabel,
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
                  backgroundColor: widget.roleColor.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: widget.roleColor.withValues(alpha: 0.5),
                  ),
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
