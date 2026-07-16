import 'dart:async'; // Timer için gerekli
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key});

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  late List<String> players;
  String? selectedPlayer;
  double progress = 0.0;
  Timer? _timer;

  // DİKKAT: Burada 'bool' tipini kesinleştiriyoruz ve başlangıç değerini atıyoruz
  bool isVotingClosed = false;
  @override
  void initState() {
    super.initState();
    int playerCount = Random().nextInt(8) + 3;
    players = List.generate(playerCount, (index) => "Oyuncu ${index + 1}");
    startTimer(); // Sayfa açılır açılmaz zamanlayıcıyı başlat
  }

  void startTimer() {
    const int totalDuration = 10; // Toplam saniye
    const int milliseconds = 100; // Güncelleme hızı
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
          isVotingClosed = true;
          timer.cancel();
        }
      });
    });
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
          // GÜNCELLENMİŞ ZAMAN ÇUBUĞU
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
              widthFactor: progress, // Değişken buraya bağlandı
              child: Container(
                decoration: BoxDecoration(
                  color: isVotingClosed ? Colors.grey : Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(bottom: 20.0, top: 10.0),
            child: Text(
              "ŞÜPHELENDİĞİN KİŞİYİ SEÇ",
              style: TextStyle(
                color: Color(0xFF8E8EAF),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final playerName = players[index];
                final isSelected = selectedPlayer == playerName;

                return GestureDetector(
                  // Süre dolduysa tıklamayı engelle
                  onTap: isVotingClosed
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
              onTap: (selectedPlayer == null || isVotingClosed)
                  ? null
                  : () {
                      HapticFeedback.heavyImpact();
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: isVotingClosed
                      ? Colors.grey
                      : (selectedPlayer == null
                            ? const Color(0xFF2E2E5C)
                            : Colors.redAccent),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    isVotingClosed
                        ? "SÜRE DOLDU"
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
