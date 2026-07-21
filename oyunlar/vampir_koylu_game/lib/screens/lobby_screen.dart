import 'dart:math';
import 'package:flutter/material.dart';
import 'entry_screen.dart';
import 'game_screen.dart';
import '../widgets/role_reveal_card.dart';

class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final Gender gender;
  final bool isHost;

  final int vampireCount;
  final int doctorCount;
  final int serialKillerCount;
  final int villagerCount;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.gender,
    required this.isHost,
    required this.vampireCount,
    this.doctorCount = 1,
    this.serialKillerCount = 1,
    this.villagerCount = 4,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late List<Map<String, dynamic>> _players;

  // Oyun başlama moduna geçildi mi kontrolü
  bool _isGameStarting = false;

  @override
  void initState() {
    super.initState();
    String hostGenderTag = widget.gender == Gender.male ? '(e)' : '(k)';

    _players = [
      {
        'name': '${widget.playerName} $hostGenderTag',
        'isHost': widget.isHost,
        'gender': widget.gender,
      },
      {'name': 'Esmanur (k)', 'isHost': false, 'gender': Gender.female},
    ];
  }

  String _getAvatarAsset(Gender gender) {
    return gender == Gender.female
        ? 'assets/images/k_kiz.png'
        : 'assets/images/k_erkek.png';
  }

  void _navigateToGameScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          roomCode: widget.roomCode,
          playerName: widget.playerName,
          gender: widget.gender,
          isHost: widget.isHost,
          vampireCount: widget.vampireCount,
          doctorCount: widget.doctorCount,
          serialKillerCount: widget.serialKillerCount,
          villagerCount: widget.villagerCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. LOBİ ARKA PLANI (Her zaman sabit kalır)
          Image.asset(
            'assets/images/arkaplan.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF13132B)),
          ),
          const _StarField(),
          Container(color: const Color(0xFF0D0D2A).withOpacity(0.75)),

          // 2. LOBİ ARAYÜZÜ (Sadece kart açılmadığı sürece görünür)
          if (!_isGameStarting)
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A3E).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF00D2FF).withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00D2FF,
                                  ).withOpacity(0.15),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'KÖYLÜLER İÇİN ODA KODU',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.roomCode,
                                  style: const TextStyle(
                                    color: Color(0xFF00D2FF),
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                    shadows: [
                                      Shadow(
                                        color: Color(0xFF00D2FF),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Katılan Oyuncular',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00D2FF,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00D2FF,
                                    ).withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  '${_players.length} Oyuncu',
                                  style: const TextStyle(
                                    color: Color(0xFF00D2FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _players.length,
                            itemBuilder: (context, index) {
                              final player = _players[index];
                              final bool isHost = player['isHost'] ?? false;
                              final Gender pGender =
                                  player['gender'] as Gender? ?? Gender.male;
                              final String avatarPath = _getAvatarAsset(
                                pGender,
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1A1A3E,
                                  ).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00D2FF,
                                    ).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF00D2FF),
                                          width: 1.5,
                                        ),
                                        image: DecorationImage(
                                          image: AssetImage(avatarPath),
                                          fit: BoxFit.cover,
                                          onError: (_, __) {},
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      player['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isHost) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF00D2FF,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF00D2FF),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Text(
                                          'MUHTAR',
                                          style: TextStyle(
                                            color: Color(0xFF00D2FF),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF00D2FF),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _NeonButton(
                      label: 'OYUNU BAŞLAT',
                      icon: Icons.play_arrow_rounded,
                      color: const Color(0xFF00D2FF),
                      large: true,
                      onPressed: () {
                        setState(() {
                          _isGameStarting = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

          // 3. SADECE KART
          if (_isGameStarting)
            Center(
              child: RoleRevealCard(
                roleName: "Vampir 🧛",
                roleDescription:
                    "Geceleri diğer vampirlerle anlaşıp köylüleri avla. Gündüzleri kendini belli etme!",
                roleColor: const Color(0xFFE74C3C),
                onDismiss: () {
                  _navigateToGameScreen();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter(), child: const SizedBox.expand());
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 100; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.0 + 0.3;
      paint.color = Colors.white.withOpacity(rng.nextDouble() * 0.4 + 0.1);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _NeonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool large;

  const _NeonButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.enabled = true,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withOpacity(0.25);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(large ? 14 : 10),
        splashColor: effectiveColor.withOpacity(0.3),
        highlightColor: effectiveColor.withOpacity(0.1),
        child: Ink(
          decoration: BoxDecoration(
            color: effectiveColor.withOpacity(enabled ? 0.18 : 0.05),
            borderRadius: BorderRadius.circular(large ? 14 : 10),
            border: Border.all(color: effectiveColor, width: large ? 1.5 : 1),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: effectiveColor.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: large ? 16 : 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: effectiveColor, size: large ? 20 : 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: effectiveColor,
                    fontSize: large ? 15 : 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
