// lib/screens/voting_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VotingScreen extends StatefulWidget {
  final dynamic socket; // Canlı soket objesi
  final String roomCode; // Oda kodu
  final String myName; // Oyuncu ismi
  final List<String> players; // Odadaki oyuncular
  final bool amIImpostor; // Ben impostor mıyım?

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
  bool hasVoted = false; // Kullanıcı oyunu gönderdi mi?
  int votedCount = 0; // Kaç kişi oy verdi canlı göstergesi

  @override
  void initState() {
    super.initState();
    
    startTimer();
    setupSocketListeners();
  }

  // 🔌 Sunucudan gelecek canlı sonuç olaylarını dinliyoruz kanka
  void setupSocketListeners() {
    // Diğer oyuncular oy verdikçe sayacı güncelle
    widget.socket.on('vote_status_updated', (data) {
      if (!mounted) return;
      setState(() {
        votedCount = data['votedCount'];
      });
    });

    // Herkes oy verince veya süre bitince sonuçlar geliyor kanka! 🔥
    widget.socket.on('voting_results', (data) {
      if (!mounted) return;
      
      _timer?.cancel(); // Zamanlayıcıyı kesin olarak kapat
      
      setState(() {
        isVotingClosed = true;
      });

      String eliminatedPlayer = data['eliminatedPlayer'] ?? "Kimse elenmedi (Beraberlik)";
      bool isTie = data['isTie'] ?? false;
      String impostorName = data['impostorName'] ?? "";

      showResultsDialog(eliminatedPlayer, isTie, impostorName);
    });
  }

  void startTimer() {
    const int totalDuration = 15; // 15 saniye oylama süresi
    const int milliseconds = 100;
    final double increment = milliseconds / (totalDuration * 1000);

    _timer = Timer.periodic(const Duration(milliseconds: milliseconds), (timer) {
      if (!mounted) return;
      setState(() {
        if (progress < 1.0) {
          progress += increment;
        } else {
          progress = 1.0;
          timer.cancel();
          // Süre bittiğinde oy vermediysek otomatik "Boş/Skip" oy fırlat kanka
          if (!hasVoted) {
            submitVote(isTimeout: true);
          }
        }
      });
    });
  }

  // OY VERME AKSİYONU
  void submitVote({bool isTimeout = false}) {
    HapticFeedback.heavyImpact();
    
    setState(() {
      hasVoted = true;
    });

    // Oy verdiğimiz oyuncuyu soketle sunucuya fırlatıyoruz! 🚀
    widget.socket.emit('submit_vote', {
      'roomCode': widget.roomCode,
      'voterName': widget.myName,
      'votedFor': isTimeout ? 'skip' : selectedPlayer,
    });
  }

  // MULTIPLAYER SONUÇ EKRANI DIALOG PENCERESİ 🏆
  void showResultsDialog(String eliminatedPlayer, bool isTie, String impostorName) {
    String title = "";
    String subtitle = "";
    bool isVictory = false;

    // 1. Durum: Beraberlik olduysa
    if (isTie) {
      title = "BERABERLİK! ⚖️";
      subtitle = "Oylamada eşitlik çıktı, kimse elenmedi! Gerçek İmpostor '$impostorName' aramızda sızmaya devam ediyor.";
      isVictory = widget.amIImpostor; // İmpostor yakalanamadığı için İmpostor kazanmış sayılır
    } 
    // 2. Durum: İmpostor başarıyla elendiyse
    else if (eliminatedPlayer == impostorName) {
      if (widget.amIImpostor) {
        title = "YAKALANDIN! 💀";
        subtitle = "Diğer oyuncular senin İmpostor olduğunu doğru bildi. Maçı kaybettin kanka!";
        isVictory = false;
      } else {
        title = "ZAFER! 🎉";
        subtitle = "Tebrikler! İmpostor olan '$impostorName' oyuncusunu başarıyla elediniz ve kazandınız!";
        isVictory = true;
      }
    } 
    // 3. Durum: Masum bir köylü elendiyse
    else {
      if (widget.amIImpostor) {
        title = "ZAFER! 😈";
        subtitle = "Köylüler yanlış kişiyi ($eliminatedPlayer) eledi! Sen yakalanmadın ve maçı kazandın.";
        isVictory = true;
      } else {
        title = "BOZGUN! 🛑";
        subtitle = "Yanlış kişiyi ($eliminatedPlayer) elediniz! Gerçek İmpostor '$impostorName' aranızda sinsi sinsi dolaşıyor.";
        isVictory = false;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Dışarı tıklayıp kapatamazlar
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF151528),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  onTap: () {
                    // Soket dinleyicilerini kapatıp çıkalım kanka
                    widget.socket.off('vote_status_updated');
                    widget.socket.off('voting_results');
                    Navigator.of(context).pop(); // Diyaloğu kapat
                    Navigator.of(context).pop(); // Oylamadan çık (GameScreen'e dön)
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2E5C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        "LOBİYE DÖN",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B1A),
      appBar: AppBar(
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ZAMAN ÇUBUĞU
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
            child: Text(
              widget.amIImpostor ? "😈 ROLÜN: İMPOSTOR" : "🧑‍🚀 ROLÜN: KÖYLÜ",
              style: TextStyle(
                color: widget.amIImpostor ? Colors.redAccent : const Color(0xFF8E8EAF),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // Kaç kişinin oy verdiğini gösteren canlı bilgi kutusu kanka
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Text(
              "Oy Verenler: $votedCount / ${widget.players.length}",
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

                return GestureDetector(
                  onTap: (hasVoted || isVotingClosed)
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          setState(() => selectedPlayer = playerName);
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
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            color: isSelected ? Colors.white : Colors.white54,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            playerName,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          if (playerName == widget.myName) ...[
                            const Spacer(),
                            const Text(
                              "(SEN)",
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            )
                          ]
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
              onTap: (selectedPlayer == null || hasVoted || isVotingClosed)
                  ? null
                  : () {
                      submitVote();
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: hasVoted
                      ? const Color(0xFF2E2E5C).withValues(alpha: 0.5)
                      : (selectedPlayer == null
                            ? const Color(0xFF2E2E5C)
                            : Colors.redAccent),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    hasVoted
                        ? "DİĞER OYUNCULAR BEKLENİYOR..."
                        : (selectedPlayer == null
                              ? "BİRİNİ SEÇ"
                              : "OYU GÖNDER"),
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