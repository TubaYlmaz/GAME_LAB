// lib/screens/voting_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'host_screen.dart'; // 🎯 EKLEME: Oylama bitince lobiye/odaya geri dönebilmek için import edildi.

class VotingScreen extends StatefulWidget {
  final dynamic socket;
  final String roomCode;
  final String myName;
  final List<String> players;
  final bool amIImpostor;

  const VotingScreen({
    super.key,
    required this.socket,
    required this.roomCode,
    required this.myName,
    required this.players,
    required this.amIImpostor,
  });

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  String? selectedPlayer;
  double progress = 0.0;
  Timer? _timer;

  bool isVotingClosed = false;
  bool hasLockedVote = false;
  int votedCount = 0;

  Map<String, int> playerVotes = {};

  @override
  void initState() {
    super.initState();

    for (var player in widget.players) {
      playerVotes[player] = 0;
    }

    startTimer();
    setupSocketListeners();
  }

  void setupSocketListeners() {
    widget.socket.on('vote_status_updated', (data) {
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

    widget.socket.on('voting_results', (data) {
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        isVotingClosed = true;
      });

      String eliminatedPlayer =
          data['eliminatedPlayer'] ?? "Kimse elenmedi (Beraberlik)";
      bool isTie = data['isTie'] ?? false;
      String impostorName = data['impostorName'] ?? "";

      showResultsDialog(eliminatedPlayer, isTie, impostorName);
    });
  }

  void startTimer() {
    const int totalDuration = 20;
    const int milliseconds = 100;
    final double increment = milliseconds / (totalDuration * 1000);

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
          if (!hasLockedVote) {
            submitVote(selectedPlayer ?? 'skip', lockIt: true);
          }
        }
      });
    });
  }

  void submitVote(String targetPlayer, {required bool lockIt}) {
    HapticFeedback.selectionClick();

    setState(() {
      selectedPlayer = (targetPlayer == 'skip') ? null : targetPlayer;
      if (lockIt) {
        hasLockedVote = true;
      }
    });

    widget.socket.emit('submit_vote', {
      'roomCode': widget.roomCode,
      'voterName': widget.myName,
      'votedFor': targetPlayer,
      'isLocking': lockIt,
    });
  }

  void showResultsDialog(
    String eliminatedPlayer,
    bool isTie,
    String impostorName,
  ) {
    String title = "";
    String subtitle = "";
    bool isVictory = false;

    if (isTie) {
      title = "BERABERLİK! ⚖️";
      subtitle =
          "Oylamada eşitlik çıktı, kimse elenmedi! Gerçek İmpostor '$impostorName' aranızda sızmaya devam ediyor.";
      isVictory = widget.amIImpostor;
    } else if (eliminatedPlayer == impostorName) {
      if (widget.amIImpostor) {
        title = "YAKALANDIN! 💀";
        subtitle =
            "Diğer oyuncular senin İmpostor olduğunu doğru bildi. Maçı kaybettin!";
        isVictory = false;
      } else {
        title = "ZAFER! 🎉";
        subtitle =
            "Tebrikler! İmpostor olan '$impostorName' oyuncusunu başarıyla elediniz ve kazandınız!";
        isVictory = true;
      }
    } else {
      if (widget.amIImpostor) {
        title = "ZAFER! 😈";
        subtitle =
            "Köylüler yanlış kişiyi ($eliminatedPlayer) eledi! Sen yakalanmadın ve maçı kazandın.";
        isVictory = true;
      } else {
        title = "BOZGUN! 🛑";
        subtitle =
            "Yanlış kişiyi ($eliminatedPlayer) elediniz! Gerçek İmpostor '$impostorName' aranızda sinsi sinsi dolaşıyor.";
        isVictory = false;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
                  isVictory ? Icons.emoji_events_rounded : Icons.gavel_rounded,
                  size: 80,
                  color: isVictory ? Colors.amber : Colors.redAccent,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isVictory ? Colors.amber : Colors.redAccent,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  // 🎯 DEĞİŞİKLİK: 'amIHost' kontrolü tamamen kaldırıldı. Tuş artık HERKESTE aktif!
                  onTap: () {
                    // 🎯 TEMİZLİK: Dinleyicileri kapatıyoruz ki bir sonraki elde hayalet tetiklenme olmasın.
                    widget.socket.off('vote_status_updated');
                    widget.socket.off('voting_results');

                    Navigator.of(context).pop(); // Dialog'u kapat

                    // 🎯 DEĞİŞİKLİK: "LOBİYE DÖN" yerine mevcut odayı/kodunu koruyarak HostScreen'e geri yönlendiriyoruz.
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HostScreen(
                          gameMode: "Klasik",
                          category: "Rastgele",
                          impostorCount: 1,
                          socket: widget.socket,
                          hostName: widget.myName,
                          existingRoomCode: widget
                              .roomCode, // 🎯 EKLEME: Mevcut oda kodunu paslıyoruz!
                        ),
                      ),
                      (route) => route
                          .isFirst, // Giriş/Ana menü hariç tüm eski oyun sayfalarını stack'ten siler.
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF00D2FF,
                      ), // Herkes tıklayabileceği için canlı mavi renk yaptık
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        "ODAYA DÖN 🏠", // 🎯 DEĞİŞİKLİK: İstediğin gibi "ODAYA DÖN" olarak güncellendi.
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B0B1A),
                        ),
                      ),
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
    widget.socket.off('vote_status_updated');
    widget.socket.off('voting_results');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          "KİM İMPOSTER?",
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
              "Onaylanan Kilitli Oylar: $votedCount / ${widget.players.length}",
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
              itemCount: widget.players.length,
              itemBuilder: (context, index) {
                final playerName = widget.players[index];
                final isSelected = selectedPlayer == playerName;
                final currentVotes = playerVotes[playerName] ?? 0;

                return GestureDetector(
                  onTap: (hasLockedVote || isVotingClosed)
                      ? null
                      : () {
                          setState(() {
                            selectedPlayer = playerName;
                          });
                          submitVote(playerName, lockIt: false);
                        },
                  child: AnimatedScale(
                    scale: isSelected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 15),
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
                                ? "$playerName ($currentVotes Oy)"
                                : playerName,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (playerName == widget.myName) ...[
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
              onTap: (hasLockedVote || isVotingClosed)
                  ? null
                  : () {
                      submitVote(selectedPlayer ?? 'skip', lockIt: true);
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: hasLockedVote
                      ? const Color(0xFF2E2E5C).withOpacity(0.5)
                      : (selectedPlayer == null
                            ? const Color(0xFF2E2E5C)
                            : const Color(0xFF4CAF50)),
                ),
                child: Center(
                  child: Text(
                    hasLockedVote
                        ? "OYUN KİLİTLENDİ 🔒"
                        : (selectedPlayer == null
                              ? "PAS GEÇ VE KİLİTLE 🔒"
                              : "OYU KİLİTLE 🔒"),
                    style: const TextStyle(
                      fontSize: 18,
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
