import 'dart:math';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';
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
  GamePhase _phase = GamePhase.dayDiscussion;
  int _round = 1;
  String? _selectedVoteTargetId;
  bool _hasVotedInCurrentRound = false;

  late List<String> _logs;
  List<PlayerModel> _players = [];
  bool _positionsCalculated = false;

  io.Socket? _socket;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _logs = [
      'System: Köy kuruldu (${widget.roomCode}).',
      'System: Herkes köye hoş geldi! Gece çökmeden önce tanışın.',
    ];

    _initSocket();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCameraOnMap();
    });
  }

  void _initSocket() {
    _socket = io.io(
      AppConfig.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket?.connect();

    // 🎯 SUNUCUDAN GELEN CANLI OYUNCU LİSTESİYLE SADECE KATILAN GERÇEK KİŞİLERİ ÇİZER
    void updatePlayersFromData(dynamic data) {
      if (!mounted) return;
      final List serverPlayers = (data is Map ? data['players'] : data) ?? [];

      if (serverPlayers.isNotEmpty) {
        setState(() {
          _players = _parseServerPlayers(serverPlayers);
          _positionsCalculated = false;
        });
      }
    }

    _socket?.on('vk_game_started', updatePlayersFromData);
    _socket?.on('vk_players_updated', updatePlayersFromData);

    _socket?.on('vk_round_ended', (data) {
      if (!mounted) return;
      final String eliminated = data['eliminatedPlayer'] ?? '';
      final bool isVampire = data['isVampire'] ?? false;

      setState(() {
        for (var p in _players) {
          if (p.name == eliminated || p.name.contains(eliminated)) {
            p.isAlive = false;
          }
        }
        _logs.add('🗳️ Oylama Bitti! $eliminated ${isVampire ? 'bir VAMPİRDİ! 🧛' : 'masum bir KÖYLÜYDÜ... 🧑‍🌾'}');
      });
    });

    _socket?.on('vk_game_over', (data) {
      if (!mounted) return;
      final String winner = data['winner'] ?? 'KÖYLÜLER';
      final String lastEliminated = data['eliminatedPlayer'] ?? 'Biri';

      _showGameOverDialog(winner, lastEliminated);
    });

    _socket?.on('vk_phase_changed', (data) {
      if (!mounted) return;
      final String nextPhase = data['phase'];
      setState(() {
        if (nextPhase == 'night') {
          _phase = GamePhase.night;
          _hasVotedInCurrentRound = false;
          _logs.add('System: Tur $_round - Gece çöktü... 🌙');
        } else if (nextPhase == 'day') {
          _round++;
          _phase = GamePhase.dayDiscussion;
          _logs.add('System: Tur $_round - Gün doğdu! ☀️');
        } else if (nextPhase == 'voting') {
          _phase = GamePhase.voting;
          _logs.add('System: Tur $_round - Oylama başladı. 🗳️');
        }
      });
    });

    _socket?.emit('vk_join_room', {
      'roomCode': widget.roomCode,
      'playerName': widget.playerName,
      'gender': widget.gender.name,
    });
  }

  List<PlayerModel> _parseServerPlayers(List serverPlayers) {
    final colors = [
      const Color(0xFF00D2FF), const Color(0xFFE74C3C), const Color(0xFF9B59B6),
      const Color(0xFF3498DB), const Color(0xFF2ECC71), const Color(0xFFF39C12),
      const Color(0xFF1ABC9C), const Color(0xFFEC407A), const Color(0xFFE67E22),
    ];

    List<PlayerModel> list = [];
    for (int i = 0; i < serverPlayers.length; i++) {
      final p = serverPlayers[i];
      final String name = p['name'] ?? 'Oyuncu ${i + 1}';
      final bool isVampire = p['isVampire'] ?? false;
      final String roleStr = p['role'] ?? (isVampire ? 'Vampir 🧛' : 'Köylü 🧑‍🌾');
      final Gender gender = p['gender'] == 'female' ? Gender.female : Gender.male;

      list.add(
        PlayerModel(
          id: 'p_$i',
          name: name,
          avatarColor: colors[i % colors.length],
          gender: gender,
          role: roleStr,
          isVampire: isVampire,
          isAlive: p['isAlive'] ?? true,
        ),
      );
    }
    return list;
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
    _socket?.disconnect();
    _transformationController.dispose();
    super.dispose();
  }

  void _calculatePlayerPositions() {
    if (_positionsCalculated || _players.isEmpty) return;

    final double worldW = GameMap.worldSize.width;
    final double worldH = GameMap.worldSize.height;

    final cx = worldW / 2;
    final cy = worldH / 2 + 28;

    const double squareRadius = 180.0;

    final double minX = worldW * 0.08;
    final double maxX = worldW * 0.92;
    final double minY = worldH * 0.10;
    final double maxY = worldH * 0.88;

    final rand = Random(1337);

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
          if (other.posX == null || other.posY == null) continue;

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

  void _startNight() {
    _socket?.emit('vk_change_phase', {'roomCode': widget.roomCode, 'nextPhase': 'night'});
    setState(() {
      _phase = GamePhase.night;
      _hasVotedInCurrentRound = false;
    });
  }

  void _startDay() {
    _socket?.emit('vk_change_phase', {'roomCode': widget.roomCode, 'nextPhase': 'day'});
    setState(() {
      _round++;
      _phase = GamePhase.dayDiscussion;
    });
  }

  void _startVoting() {
    _socket?.emit('vk_change_phase', {'roomCode': widget.roomCode, 'nextPhase': 'voting'});
    setState(() {
      _phase = GamePhase.voting;
    });
  }

  void _submitVote() {
    if (_selectedVoteTargetId == null) return;
    final target = _players.firstWhere((p) => p.id == _selectedVoteTargetId);

    _socket?.emit('vk_submit_vote', {
      'roomCode': widget.roomCode,
      'votedPlayerName': target.name,
    });

    setState(() {
      target.isAlive = false;
      _logs.add('System: ${target.name} elendi!');
      _selectedVoteTargetId = null;
      _hasVotedInCurrentRound = true;
    });
  }

  void _showGameOverDialog(String winner, String lastEliminated) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final bool isVillagerWin = winner == 'KÖYLÜLER';

        return AlertDialog(
          backgroundColor: const Color(0xFF0D0D2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isVillagerWin ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
              width: 2,
            ),
          ),
          title: Text(
            isVillagerWin ? '🎉 KÖYLÜLER KAZANDI!' : '🧛 VAMPİRLER KAZANDI!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isVillagerWin ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$lastEliminated elendi ve kader tayin edildi!', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              Text(
                isVillagerWin
                    ? 'Köydeki tüm vampirler temizlendi, adalet yerini buldu! ☀️'
                    : 'Vampirler köyün kontrolünü tamamen ele geçirdi! 🌑',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D2FF)),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('LOBİYE DÖN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    _calculatePlayerPositions();

    final PlayerModel myPlayer = _players.firstWhere(
      (p) => p.name.contains(widget.playerName),
      orElse: () => _players.isNotEmpty ? _players[0] : PlayerModel(
        id: 'fallback',
        name: widget.playerName,
        avatarColor: Colors.cyan,
        gender: widget.gender,
        role: 'Köylü',
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF13132B),
      body: Stack(
        children: [
          if (_players.isNotEmpty)
            GameMap(
              screenSize: size,
              isNight: _phase == GamePhase.night,
              phase: _phase,
              players: _players,
              transformationController: _transformationController,
            ),

          if (_players.isNotEmpty)
            GameHud(
              screenSize: size,
              round: _round,
              phase: _phase,
              logs: _logs,
              players: _players,
              selectedVoteTargetId: _selectedVoteTargetId,
              myPlayer: myPlayer,
              hasVotedInCurrentRound: _hasVotedInCurrentRound,
              onShowRoleCard: () => GameDialogs.showMyRoleCard(context, myPlayer),
              onShowDebugDialog: () => GameDialogs.showRoleDistributionDebug(context, _players),
              onSelectPlayer: (id) => setState(() => _selectedVoteTargetId = id),
              onStartNight: _startNight,
              onStartDay: _startDay,
              onStartVoting: _startVoting,
              onSubmitVote: _submitVote,
            ),

          if (_players.isEmpty)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00D2FF)),
                  SizedBox(height: 16),
                  Text('Köy yükleniyor...', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}