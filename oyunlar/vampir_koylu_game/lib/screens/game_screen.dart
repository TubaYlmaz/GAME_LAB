import 'dart:math';
import 'package:flutter/material.dart';

import 'entry_screen.dart';
import '../player_model.dart';

import '../widgets/game_map.dart';
import '../widgets/game_hud.dart';
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
  // Koşulsuz şartsız İlk Açılış GÜNDÜZ (Tur 1)
  GamePhase _phase = GamePhase.dayDiscussion;
  int _round = 1;
  String? _selectedVoteTargetId;
  bool _hasVotedInCurrentRound = false; // Oy kullanıldı mı kontrolü

  late List<String> _logs;
  late List<PlayerModel> _players;
  bool _positionsCalculated = false;

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _logs = [
      'System: Köy kuruldu (${widget.roomCode}).',
      'System: Herkes köye hoş geldi! Gece çökmeden önce tanışın.',
      'Oyuncu 2: Selamlar millet!',
      'Oyuncu 3: Herkese iyi şanslar 👋',
      'Oyuncu 4: Gece ilk kimi yesek acaba? 👀',
    ];

    _players = _generateAndDistributeRoles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      GameDialogs.showRoleDistributionDebug(context, _players);
      _centerCameraOnMap();
    });
  }

  void _centerCameraOnMap() {
    final screenSize = MediaQuery.of(context).size;
    final double xOffset = (GameMap.worldSize.width - screenSize.width) / 2;
    final double yOffset = (GameMap.worldSize.height - screenSize.height) / 2;

    _transformationController.value = Matrix4.identity()
      ..translate(-xOffset, -yOffset);
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

  void _calculatePlayerPositions() {
    if (_positionsCalculated) return;

    final double worldW = GameMap.worldSize.width;
    final double worldH = GameMap.worldSize.height;

    final cx = worldW / 2;
    final cy = worldH / 2 + 28;

    const double squareRadius = 180.0;

    final double minX = worldW * 0.08;
    final double maxX = worldW * 0.92;
    final double minY = worldH * 0.10;
    final double maxY = worldH * 0.88;

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

        final distanceToCenter = sqrt(pow(x - cx, 2) + pow(y - cy, 2));
        if (distanceToCenter < (squareRadius + max(currentW, currentH) / 2 + 20)) {
          continue;
        }

        bool overlaps = false;
        for (int j = 0; j < i; j++) {
          final other = _players[j];
          final double otherW = other.isAlive ? 180.0 : 110.0;
          final double otherH = other.isAlive ? 150.0 : 90.0;

          final bool xOverlap = (x - currentW / 2 < other.posX! + otherW / 2 + 15) &&
              (x + currentW / 2 > other.posX! - otherW / 2 - 15);
          final bool yOverlap = (y - currentH / 2 < other.posY! + otherH / 2 + 15) &&
              (y + currentH / 2 > other.posY! - otherH / 2 - 15);

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

  // --- FAZ VE DÖNGÜ YÖNETİMİ ---

  // 1. Geceyi Başlat (Manuel Buton Basışı ile)
  void _startNight() {
    setState(() {
      _phase = GamePhase.night;
      _hasVotedInCurrentRound = false; // Yeni faz için sıfırla
      _logs.add('System: Tur $_round - Gece çöktü... Herkes evlerine çekildi. 🌙');
    });
  }

  // 2. Gündüzü Başlat (Tur Sayısını Artırır)
  void _startDay() {
    setState(() {
      _round++; // Yeni tur başlar
      _phase = GamePhase.dayDiscussion;
      _logs.add('System: Tur $_round - Gün doğdu! Köylüler meydanda toplandı. ☀️');
    });
  }

  // 3. Oylama Moduna Geç
  void _startVoting() {
    setState(() {
      _phase = GamePhase.voting;
      _logs.add('System: Tur $_round - Oylama başladı. Oy vermek istediğiniz kişiyi seçin... 🗳️');
    });
  }

  // 4. Oy Kullanılınca Çalışır (GECEYE ATMAZ, SADECE ELEME YAPAR)
  void _submitVote() {
    if (_selectedVoteTargetId == null) return;
    final target = _players.firstWhere((p) => p.id == _selectedVoteTargetId);

    setState(() {
      target.isAlive = false;
      _logs.add('System: ${target.name} elendi! Rolü: [${target.role}]');
      _selectedVoteTargetId = null;
      _hasVotedInCurrentRound = true; // Oy verildi! Buton 'GECEYE GEÇ' olacak.
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    _calculatePlayerPositions();

    return Scaffold(
      backgroundColor: const Color(0xFF13132B),
      body: Stack(
        children: [
          // 1. HARİTA
          GameMap(
            screenSize: size,
            isNight: _phase == GamePhase.night,
            phase: _phase,
            players: _players,
            transformationController: _transformationController,
          ),

          // 2. TEK ALT BİRLEŞİK ARAYÜZ (GameHud)
          GameHud(
            screenSize: size,
            round: _round,
            phase: _phase,
            logs: _logs,
            players: _players,
            selectedVoteTargetId: _selectedVoteTargetId,
            myPlayer: _players[0],
            hasVotedInCurrentRound: _hasVotedInCurrentRound, // Yeni Eklendi
            onShowRoleCard: () => GameDialogs.showMyRoleCard(context, _players[0]),
            onShowDebugDialog: () => GameDialogs.showRoleDistributionDebug(context, _players),
            onSelectPlayer: (id) => setState(() => _selectedVoteTargetId = id),
            onStartNight: _startNight,
            onStartDay: _startDay,
            onStartVoting: _startVoting,
            onSubmitVote: _submitVote,
          ),
        ],
      ),
    );
  }
}