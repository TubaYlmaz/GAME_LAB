import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const VampireVillagerApp());
}

class VampireVillagerApp extends StatelessWidget {
  const VampireVillagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vampire Villager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF13132B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2FF),
          surface: Color(0xFF1A1A3E),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

enum GamePhase { night, dayDiscussion, voting }

class PlayerModel {
  final String id;
  final String name;
  final Color avatarColor;
  bool isAlive;
  bool isVampire;

  // 🏡 Her oyuncunun tamamen rastgele, çakışmasız sabit koordinatları
  double? posX;
  double? posY;

  PlayerModel({
    required this.id,
    required this.name,
    required this.avatarColor,
    this.isAlive = true,
    this.isVampire = false,
  });
}

// ─── Game Screen ──────────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  GamePhase _phase = GamePhase.night;
  int _round = 1;
  String? _selectedVoteTargetId;

  final List<String> _logs = [
    'System: Welcome to Vampire Villager!',
    'System: Night falls upon the village...',
    'System: Vampires are awakening...',
    'System: Villagers, stay vigilant.',
  ];

  late List<PlayerModel> _players;
  late AnimationController _phaseAnimController;
  bool _positionsCalculated = false;

  @override
  void initState() {
    super.initState();
    _players = _buildPlayers();
    _phaseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _players[5].isAlive = false;
  }

  List<PlayerModel> _buildPlayers() {
    final names = [
      'Aldric', 'Brenna', 'Corvus', 'Delara',
      'Enzo', 'Fiora', 'Gareth', 'Helia',
    ];
    final colors = [
      const Color(0xFFE74C3C),
      const Color(0xFF9B59B6),
      const Color(0xFF3498DB),
      const Color(0xFF2ECC71),
      const Color(0xFFF39C12),
      const Color(0xFF1ABC9C),
      const Color(0xFFE67E22),
      const Color(0xFFEC407A),
    ];
    return List.generate(8, (i) => PlayerModel(
      id: 'p$i',
      name: names[i],
      avatarColor: colors[i],
      isVampire: i == 0 || i == 3,
    ));
  }

  // 🧠 ASLA ÇAKIŞMAYAN VE RESMİN ORTASINDAKİ MEYDANI BOŞ BIRAKAN RASTGELE YERLEŞİM MOTORU
  void _calculatePlayerPositions(Size size) {
    if (_positionsCalculated) return;

    final cx = size.width / 2;
    final cy = size.height / 2 + 28;
    
    // Görselindeki taş meydanın tahmini kapladığı alan (Burası boş kalacak kanka)
    final double squareRadius = min(size.width, size.height) * 0.22;
    
    // Taşmayı önlemek için ekrandaki güvenli sınırlar
    final double minX = size.width * 0.10;
    final double maxX = size.width * 0.90;
    final double minY = size.height * 0.15;
    final double maxY = size.height * 0.82;

    final rand = Random(1337); 

    for (int i = 0; i < _players.length; i++) {
      double x = 0;
      double y = 0;
      bool validPosition = false;
      int attempts = 0;

      final double currentW = _players[i].isAlive ? 220.0 : 125.0;
      final double currentH = _players[i].isAlive ? 180.0 : 105.0;

      while (!validPosition && attempts < 2000) {
        attempts++;
        x = minX + rand.nextDouble() * (maxX - minX);
        y = minY + rand.nextDouble() * (maxY - minY);

        // 1. KONTROL: Resmin ortasındaki taş meydana denk geliyor mu? (Meydanı boş bırakır)
        final distanceToCenter = sqrt(pow(x - cx, 2) + pow(y - cy, 2));
        if (distanceToCenter < (squareRadius + max(currentW, currentH) / 2 + 20)) {
          continue; 
        }

        // 2. KONTROL: Diğer yerleşen evlerle çakışıyor mu? (ASLA ÇAKIŞMAZ! 🚀)
        bool overlaps = false;
        for (int j = 0; j < i; j++) {
          final other = _players[j];
          final double otherW = other.isAlive ? 220.0 : 125.0;
          final double otherH = other.isAlive ? 180.0 : 105.0;

          final bool xOverlap = (x - currentW / 2 < other.posX! + otherW / 2) && (x + currentW / 2 > other.posX! - otherW / 2);
          final bool yOverlap = (y - currentH / 2 < other.posY! + otherH / 2) && (y + currentH / 2 > other.posY! - otherH / 2);

          if (xOverlap && yOverlap) {
            overlaps = true;
            break;
          }
        }

        if (!overlaps) {
          validPosition = true;
        }
      }

      _players[i].posX = x;
      _players[i].posY = y;
    }

    _positionsCalculated = true;
  }

  void _startDay() {
    setState(() {
      _phase = GamePhase.dayDiscussion;
      _logs.add('System: Dawn breaks — citizens gather in the square!');
    });
  }

  void _startVoting() {
    setState(() {
      _phase = GamePhase.voting;
      _logs.add('System: Voting phase begins. Choose wisely...');
    });
  }

  void _submitVote() {
    if (_selectedVoteTargetId == null) return;
    final target = _players.firstWhere((p) => p.id == _selectedVoteTargetId);
    setState(() {
      target.isAlive = false;
      _logs.add(
        'System: ${target.name} was voted out! '
        '${target.isVampire ? "🧛 A Vampire revealed!" : "🪦 An innocent soul..."}',
      );
      _selectedVoteTargetId = null;
      _round++;
      _phase = GamePhase.night;
      _logs.add('System: Night falls again... Round $_round begins.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isNight = _phase == GamePhase.night;

    _calculatePlayerPositions(size);

    return Scaffold(
      body: Stack(
        children: [
          // 🪨 ARKA PLAN GÖRSELİ
          Image.asset(
            'assets/images/arkaplan.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // Geceleri parıldayan yıldızlar efekti
          if (isNight) const _StarField(),

          // Gelişmiş Gece Işık Overlay'i
          AnimatedOpacity(
            opacity: isNight ? 0.45 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: Container(
              color: const Color(0xFF07071F).withValues(alpha: 0.8),
            ),
          ),

          // Ana Harita Katmanı (Evler ve Piyonlar)
          _buildGameCanvas(size),

          // Üst HUD Barı
          _buildTopBar(),

          // Game log (Sol Alt)
          Positioned(
            left: 16,
            bottom: 16,
            child: _buildGameLog(size),
          ),

          // Oyuncu Listesi (Sağ Alt)
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildPlayerStatusPanel(),
          ),

          // Orta Alt Kontrol Butonları
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final phaseLabel = switch (_phase) {
      GamePhase.night => '🌑  Night Phase',
      GamePhase.dayDiscussion => '☀️  Day Discussion',
      GamePhase.voting => '🗳️  Voting Phase',
    };
    final phaseColor = switch (_phase) {
      GamePhase.night => const Color(0xFF9B59B6),
      GamePhase.dayDiscussion => const Color(0xFFF39C12),
      GamePhase.voting => const Color(0xFF00D2FF),
    };
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2A).withValues(alpha: 0.9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF00D2FF), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Text(
            'VAMPIRE  VILLAGER',
            style: TextStyle(
              color: Color(0xFF00D2FF),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: phaseColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: phaseColor, width: 1),
            ),
            child: Text(
              phaseLabel,
              style: TextStyle(
                color: phaseColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Text(
            'Round  $_round',
            style: const TextStyle(
              color: Color(0xFF8888BB),
              fontSize: 13,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCanvas(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 28;
    final inSquare = _phase == GamePhase.dayDiscussion || _phase == GamePhase.voting;

    return Stack(
      children: [
        // 🛑 BURADAKİ ESKİ YAZILI VE HİLALLİ _VillageSquare KATMANI TAMAMEN SİLİNDİ KANKA!

        // Tamamen rastgele, çakışmasız dağıtılan evler ve piyonlar
        for (int i = 0; i < _players.length; i++)
          _buildPlayerSlot(
            player: _players[i],
            index: i,
            total: _players.length,
            cx: cx,
            cy: cy,
            inSquare: inSquare,
          ),
      ],
    );
  }

  Widget _buildPlayerSlot({
    required PlayerModel player,
    required int index,
    required int total,
    required double cx,
    required double cy,
    required bool inSquare,
  }) {
    final hx = player.posX ?? cx;
    final hy = player.posY ?? cy;

    final double houseWidth = player.isAlive ? 220.0 : 125.0;
    final double houseHeight = player.isAlive ? 180.0 : 105.0;

    final double tx;
    final double ty;
    if (inSquare && player.isAlive) {
      final spread = 45.0; 
      final innerAngle = (2 * pi * index / total);
      tx = cx + spread * cos(innerAngle) - 20;
      ty = cy + spread * sin(innerAngle) - 35;
    } else {
      tx = hx - 20; 
      ty = hy + (houseHeight / 4) - (player.isAlive ? 5 : -5);
    }

    return Stack(
      children: [
        // 🏡 ASLA ÇAKIŞMAYAN RANDOM EVLER
        Positioned(
          left: hx - (houseWidth / 2), 
          top: hy - (houseHeight / 2),  
          child: Image.asset(
            player.isAlive ? 'assets/images/ev_aktif.png' : 'assets/images/ev_yikik.png',
            width: houseWidth,    
            height: houseHeight,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                player.isAlive ? Icons.home : Icons.gite_outlined, 
                size: 60, 
                color: player.isAlive ? player.avatarColor : Colors.grey
              );
            },
          ),
        ),
        
        // Mezar Taşı
        if (!player.isAlive)
          Positioned(
            left: hx - 10,
            top: hy + (houseHeight / 2) - 15, 
            child: const Text('🪦', style: TextStyle(fontSize: 16)),
          ),

        // 🏃‍♂️ PÜRÜZSÜZ AVATARLAR
        AnimatedPositioned(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOutCubic,
          left: tx,
          top: ty,
          child: player.isAlive
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A22).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: player.avatarColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        player.name,
                        style: TextStyle(color: player.avatarColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Image.asset(
                      'assets/images/karakter.png',
                      width: 36,
                      height: 40,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.accessibility_new, size: 26, color: player.avatarColor);
                      },
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildGameLog(Size screenSize) {
    final w = min(screenSize.width * 0.28, 340.0);
    return Container(
      width: w,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A22).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: const Color(0xFF00D2FF).withValues(alpha: 0.25))),
            ),
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: Color(0xFF00D2FF), size: 14),
                SizedBox(width: 6),
                Text('GAME LOG', style: TextStyle(color: Color(0xFF00D2FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              reverse: true,
              itemBuilder: (_, i) {
                final log = _logs[_logs.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(log, style: TextStyle(color: const Color(0xFFCCCCDD).withValues(alpha: 0.85), fontSize: 11, height: 1.4)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatusPanel() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A22).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: const Color(0xFF00D2FF).withValues(alpha: 0.25))),
            ),
            child: const Row(
              children: [
                Icon(Icons.people_outline, color: Color(0xFF00D2FF), size: 14),
                SizedBox(width: 6),
                Text('PLAYERS', style: TextStyle(color: Color(0xFF00D2FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ),
          ..._players.map((p) => _buildPlayerStatusRow(p)),
        ],
      ),
    );
  }

  Widget _buildPlayerStatusRow(PlayerModel player) {
    final isVoteTarget = _selectedVoteTargetId == player.id;
    final canVote = _phase == GamePhase.voting && player.isAlive;
    return GestureDetector(
      onTap: canVote ? () => setState(() => _selectedVoteTargetId = isVoteTarget ? null : player.id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isVoteTarget ? const Color(0xFF00D2FF).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isVoteTarget ? const Color(0xFF00D2FF) : Colors.transparent, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: player.isAlive ? player.avatarColor : const Color(0xFF444466),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                player.name,
                style: TextStyle(
                  color: player.isAlive ? const Color(0xFFCCCCDD) : const Color(0xFF555577),
                  fontSize: 12,
                  decoration: player.isAlive ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (!player.isAlive) const Text('🪦', style: TextStyle(fontSize: 11)),
            if (canVote && !isVoteTarget) Icon(Icons.how_to_vote_outlined, size: 13, color: const Color(0xFF00D2FF).withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_phase == GamePhase.night)
              _NeonButton(label: 'TEST: START DAY', icon: Icons.wb_sunny_outlined, color: const Color(0xFFF39C12), onPressed: _startDay),
            if (_phase == GamePhase.dayDiscussion)
              _NeonButton(label: 'START VOTING', icon: Icons.how_to_vote_outlined, color: const Color(0xFF00D2FF), onPressed: _startVoting),
          ],
        ),
        const SizedBox(height: 10),
        _NeonButton(
          label: 'SUBMIT VOTE',
          icon: Icons.gavel,
          color: const Color(0xFF00D2FF),
          enabled: _phase == GamePhase.voting && _selectedVoteTargetId != null,
          onPressed: _submitVote,
          large: true,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  @override
  void dispose() {
    _phaseAnimController.dispose();
    super.dispose();
  }
}

// ─── Yıldızlar Efekti ──────────────────────────────────────────────────────────

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarPainter(),
      child: const SizedBox.expand(),
    );
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
      paint.color = Colors.white.withValues(alpha: rng.nextDouble() * 0.4 + 0.1);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Neon Button ──────────────────────────────────────────────────────────────

class _NeonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
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
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.25);
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: large ? 36 : 24,
          vertical: large ? 14 : 10,
        ),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: enabled ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(large ? 14 : 10),
          border: Border.all(color: effectiveColor, width: large ? 1.5 : 1),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: effectiveColor, size: large ? 18 : 15),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: large ? 14 : 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}