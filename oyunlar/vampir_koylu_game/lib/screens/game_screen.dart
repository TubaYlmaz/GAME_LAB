import 'dart:math';
import 'package:flutter/material.dart';

// Modeller ve Ekranlar
import 'entry_screen.dart';
import '../player_model.dart';

// Widget Parçaları
import '../widgets/game_map.dart';
import '../widgets/game_hud.dart';
import '../widgets/mobile_hud.dart';
import '../widgets/game_dialogs.dart';

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

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _logs = [
      'System: Köy kuruldu (${widget.roomCode}).',
      'System: Roller rastgele dağıtıldı ve gece başladı...',
    ];

    _players = _generateAndDistributeRoles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      GameDialogs.showRoleDistributionDebug(context, _players);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  List<PlayerModel> _generateAndDistributeRoles() {
    List<String> rolePool = [];
    for (int i = 0; i < widget.vampireCount; i++) rolePool.add('Vampir 🧛');
    for (int i = 0; i < widget.doctorCount; i++) rolePool.add('Doktor 🩺');
    for (int i = 0; i < widget.serialKillerCount; i++) rolePool.add('Seri Katil 🔪');
    for (int i = 0; i < widget.villagerCount; i++) rolePool.add('Köylü 🧑‍🌾');

    rolePool.shuffle(Random());

    final totalPlayers = rolePool.length;
    List<PlayerModel> generatedPlayers = [];

    final colors = [
      const Color(0xFF00D2FF), const Color(0xFFE74C3C), const Color(0xFF9B59B6),
      const Color(0xFF3498DB), const Color(0xFF2ECC71), const Color(0xFFF39C12),
      const Color(0xFF1ABC9C), const Color(0xFFEC407A), const Color(0xFFE67E22),
      const Color(0xFF95A5A6), const Color(0xFF8E44AD), const Color(0xFFD35400),
    ];

    for (int i = 0; i < totalPlayers; i++) {
      Gender pGender = (i == 0) ? widget.gender : (i % 2 == 0 ? Gender.male : Gender.female);
      String genderTag = pGender == Gender.male ? '(e)' : '(k)';
      String pName = (i == 0) ? '${widget.playerName} $genderTag' : 'Oyuncu ${i + 1} $genderTag';
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

    // --- ORTA MEYDAN / DİSK KORUMASI ---
    // Mobilde genişlik dar olsa dahi meydan yarıçapının min 120px olmasını sağladık
    final double calculatedRadius = min(size.width, size.height) * 0.22;
    final double squareRadius = max(calculatedRadius, 120.0);

    // Evlerin serpilebileceği sınırlar
    final double minX = size.width * 0.06;
    final double maxX = size.width * 0.94;
    final double minY = size.height * 0.10;
    final double maxY = size.height * 0.88;

    final rand = Random();

    for (int i = 0; i < _players.length; i++) {
      double x = 0;
      double y = 0;
      bool validPosition = false;
      int attempts = 0;

      final double currentW = _players[i].isAlive ? 180.0 : 110.0;
      final double currentH = _players[i].isAlive ? 150.0 : 90.0;

      while (!validPosition && attempts < 4000) {
        attempts++;
        x = minX + rand.nextDouble() * (maxX - minX);
        y = minY + rand.nextDouble() * (maxY - minY);

        // 1. KONTROL: Merkeze (Ortadaki daireye) olan mesafe kontrolü
        final distanceToCenter = sqrt(pow(x - cx, 2) + pow(y - cy, 2));
        if (distanceToCenter < (squareRadius + max(currentW, currentH) / 2 + 15)) {
          continue; // Dairenin içine kalıyorsa pas geç, tekrar dene
        }

        // 2. KONTROL: Evlerin üst üste binmeme (Overlap) kontrolü
        bool overlaps = false;
        for (int j = 0; j < i; j++) {
          final other = _players[j];
          final double otherW = other.isAlive ? 180.0 : 110.0;
          final double otherH = other.isAlive ? 150.0 : 90.0;

          final bool xOverlap = (x - currentW / 2 < other.posX! + otherW / 2 + 10) &&
              (x + currentW / 2 > other.posX! - otherW / 2 - 10);
          final bool yOverlap = (y - currentH / 2 < other.posY! + otherH / 2 + 10) &&
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
    final isMobile = size.width < 700; // Genişlik 700px altındaysa mobil HUD

    _calculatePlayerPositions(size);

    return Scaffold(
      backgroundColor: const Color(0xFF13132B),
      body: Stack(
        children: [
          // 1. ZOOM EDİLEBİLİR HARİTA
          GameMap(
            size: size,
            isNight: _phase == GamePhase.night,
            phase: _phase,
            players: _players,
            transformationController: _transformationController,
          ),

          // 2. EKRAN BOYUTUNA GÖRE ARAYÜZ (Mobil vs Masaüstü)
          if (isMobile)
            MobileHud(
              screenSize: size,
              roomCode: widget.roomCode,
              round: _round,
              phase: _phase,
              logs: _logs,
              players: _players,
              selectedVoteTargetId: _selectedVoteTargetId,
              onShowRoleCard: () => GameDialogs.showMyRoleCard(context, _players[0]),
              onShowDebugDialog: () => GameDialogs.showRoleDistributionDebug(context, _players),
              onSelectPlayer: (id) => setState(() => _selectedVoteTargetId = id),
              onStartDay: _startDay,
              onStartVoting: _startVoting,
              onSubmitVote: _submitVote,
            )
          else
            GameHud(
              screenSize: size,
              roomCode: widget.roomCode,
              round: _round,
              phase: _phase,
              logs: _logs,
              players: _players,
              selectedVoteTargetId: _selectedVoteTargetId,
              onShowRoleCard: () => GameDialogs.showMyRoleCard(context, _players[0]),
              onShowDebugDialog: () => GameDialogs.showRoleDistributionDebug(context, _players),
              onSelectPlayer: (id) => setState(() => _selectedVoteTargetId = id),
              onStartDay: _startDay,
              onStartVoting: _startVoting,
              onSubmitVote: _submitVote,
            ),
        ],
      ),
    );
  }
}