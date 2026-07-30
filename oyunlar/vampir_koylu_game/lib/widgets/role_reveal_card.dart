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
  bool _isFront = false;
  bool _isReady = false;

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
    if (_isReady) return; // Hazır olduktan sonra kartı çeviremez
    if (_isFront) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  void _handleReady() {
    if (_isReady) return;

    setState(() {
      _isReady = true; // Kartı yükleme durumuna geçir, ekrandan KALDIRMA!
    });

    // Sunucuya "ben hazırımı" bildiriyoruz
    if (widget.onReadySubmitted != null) {
      widget.onReadySubmitted!();
    }
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
          const SizedBox(height: 24),

          AnimatedOpacity(
            opacity: _isFront ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _isReady
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.roleColor.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: widget.roleColor,
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Rolünü onayladın!\nDiğer oyuncuların kartlarını açması bekleniyor...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                : ElevatedButton.icon(
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
                    onPressed: _isFront ? _handleReady : null,
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'ROLÜMÜ ANLADIM VE HAZIRIM',
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

  Widget _buildCardBack() {
    return Container(
      width: 260,
      height: 380,
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
