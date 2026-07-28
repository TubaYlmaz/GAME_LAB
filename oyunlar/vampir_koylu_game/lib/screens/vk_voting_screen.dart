import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/socket_service.dart';
import '../player_model.dart';
import 'lobby_screen.dart';
import 'entry_screen.dart';

class VKVotingScreen extends StatefulWidget {
  final String roomCode;
  final String myName;
  final List<PlayerModel> players;
  final bool amIVampire;

  const VKVotingScreen({
    super.key,
    required this.roomCode,
    required this.myName,
    required this.players,
    required this.amIVampire,
  });

  @override
  State<VKVotingScreen> createState() => _VKVotingScreenState();
}

class _VKVotingScreenState extends State<VKVotingScreen> {
  final SocketService _socketService = SocketService();
  String? selectedPlayer;
  double progress = 0.0;
  Timer? _timer;

  bool isVotingClosed = false;
  bool hasLockedVote = false;
  bool isDialogShown = false;
  int votedCount = 0;

  Map<String, int> playerVotes = {};

  @override
  void initState() {
    super.initState();

    for (var player in widget.players) {
      if (player.isAlive) {
        playerVotes[player.name] = 0;
      }
    }

    startTimer();
    setupSocketListeners();
  }

  void setupSocketListeners() {
    _socketService.socket?.off('vk_vote_status_updated');
    _socketService.socket?.off('vk_voting_results');
    _socketService.socket?.off('vk_round_ended');
    _socketService.socket?.off('vk_game_over');

    _socketService.socket?.on('vk_vote_status_updated', (data) {
      if (!mounted) return;

      setState(() {
        votedCount = data['votedCount'] ?? 0;

        if (data['currentVotes'] != null) {
          playerVotes.updateAll((key, value) => 0);

          Map<String, dynamic> rawVotes = Map<String, dynamic>.from(
            data['currentVotes'],
          );
          rawVotes.forEach((voter, votedFor) {
            if (votedFor != 'skip' && playerVotes.containsKey(votedFor)) {
              playerVotes[votedFor] = (playerVotes[votedFor] ?? 0) + 1;
            }
          });
        }
      });
    });

    void handleResults(dynamic data) {
      if (!mounted || isDialogShown) return;

      _timer?.cancel();
      setState(() {
        isVotingClosed = true;
        isDialogShown = true;
      });

      String? eliminated = data['eliminatedPlayer'];
      bool isTie = data['isTie'] ?? false;
      bool isVampire = data['isVampire'] ?? false;

      showRoundResultsDialog(eliminated, isTie, isVampire);
    }

    _socketService.socket?.on('vk_voting_results', handleResults);
    _socketService.socket?.on('vk_round_ended', handleResults);

    _socketService.socket?.on('vk_game_over', (data) {
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        isVotingClosed = true;
      });

      String winner = data['winner'] ?? 'KÖYLÜLER';
      String lastEliminated = data['eliminatedPlayer'] ?? 'Biri';

      showGameOverDialog(winner, lastEliminated);
    });
  }

  void startTimer() {
    const int totalDuration = 20;
    const int milliseconds = 100;
    final double increment = milliseconds / (totalDuration * 1000);

    final bool amIAlive = _isMyPlayerAlive();

    _timer = Timer.periodic(const Duration(milliseconds: milliseconds), (
      timer,
    ) {
      if (!mounted) return;
      setState(() {
        if (progress < 1.0) {
          progress += increment;
        } else {
          progress = 1.0;
          timer.cancel();
          if (!hasLockedVote && amIAlive) {
            submitVote(selectedPlayer ?? 'skip', lockIt: true);
          }
        }
      });
    });
  }

  bool _isMyPlayerAlive() {
    return widget.players
        .firstWhere(
          (p) => p.name.contains(widget.myName),
          orElse: () => widget.players.isNotEmpty
              ? widget.players[0]
              : PlayerModel(
                  id: 'me',
                  name: widget.myName,
                  avatarColor: Colors.blue,
                  gender: Gender.female,
                  role: 'Köylü',
                ),
        )
        .isAlive;
  }

  void submitVote(String targetPlayer, {required bool lockIt}) {
    if (!_isMyPlayerAlive()) return;

    HapticFeedback.selectionClick();

    setState(() {
      selectedPlayer = (targetPlayer == 'skip') ? null : targetPlayer;
      if (lockIt) {
        hasLockedVote = true;
      }
    });

    _socketService.socket?.emit('vk_submit_vote', {
      'roomCode': widget.roomCode,
      'voterName': widget.myName,
      'isLocking': lockIt,
      'votedTargetName': targetPlayer,
    });
  }

  void showRoundResultsDialog(
    String? eliminatedPlayer,
    bool isTie,
    bool isVampire,
  ) {
    String title = "";
    String subtitle = "";

    if (isTie || eliminatedPlayer == null) {
      title = "BERABERLİK! ⚖️";
      subtitle = "Oylamada eşitlik çıktı, bu tur kimse elenmedi!";
    } else {
      title = "OYLAMA BİTTİ! 🗳️";
      subtitle =
          "$eliminatedPlayer köy kararıyla elendi. Rolü: ${isVampire ? 'VAMPİR 🧛' : 'MASUM KÖYLÜ 🧑‍🌾'}";
    }

    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF151528),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTie
                      ? Icons.balance
                      : (isVampire ? Icons.bloodtype : Icons.person_off),
                  size: 70,
                  color: isTie
                      ? Colors.amber
                      : (isVampire ? Colors.redAccent : Colors.lightBlueAccent),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                const Text(
                  "3 saniye sonra otomatik haritaya dönülüyor...",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showGameOverDialog(String winner, String lastEliminated) {
    final bool isVillagerWin = winner == 'KÖYLÜLER';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0D0D2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isVillagerWin
                  ? const Color(0xFF2ECC71)
                  : const Color(0xFFE74C3C),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVillagerWin
                      ? Icons.wb_sunny_rounded
                      : Icons.nights_stay_rounded,
                  size: 80,
                  color: isVillagerWin
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFE74C3C),
                ),
                const SizedBox(height: 20),
                Text(
                  isVillagerWin
                      ? '🎉 KÖYLÜLER KAZANDI!'
                      : '🧛 VAMPİRLER KAZANDI!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isVillagerWin
                        ? const Color(0xFF2ECC71)
                        : const Color(0xFFE74C3C),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isVillagerWin
                      ? 'Köydeki tüm vampirler temizlendi, adalet yerini buldu! ☀️'
                      : 'Vampirler sayıca üstünlüğü ele geçirdi ve köyü karanlığa gömdü! 🌑',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2FF),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LobbyScreen(
                          roomCode: widget.roomCode,
                          playerName: widget.myName,
                          gender: Gender.female,
                          isHost: false,
                          vampireCount: 1,
                        ),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text(
                    'LOBİYE DÖN 🏠',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _socketService.socket?.off('vk_vote_status_updated');
    _socketService.socket?.off('vk_voting_results');
    _socketService.socket?.off('vk_round_ended');
    _socketService.socket?.off('vk_game_over');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alivePlayers = widget.players.where((p) => p.isAlive).toList();
    final bool amIAlive = _isMyPlayerAlive();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B1A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "KÖY OYLAMASI 🗳️",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2E5C),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: isVotingClosed ? Colors.grey : Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Text(
              "Onaylanan Kilitli Oylar: $votedCount / ${alivePlayers.length}",
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: alivePlayers.length,
              itemBuilder: (context, index) {
                final player = alivePlayers[index];
                final isSelected = selectedPlayer == player.name;
                final currentVotes = playerVotes[player.name] ?? 0;

                return GestureDetector(
                  onTap: (!amIAlive || hasLockedVote || isVotingClosed)
                      ? null
                      : () {
                          setState(() {
                            selectedPlayer = player.name;
                          });
                          submitVote(player.name, lockIt: false);
                        },
                  child: AnimatedScale(
                    scale: isSelected ? 1.03 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                              )
                            : const LinearGradient(
                                colors: [Color(0xFF1E1E38), Color(0xFF151528)],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        border: hasLockedVote && isSelected
                            ? Border.all(color: Colors.greenAccent, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasLockedVote && isSelected
                                ? Icons.lock_outline_rounded
                                : Icons.person_rounded,
                            color: isSelected ? Colors.white : Colors.white54,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            currentVotes > 0
                                ? "${player.name} ($currentVotes Oy)"
                                : player.name,
                            style: const TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (player.name.contains(widget.myName)) ...[
                            const Spacer(),
                            const Text(
                              "(SEN)",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: GestureDetector(
              onTap: (!amIAlive || hasLockedVote || isVotingClosed)
                  ? null
                  : () {
                      submitVote(selectedPlayer ?? 'skip', lockIt: true);
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: !amIAlive
                      ? const Color(0xFF2E2E5C).withOpacity(0.3)
                      : (hasLockedVote
                            ? const Color(0xFF2E2E5C).withOpacity(0.5)
                            : (selectedPlayer == null
                                  ? const Color(0xFF2E2E5C)
                                  : const Color(0xFF4CAF50))),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    !amIAlive
                        ? "ÖLDÜNÜZ (İZLEYİCİ MODU) 👻"
                        : (hasLockedVote
                              ? "OYUN KİLİTLENDİ 🔒"
                              : (selectedPlayer == null
                                    ? "PAS GEÇ VE KİLİTLE 🔒"
                                    : "OYU KİLİTLE 🔒")),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
