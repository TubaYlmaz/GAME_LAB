import 'dart:math';
import 'package:flutter/material.dart';
import 'entry_screen.dart';
import '../player_model.dart';

class GameScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final Gender gender;
  final bool isHost;

  final int vampireCount;
  final int doctorCount;
  final int serialKillerCount;
  final int villagerCount;

  const GameScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.gender,
    required this.isHost,
    required this.vampireCount,
    required this.doctorCount,
    required this.serialKillerCount,
    required this.villagerCount,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  GamePhase _phase = GamePhase.night;
  int _round = 1;
  String? _selectedVoteTargetId;

  late List<String> _logs;
  late List<PlayerModel> _players;
  bool _positionsCalculated = false;

  @override
  void initState() {
    super.initState();
    _logs = [
      'System: Köy kuruldu (${widget.roomCode}).',
      'System: Roller rastgele dağıtıldı ve gece başladı...',
    ];

    _players = _generateAndDistributeRoles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRoleDistributionDebugDialog();
    });
  }

  List<PlayerModel> _generateAndDistributeRoles() {
    List<String> rolePool = [];
    for (int i = 0; i < widget.vampireCount; i++) {
      rolePool.add('Vampir 🧛');
    }
    for (int i = 0; i < widget.doctorCount; i++) {
      rolePool.add('Doktor 🩺');
    }
    for (int i = 0; i < widget.serialKillerCount; i++) {
      rolePool.add('Seri Katil 🔪');
    }
    for (int i = 0; i < widget.villagerCount; i++) {
      rolePool.add('Köylü 🧑‍🌾');
    }

    rolePool.shuffle(Random());

    final totalPlayers = rolePool.length;
    List<PlayerModel> generatedPlayers = [];

    final colors = [
      const Color(0xFF00D2FF),
      const Color(0xFFE74C3C),
      const Color(0xFF9B59B6),
      const Color(0xFF3498DB),
      const Color(0xFF2ECC71),
      const Color(0xFFF39C12),
      const Color(0xFF1ABC9C),
      const Color(0xFFEC407A),
      const Color(0xFFE67E22),
      const Color(0xFF95A5A6),
      const Color(0xFF8E44AD),
      const Color(0xFFD35400),
    ];

    for (int i = 0; i < totalPlayers; i++) {
      String pName = (i == 0)
          ? '${widget.playerName} (Oyuncu 1)'
          : 'Oyuncu ${i + 1}';
      Gender pGender = (i == 0)
          ? widget.gender
          : (i % 2 == 0 ? Gender.male : Gender.female);

      final roleStr = rolePool[i];

      generatedPlayers.add(
        PlayerModel(
          id: 'p_$i',
          name: pName,
          avatarColor: colors[i % colors.length],
          gender: pGender,
          role: roleStr,
          isVampire: roleStr.contains('Vampir'),
        ),
      );
    }

    return generatedPlayers;
  }

  void _calculatePlayerPositions(Size size) {
    if (_positionsCalculated) return;

    final cx = size.width / 2;
    final cy = size.height / 2 + 28;
    final double squareRadius = min(size.width, size.height) * 0.18;
    final double minX = size.width * 0.08;
    final double maxX = size.width * 0.92;
    final double minY = size.height * 0.12;
    final double maxY = size.height * 0.85;

    final rand = Random();

    for (int i = 0; i < _players.length; i++) {
      double x = 0;
      double y = 0;
      bool validPosition = false;
      int attempts = 0;

      final double currentW = _players[i].isAlive ? 180.0 : 110.0;
      final double currentH = _players[i].isAlive ? 150.0 : 90.0;

      while (!validPosition && attempts < 3000) {
        attempts++;
        x = minX + rand.nextDouble() * (maxX - minX);
        y = minY + rand.nextDouble() * (maxY - minY);

        final distanceToCenter = sqrt(pow(x - cx, 2) + pow(y - cy, 2));
        if (distanceToCenter <
            (squareRadius + max(currentW, currentH) / 2 + 10)) {
          continue;
        }

        bool overlaps = false;
        for (int j = 0; j < i; j++) {
          final other = _players[j];
          final double otherW = other.isAlive ? 180.0 : 110.0;
          final double otherH = other.isAlive ? 150.0 : 90.0;

          final bool xOverlap =
              (x - currentW / 2 < other.posX! + otherW / 2 + 10) &&
              (x + currentW / 2 > other.posX! - otherW / 2 - 10);
          final bool yOverlap =
              (y - currentH / 2 < other.posY! + otherH / 2 + 10) &&
              (y + currentH / 2 > other.posY! - otherH / 2 - 10);

          if (xOverlap && yOverlap) {
            overlaps = true;
            break;
          }
        }

        if (!overlaps) validPosition = true;
      }

      _players[i].posX = x;
      _players[i].posY = y;
    }

    _positionsCalculated = true;
  }

  void _showRoleDistributionDebugDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A3E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.bug_report, color: Color(0xFF00D2FF)),
              const SizedBox(width: 8),
              Text(
                'TOPLAM OYUNCU: ${_players.length}',
                style: const TextStyle(
                  color: Color(0xFF00D2FF),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _players.length,
              itemBuilder: (context, index) {
                final p = _players[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.avatarColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          color: p.avatarColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        p.role,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D2FF),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'ANLADIM, OYUNA GEÇ',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMyRoleCard() {
    final myPlayer = _players[0];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13132B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: myPlayer.avatarColor, width: 2),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GİZLİ ROLÜN',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                myPlayer.role,
                style: TextStyle(
                  color: myPlayer.avatarColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startDay() {
    setState(() {
      _phase = GamePhase.dayDiscussion;
      _logs.add('System: Gün doğdu — Köylüler meydanda toplandı!');
    });
  }

  void _startVoting() {
    setState(() {
      _phase = GamePhase.voting;
      _logs.add('System: Oylama başladı. Sağdaki listeden isim seçin...');
    });
  }

  void _submitVote() {
    if (_selectedVoteTargetId == null) return;
    final target = _players.firstWhere((p) => p.id == _selectedVoteTargetId);
    setState(() {
      target.isAlive = false;
      _logs.add('System: ${target.name} elendi! Rolü: [${target.role}]');
      _selectedVoteTargetId = null;
      _round++;
      _phase = GamePhase.night;
      _logs.add('System: Gece çöktü... Tur $_round başladı.');
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
          Image.asset(
            'assets/images/arkaplan.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF13132B)),
          ),
          AnimatedOpacity(
            opacity: isNight ? 0.45 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: Container(color: const Color(0xFF07071F).withOpacity(0.8)),
          ),
          _buildGameCanvas(size),
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
          Positioned(left: 16, bottom: 16, child: _buildGameLog(size)),
          Positioned(right: 16, bottom: 16, child: _buildPlayerStatusPanel()),
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
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D2A).withOpacity(0.9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF00D2FF), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            'KÖY: ${widget.roomCode}',
            style: const TextStyle(
              color: Color(0xFF00D2FF),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.style, color: Color(0xFF00D2FF)),
            tooltip: 'Gizli Rolünü Gör',
            onPressed: _showMyRoleCard,
          ),
          IconButton(
            icon: const Icon(
              Icons.bug_report_outlined,
              color: Colors.orangeAccent,
            ),
            tooltip: 'Algoritma Rol Çıktısı',
            onPressed: _showRoleDistributionDebugDialog,
          ),
          const SizedBox(width: 12),
          Text(
            'Tur $_round',
            style: const TextStyle(color: Color(0xFF8888BB), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCanvas(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 28;
    final inSquare =
        _phase == GamePhase.dayDiscussion || _phase == GamePhase.voting;

    return Stack(
      children: [
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
    final double houseWidth = player.isAlive ? 180.0 : 110.0;
    final double houseHeight = player.isAlive ? 150.0 : 90.0;

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
        Positioned(
          left: hx - (houseWidth / 2),
          top: hy - (houseHeight / 2),
          child: Image.asset(
            player.isAlive
                ? 'assets/images/ev_aktif.png'
                : 'assets/images/ev_yikik.png',
            width: houseWidth,
            height: houseHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              player.isAlive ? Icons.home : Icons.gite_outlined,
              size: 50,
              color: player.isAlive ? player.avatarColor : Colors.grey,
            ),
          ),
        ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A22).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: player.avatarColor.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        '${player.name} ${player.gender == Gender.male ? "👨" : "👩"}',
                        style: TextStyle(
                          color: player.avatarColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Image.asset(
                      'assets/images/karakter.png',
                      width: 32,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person,
                        size: 24,
                        color: player.avatarColor,
                      ),
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
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A22).withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.3)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _logs.length,
        reverse: true,
        itemBuilder: (_, i) => Text(
          _logs[_logs.length - 1 - i],
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildPlayerStatusPanel() {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A22).withOpacity(0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _players.map((p) {
          final isSelected = _selectedVoteTargetId == p.id;
          return GestureDetector(
            onTap: () {
              if (_phase == GamePhase.voting && p.isAlive) {
                setState(() {
                  _selectedVoteTargetId = p.id;
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.redAccent.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? Border.all(color: Colors.redAccent)
                      : null,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: p.isAlive ? p.avatarColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.yellow
                              : (p.isAlive ? Colors.white : Colors.white30),
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_phase == GamePhase.night)
          ElevatedButton(
            onPressed: _startDay,
            child: const Text('GÜNDÜZÜ BAŞLAT'),
          ),
        if (_phase == GamePhase.dayDiscussion)
          ElevatedButton(
            onPressed: _startVoting,
            child: const Text('OYLAMAYI BAŞLAT'),
          ),
        if (_phase == GamePhase.voting)
          ElevatedButton(
            onPressed: _selectedVoteTargetId != null ? _submitVote : null,
            child: Text(
              _selectedVoteTargetId != null ? 'OYU GÖNDER' : 'KİŞİ SEÇİN',
            ),
          ),
      ],
    );
  }
}
