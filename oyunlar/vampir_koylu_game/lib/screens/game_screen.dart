import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import 'entry_screen.dart';
import '../player_model.dart';
import '../widgets/game_map.dart';
import '../widgets/game_hud.dart';
import '../widgets/game_dialogs.dart';
import '../widgets/night_action_dialog.dart';
import 'vk_voting_screen.dart';
import 'lobby_screen.dart';

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
  bool _isAfterNight = false;
  int _round = 1;
  String? _selectedVoteTargetId;
  bool _hasVotedInCurrentRound = false;
  bool _hasActedAtNight = false;
  late bool _isHost;

  bool _isNightDialogShowing = false;
  bool _isGameOverDialogShowing = false; // Çift açılmayı önlemek için

  late List<String> _logs;
  List<PlayerModel> _players = [];
  bool _positionsCalculated = false;

  final SocketService _socketService = SocketService();
  final TransformationController _transformationController =
      TransformationController();
  final StreamController<Map<String, List<String>>> _vampireChoicesController =
      StreamController<Map<String, List<String>>>.broadcast();

  @override
  void initState() {
    super.initState();
    _isHost = widget.isHost;
    _logs = [
      'System: Köy kuruldu (${widget.roomCode}).',
      'System: Oyun başladı, gündüz tartışması aktif.',
    ];

    _initSocket();

    _phase = GamePhase.dayDiscussion;
    _isAfterNight = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCameraOnMap();
    });
  }

  void _showRoleCardModal() {
    final myPlayer = _getMyPlayer();

    List<String> teamMates = [];
    if (myPlayer.isVampire) {
      teamMates = _players
          .where(
            (p) => p.isVampire && p.name.trim() != widget.playerName.trim(),
          )
          .map((p) => p.name)
          .toList();
    }

    GameDialogs.showMyRoleCard(
      context,
      myPlayer,
      roomCode: widget.roomCode,
      socketService: _socketService,
      teamMates: teamMates,
    );
  }

  void _closeNightDialogIfOpen() {
    if (_isNightDialogShowing && mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _isNightDialogShowing = false;
    }
  }

  void _initSocket() {
    _socketService.currentRoomCode = widget.roomCode;
    _socketService.connect();

    // Dinleyicileri temizleme
    _socketService.socket?.off('vk_players_updated');
    _socketService.socket?.off('vk_game_started');
    _socketService.socket?.off('vk_vote_progress');
    _socketService.socket?.off('vk_round_ended');
    _socketService.socket?.off('vk_voting_results');
    _socketService.socket?.off('vk_game_over');
    _socketService.socket?.off('vk_phase_changed');
    _socketService.socket?.off('vk_navigate_to_voting');
    _socketService.socket?.off('night_results');
    _socketService.socket?.off('night_action_error');
    _socketService.socket?.off('vk_show_role_card');
    _socketService.socket?.off('vk_host_changed');
    _socketService.socket?.off('vk_host_status');
    _socketService.socket?.off('vk_phase_error');
    _socketService.socket?.off('vk_night_action_choices');

    void updatePlayersFromData(dynamic data) {
      if (!mounted) return;
      final List serverPlayers = (data is Map ? data['players'] : data) ?? [];

      if (serverPlayers.isNotEmpty) {
        setState(() {
          _players = _parseServerPlayers(serverPlayers);
          final myPlayerData = serverPlayers.cast<dynamic>().firstWhere(
            (player) =>
                player is Map &&
                player['name']?.toString().trim().toLowerCase() ==
                    widget.playerName.trim().toLowerCase(),
            orElse: () => null,
          );
          if (myPlayerData is Map && myPlayerData['isHost'] != null) {
            _isHost = myPlayerData['isHost'] == true;
          }
          _positionsCalculated = false;
        });
      }
    }

    _socketService.socket?.on('vk_players_updated', updatePlayersFromData);
    _socketService.socket?.on('vk_game_started', updatePlayersFromData);

    _socketService.socket?.on('vk_host_changed', (data) {
      if (!mounted || data is! Map || data['newHost'] == null) return;

      final newHost = data['newHost'].toString().trim().toLowerCase();
      final amINewHost = newHost == widget.playerName.trim().toLowerCase();
      setState(() {
        _isHost = amINewHost;
        _logs.add(
          amINewHost
              ? 'System: Muhtar oldun. Faz yönetimi artık sende.'
              : 'System: Yeni muhtar: ${data['newHost']}.',
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            amINewHost
                ? '🏛️ Muhtar oldun! Gece/gündüz geçişlerini sen yönetebilirsin.'
                : (data['message'] ?? 'Yeni muhtar seçildi.').toString(),
          ),
          backgroundColor: amINewHost ? Colors.teal : Colors.indigo,
        ),
      );

      // Ask the server for an authoritative answer as well.  This avoids a
      // stale local name comparison leaving the newly assigned host locked.
      _socketService.socket?.emit('vk_get_host_status', {
        'roomCode': widget.roomCode,
      });
    });

    _socketService.socket?.on('vk_host_status', (data) {
      if (!mounted || data is! Map) return;
      final bool amIHost = data['isHost'] == true;
      if (_isHost == amIHost) return;
      setState(() {
        _isHost = amIHost;
        if (amIHost) {
          _logs.add('System: Sunucu host yetkini doğruladı.');
        }
      });
    });

    _socketService.socket?.on('vk_phase_error', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (data is Map ? data['message'] : null) ??
                'Bu geçişi yalnızca muhtar yapabilir.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    });

    _socketService.socket?.on('vk_vote_progress', (data) {
      if (!mounted) return;
      final int voted = (data is Map && data['votedCount'] != null)
          ? data['votedCount']
          : 0;
      final int total = (data is Map && data['totalAlive'] != null)
          ? data['totalAlive']
          : 0;
      setState(() {
        _logs.add(
          'System: Oylama devam ediyor... ($voted / $total oy kullanıldı)',
        );
      });
    });

    void handleRoundEnded(dynamic data) {
      if (!mounted) return;
      _closeNightDialogIfOpen();

      final String? eliminated =
          (data is Map && data['eliminatedPlayer'] != null)
          ? data['eliminatedPlayer'].toString()
          : null;
      final bool isTie = (data is Map && data['isTie'] == true);
      final bool isVampire = (data is Map && data['isVampire'] == true);
      final List serverPlayers = (data is Map && data['players'] is List)
          ? data['players']
          : [];

      setState(() {
        if (serverPlayers.isNotEmpty) {
          _players = _parseServerPlayers(serverPlayers);
        } else if (eliminated != null && !isTie) {
          _players = _players.map((p) {
            final String cleanPName = p.name.trim().toLowerCase();
            final String cleanEliminated = eliminated.trim().toLowerCase();

            if (cleanPName == cleanEliminated ||
                cleanPName.contains(cleanEliminated) ||
                cleanEliminated.contains(cleanPName)) {
              return PlayerModel(
                id: p.id,
                name: p.name,
                avatarColor: p.avatarColor,
                gender: p.gender,
                role: p.role,
                isVampire: p.isVampire,
                isAlive: false,
              );
            }
            return p;
          }).toList();
        }

        _phase = GamePhase.dayDiscussion;
        _isAfterNight = false;
        _hasVotedInCurrentRound = false;
        _selectedVoteTargetId = null;
        _positionsCalculated = false;

        if (isTie || eliminated == null) {
          _logs.add(
            '⚖️ Oylama sonucu: Eşitlik çıktı, kimse elenmedi. Geceye hazırlanılıyor... 🌙',
          );
        } else {
          _logs.add(
            '🗳️ Oylama sonucu: $eliminated elendi! (Rolü: ${isVampire ? 'Vampir 🧛' : 'Köylü 🧑‍🌾'}) - Geceye hazırlanılıyor... 🌙',
          );
        }
      });
    }

    _socketService.socket?.on('vk_round_ended', handleRoundEnded);
    _socketService.socket?.on('vk_voting_results', handleRoundEnded);

    // 🏆 OYUN BİTTİ DİNLENİCİSİ (EntryScreen hatasını tamamen engelleyen güvenli yapı)
    // 🏆 OYUN BİTTİ DİNLENİCİSİ
    _socketService.socket?.on('vk_game_over', (data) {
      print("🔥🔥🔥 VK_GAME_OVER SOKETTEN ALINDI!");
      if (!mounted || _isGameOverDialogShowing) return;

      _isGameOverDialogShowing = true;
      _isNightDialogShowing = false;

      // DİKKAT: Burada Navigator.pop() kullanarak ekranı ya da routelu
      // geriye sarmaya ÇALIŞMIYORUZ. Bu sayede EntryScreen'e fırlamasını engelliyoruz.

      final String winner = (data is Map && data['winner'] != null)
          ? data['winner'].toString()
          : 'KÖYLÜLER';
      final String lastEliminated =
          (data is Map && data['eliminatedPlayer'] != null)
          ? data['eliminatedPlayer'].toString()
          : 'Biri';

      final List serverPlayers = (data is Map && data['players'] is List)
          ? data['players']
          : const [];
      if (serverPlayers.isNotEmpty) {
        setState(() {
          _players = _parseServerPlayers(serverPlayers);
          _positionsCalculated = false;
        });
      }

      // Doğrudan mevcut GameScreen haritası üzerinde dialogu açıyoruz
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showGameOverDialog(winner, lastEliminated);
        }
      });
    });

    // 🔄 FAZ DEĞİŞİM DİNLENİCİSİ
    _socketService.socket?.on('vk_phase_changed', (data) {
      if (!mounted) return;
      final String? nextPhase = (data is Map && data['phase'] != null)
          ? data['phase'].toString()
          : null;

      if (nextPhase == null) return;

      if (nextPhase != 'night') {
        _closeNightDialogIfOpen();
      }

      setState(() {
        if (nextPhase == 'night') {
          _phase = GamePhase.night;
          _hasVotedInCurrentRound = false;
          _hasActedAtNight = false;
          _logs.add('System: Tur $_round - Gece çöktü... 🌙');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _checkAndShowNightDialog();
            }
          });
        } else if (nextPhase == 'day') {
          _round++;
          _phase = GamePhase.dayDiscussion;
          _isAfterNight = true;
          _logs.add('System: Tur $_round - Gün doğdu! ☀️');
        } else if (nextPhase == 'voting') {
          _phase = GamePhase.voting;
          _logs.add(
            'System: Tur $_round - Oylama başladı. Oyunuzu kullanın! 🗳️',
          );
        }
      });
    });

    _socketService.socket?.on('night_results', (data) {
      if (!mounted) return;
      _closeNightDialogIfOpen();

      final List deadPlayers = (data is Map && data['deadPlayers'] is List)
          ? data['deadPlayers']
          : [];
      final String msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Gece sona erdi.';

      setState(() {
        _logs.add('System: $msg');
        for (var p in _players) {
          if (deadPlayers
              .map((e) => e.toString().trim())
              .contains(p.name.trim())) {
            p.isAlive = false;
          }
        }
        _positionsCalculated = false;
      });
    });

    _socketService.socket?.on('night_action_error', (data) {
      if (!mounted) return;
      final String message = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Anlaşmazlık çıktı!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 4),
        ),
      );

      final String roleTarget =
          (data is Map && data['roleTarget'] != null)
              ? data['roleTarget'].toString().toLowerCase()
              : '';
      final String myRole = _getMyPlayer().role.toLowerCase();
      final bool mustChooseAgain =
          (roleTarget.contains('vampir') && myRole.contains('vampir')) ||
          (roleTarget.contains('seri') &&
              (myRole.contains('seri') || myRole.contains('katil')));

      if (mustChooseAgain) {
        _closeNightDialogIfOpen();
      }
      setState(() {
        _hasActedAtNight = false;
      });
      if (mustChooseAgain) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkAndShowNightDialog();
        });
      }
    });

    _socketService.socket?.on('vk_night_action_choices', (data) {
      if (data is! Map || data['vampireSelections'] is! Map) return;

      final selections = <String, List<String>>{};
      (data['vampireSelections'] as Map).forEach((target, voters) {
        selections[target.toString()] = voters is List
            ? voters.map((voter) => voter.toString()).toList()
            : <String>[];
      });
      if (!_vampireChoicesController.isClosed) {
        _vampireChoicesController.add(selections);
      }
    });

    _socketService.socket?.on('vk_navigate_to_voting', (_) {
      if (!mounted) return;
      _closeNightDialogIfOpen();

      setState(() {
        _phase = GamePhase.voting;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VKVotingScreen(
            roomCode: widget.roomCode,
            myName: widget.playerName,
            players: _players,
            amIVampire: _getMyPlayer().isVampire,
            isHost: _isHost,
          ),
        ),
      );
    });

    _socketService.socket?.emit('vk_get_players', {
      'roomCode': widget.roomCode,
    });
    _socketService.socket?.emit('vk_get_host_status', {
      'roomCode': widget.roomCode,
    });
  }

  PlayerModel _getMyPlayer() {
    return _players.firstWhere(
      (p) => p.name.trim() == widget.playerName.trim(),
      orElse: () => _players.isNotEmpty
          ? _players[0]
          : PlayerModel(
              id: 'me',
              name: widget.playerName,
              avatarColor: Colors.blue,
              gender: widget.gender,
              role: 'Köylü 🧑‍🌾',
            ),
    );
  }

  void _checkAndShowNightDialog() {
    final myPlayer = _getMyPlayer();
    if (myPlayer.isAlive &&
        !_hasActedAtNight &&
        _phase == GamePhase.night &&
        !_isNightDialogShowing) {
      _showNightActionModal(myPlayer);
    }
  }

  void _showNightActionModal(PlayerModel myPlayer) {
    if (_isNightDialogShowing) return;
    _isNightDialogShowing = true;

    final aliveTargets = _players
        .where((p) => p.isAlive)
        .map((p) => {'id': p.name, 'name': p.name})
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return NightActionDialog(
          myRole: myPlayer.role,
          alivePlayers: aliveTargets,
          vampireVotesStream: _vampireChoicesController.stream,
          onActionSubmitted: (target) {
            setState(() {
              _hasActedAtNight = true;
            });

            _socketService.socket?.emit('submit_night_action', {
              'roomCode': widget.roomCode,
              'playerName': widget.playerName,
              'role': myPlayer.role,
              'target': target,
            });
          },
        );
      },
    ).then((_) {
      _isNightDialogShowing = false;
    });
  }

  List<PlayerModel> _parseServerPlayers(List serverPlayers) {
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
    ];

    List<PlayerModel> list = [];
    for (int i = 0; i < serverPlayers.length; i++) {
      final p = serverPlayers[i];
      if (p == null) continue;

      final String name = (p is Map && p['name'] != null)
          ? p['name'].toString()
          : (p is Map && p['playerName'] != null)
          ? p['playerName'].toString()
          : 'Oyuncu ${i + 1}';

      final String rawRole = (p is Map && p['role'] != null)
          ? p['role'].toString()
          : (p is Map && p['roleName'] != null)
          ? p['roleName'].toString()
          : '';

      final bool isVampire =
          (p is Map && p['isVampire'] == true) ||
          rawRole.toLowerCase().contains('vampir');

      String roleStr = rawRole;
      if (roleStr.isEmpty) {
        roleStr = isVampire ? 'Vampir 🧛' : 'Köylü 🧑‍🌾';
      }

      final Gender gender = (p is Map && p['gender']?.toString() == 'female')
          ? Gender.female
          : Gender.male;

      Color avatarColor = colors[i % colors.length];
      if (p is Map && p['avatarColor'] != null) {
        try {
          final String rawColor = p['avatarColor'].toString();
          if (rawColor.startsWith('0x') || rawColor.startsWith('#')) {
            avatarColor = Color(int.parse(rawColor.replaceAll('#', '0x')));
          } else if (int.tryParse(rawColor) != null) {
            avatarColor = Color(int.parse(rawColor));
          }
        } catch (_) {
          avatarColor = colors[i % colors.length];
        }
      }

      final String id = (p is Map && p['id'] != null)
          ? p['id'].toString()
          : (p is Map && p['socketId'] != null)
          ? p['socketId'].toString()
          : 'p_$i';

      final bool isAlive = (p is Map && p['isAlive'] != null)
          ? (p['isAlive'] == true)
          : true;

      list.add(
        PlayerModel(
          id: id,
          name: name,
          avatarColor: avatarColor,
          gender: gender,
          role: roleStr,
          isVampire: isVampire,
          isAlive: isAlive,
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
    _socketService.clearAllListeners();
    _vampireChoicesController.close();
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
        if (distanceToCenter <
            (squareRadius + max(currentW, currentH) / 2 + 20)) {
          continue;
        }

        bool overlaps = false;
        for (int j = 0; j < i; j++) {
          final other = _players[j];
          if (other.posX == null || other.posY == null) continue;

          final double otherW = other.isAlive ? 180.0 : 110.0;
          final double otherH = other.isAlive ? 150.0 : 90.0;

          final bool xOverlap =
              (x - currentW / 2 < other.posX! + otherW / 2 + 15) &&
              (x + currentW / 2 > other.posX! - otherW / 2 - 15);
          final bool yOverlap =
              (y - currentH / 2 < other.posY! + otherH / 2 + 15) &&
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
    _socketService.socket?.emit('vk_change_phase', {
      'roomCode': widget.roomCode,
      'nextPhase': 'night',
    });
  }

  void _startDay() {
    _socketService.socket?.emit('vk_change_phase', {
      'roomCode': widget.roomCode,
      'nextPhase': 'day',
    });
  }

  void _startVoting() {
    _socketService.socket?.emit('vk_change_phase', {
      'roomCode': widget.roomCode,
      'nextPhase': 'voting',
    });
  }

  void _submitVote() {
    if (_selectedVoteTargetId == null || _hasVotedInCurrentRound) return;
    final target = _players.firstWhere((p) => p.id == _selectedVoteTargetId);

    final myPlayerName = _getMyPlayer().name;

    _socketService.socket?.emit('vk_submit_vote', {
      'roomCode': widget.roomCode,
      'voterName': myPlayerName,
      'votedTargetName': target.name,
      'isLocking': true,
    });

    setState(() {
      _hasVotedInCurrentRound = true;
      _logs.add(
        'System: Oyunuzu ${target.name} kişisine verdiniz. Diğerlerinin oyları bekleniyor...',
      );
      _selectedVoteTargetId = null;
    });
  }

  void _showGameOverDialog(String winner, String lastEliminated) {
    final bool isVillagerWin = winner.toUpperCase().contains('KÖYL');
    final PlayerModel myPlayer = _getMyPlayer();
    final String myRole = myPlayer.role.toLowerCase();
    final bool amIEvil =
        myPlayer.isVampire ||
        myRole.contains('vampir') ||
        myRole.contains('seri') ||
        myRole.contains('katil');
    final bool didIWin = isVillagerWin ? !amIEvil : amIEvil;

    showDialog(
      context: context,
      barrierDismissible: false,
      // 🌟 BU SATIR ÇOK ÖNEMLİ: Arkadaki ekranın kararmasını (barrierColor)
      // yarı şeffaf yaparak arkadaki haritanın görünmesini sağlıyoruz.
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        return AlertDialog(
          // 🌟 Arka plan rengini hafif şeffaf yaparak haritanın bütünlüğünü bozmuyoruz
          backgroundColor: const Color(0xFF0D0D2A).withOpacity(0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isVillagerWin
                  ? const Color(0xFF2ECC71)
                  : const Color(0xFFE74C3C),
              width: 2,
            ),
          ),
          title: Text(
            didIWin ? '🎉 KAZANDIN!' : '💀 KAYBETTİN!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isVillagerWin
                  ? const Color(0xFF2ECC71)
                  : const Color(0xFFE74C3C),
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isVillagerWin
                    ? 'Köylüler kazandı. ${didIWin ? 'Ekibin zafere ulaştı!' : 'Ekibin elendi.'}'
                    : 'Vampirler kazandı. ${didIWin ? 'Ekibin köyü ele geçirdi!' : 'Köy karanlığa yenildi.'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                'Son elenen: $lastEliminated',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D2FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // 1. Sadece açılan bu oyun bitti kartını kapatıyoruz (arkadaki GameScreen kalıyor)
                  Navigator.of(ctx).pop();

                  // 2. Voting ekranı açıksa da eski oyun ekranlarına dönmeden
                  // doğrudan temiz bir lobiye geçiyoruz.
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => LobbyScreen(
                        roomCode: widget.roomCode,
                        playerName: widget.playerName,
                        gender: widget.gender,
                        isHost: _isHost,
                        vampireCount: widget.vampireCount,
                        doctorCount: widget.doctorCount,
                        serialKillerCount: widget.serialKillerCount,
                        villagerCount: widget.villagerCount,
                      ),
                    ),
                    (route) => route.isFirst,
                  );
                },
                child: const Text(
                  'LOBİYE DÖN',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
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

    final PlayerModel myPlayer = _getMyPlayer();

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
              isAfterNight: _isAfterNight,
              logs: _logs,
              players: _players,
              selectedVoteTargetId: _selectedVoteTargetId,
              myPlayer: myPlayer,
              hasVotedInCurrentRound: _hasVotedInCurrentRound,
              isHost: _isHost,
              onShowRoleCard: () => _showRoleCardModal(),
              onShowDebugDialog: () =>
                  GameDialogs.showRoleDistributionDebug(context, _players),
              onSelectPlayer: (id) =>
                  setState(() => _selectedVoteTargetId = id),
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
                  Text(
                    'Köy yükleniyor...',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
