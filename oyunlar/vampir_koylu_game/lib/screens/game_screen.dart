import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/role_reveal_card.dart';
import '../player_model.dart';
import '../widgets.dart';
import 'entry_screen.dart';

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
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _logs = [
      'Sistem: Köy kuruldu (${widget.roomCode}).',
      'Sistem: Roller rastgele dağıtıldı ve gece başladı...',
      'Sistem: Vampirler uyanıyor...',
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
      String pName = (i == 0) ? widget.playerName : 'Oyuncu ${i + 1}';
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
    if (_positionsCalculated || size.width == 0 || size.height == 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final double squareRadius = min(size.width, size.height) * 0.20;
    final double minX = size.width * 0.12;
    final double maxX = size.width * 0.88;
    final double minY = size.height * 0.18;
    final double maxY = size.height * 0.80;

    final rand = Random(1337);

    for (int i = 0; i < _players.length; i++) {
      double x = 0;
      double y = 0;
      bool validPosition = false;
      int attempts = 0;

      final double currentW = _players[i].isAlive ? 150.0 : 95.0;
      final double currentH = _players[i].isAlive ? 120.0 : 75.0;

      while (!validPosition && attempts < 1500) {
        attempts++;
        x = minX + rand.nextDouble() * (maxX - minX);
        y = minY + rand.nextDouble() * (maxY - minY);

        final distanceToCenter = sqrt(pow(x - cx, 2) + pow(y - cy, 2));
        if (distanceToCenter <
            (squareRadius + max(currentW, currentH) / 2 + 15)) {
          continue;
        }

        bool overlaps = false;
        for (int j = 0; j < i; j++) {
          final other = _players[j];
          final double otherW = other.isAlive ? 150.0 : 95.0;
          final double otherH = other.isAlive ? 120.0 : 75.0;

          final bool xOverlap =
              (x - currentW / 2 < other.posX! + otherW / 2) &&
              (x + currentW / 2 > other.posX! - otherW / 2);
          final bool yOverlap =
              (y - currentH / 2 < other.posY! + otherH / 2) &&
              (y + currentH / 2 > other.posY! - otherH / 2);

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
                    border: Border.all(
                      color: p.avatarColor.withValues(alpha: 0.4),
                    ),
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

  void _startDay() {
    setState(() {
      _phase = GamePhase.dayDiscussion;
      _logs.add('Sistem: Gün ağarıyor — köylüler meydanda toplanıyor!');
    });
  }

  void _startVoting() {
    setState(() {
      _phase = GamePhase.voting;
      _logs.add(
        'Sistem: Oylama evresi başladı. Şüphelendiğiniz kişiye tıklayın...',
      );
    });
  }

  void _submitVote() {
    if (_selectedVoteTargetId == null) return;
    final target = _players.firstWhere((p) => p.id == _selectedVoteTargetId);
    setState(() {
      target.isAlive = false;
      _logs.add(
        'Sistem: ${target.name} köyden sürgün edildi! Rolü: [${target.role}]',
      );
      _selectedVoteTargetId = null;
      _round++;
      _phase = GamePhase.night;
      _logs.add('Sistem: Gece tekrar çöküyor... Tur $_round başladı.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNight = _phase == GamePhase.night;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            _calculatePlayerPositions(size);

            return Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 2.2,
                  boundaryMargin: EdgeInsets.zero,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Stack(
                      children: [
                        Image.asset(
                          'assets/images/arkaplan.png',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        if (isNight) const StarField(),
                        AnimatedOpacity(
                          opacity: isNight ? 0.45 : 0.0,
                          duration: const Duration(milliseconds: 800),
                          child: Container(
                            color: const Color(
                              0xFF07071F,
                            ).withValues(alpha: 0.8),
                          ),
                        ),
                        _buildGameCanvas(size),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: TopBar(phase: _phase, round: _round),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: GameLogPanel(logs: _logs, screenSize: size),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: PlayerStatusPanel(
                    players: _players,
                    phase: _phase,
                    selectedVoteTargetId: _selectedVoteTargetId,
                    onSelectTarget: (id) =>
                        setState(() => _selectedVoteTargetId = id),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildBottomControls()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGameCanvas(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
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

    final double houseWidth = player.isAlive ? 150.0 : 95.0;
    final double houseHeight = player.isAlive ? 120.0 : 75.0;

    final double tx;
    final double ty;
    if (inSquare && player.isAlive) {
      final spread = 35.0;
      final innerAngle = (2 * pi * index / total);
      tx = cx + spread * cos(innerAngle) - 15;
      ty = cy + spread * sin(innerAngle) - 25;
    } else {
      tx = hx - 15;
      ty = hy + (houseHeight / 5);
    }

    final isSelected = _selectedVoteTargetId == player.id;

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
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                player.isAlive ? Icons.home_rounded : Icons.gite_outlined,
                size: 42,
                color: player.isAlive ? player.avatarColor : Colors.white24,
              );
            },
          ),
        ),
        if (!player.isAlive)
          Positioned(
            left: hx - 8,
            top: hy + (houseHeight / 2) - 12,
            child: const Text('🪦', style: TextStyle(fontSize: 13)),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
          left: tx,
          top: ty,
          child: player.isAlive
              ? GestureDetector(
                  onTap: () {
                    if (_phase == GamePhase.voting) {
                      setState(() {
                        _selectedVoteTargetId = player.id;
                      });
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.redAccent.withValues(alpha: 0.9)
                              : const Color(0xFF090919).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? Colors.yellow
                                : player.avatarColor.withValues(alpha: 0.6),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          player.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : player.avatarColor,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Image.asset(
                        'assets/images/karakter.png',
                        width: 26,
                        height: 30,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.accessibility_new_rounded,
                            size: 20,
                            color: player.avatarColor,
                          );
                        },
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_phase == GamePhase.night)
              NeonButton(
                label: 'GÜNDÜZÜ BAŞLAT',
                icon: Icons.wb_sunny_outlined,
                color: const Color(0xFFF39C12),
                onPressed: _startDay,
              ),
            if (_phase == GamePhase.dayDiscussion)
              NeonButton(
                label: 'OYLAMAYA GEÇ',
                icon: Icons.how_to_vote_outlined,
                color: const Color(0xFF00D2FF),
                onPressed: _startVoting,
              ),
          ],
        ),
        if (_phase == GamePhase.voting) ...[
          const SizedBox(height: 6),
          NeonButton(
            label: _selectedVoteTargetId != null
                ? 'OYU ONAYLA'
                : 'OYUNCU SEÇİN',
            icon: Icons.gavel_rounded,
            color: _selectedVoteTargetId != null
                ? const Color(0xFFE74C3C)
                : const Color(0xFF00D2FF),
            enabled: _selectedVoteTargetId != null,
            onPressed: _submitVote,
            large: true,
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}
