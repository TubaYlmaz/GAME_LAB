import 'package:flutter/material.dart';
import '../screens/entry_screen.dart';
import '../player_model.dart';

class GameHud extends StatelessWidget {
  final Size screenSize;
  final int round;
  final GamePhase phase;
  final bool isAfterNight; // 🎯 Geceden sonraki gündüz mü kontrolü
  final List<String> logs;
  final List<PlayerModel> players;
  final String? selectedVoteTargetId;
  final PlayerModel myPlayer;
  final bool hasVotedInCurrentRound;

  final VoidCallback onShowRoleCard;
  final VoidCallback onShowDebugDialog;
  final ValueChanged<String?> onSelectPlayer;
  final VoidCallback onStartNight;
  final VoidCallback onStartDay;
  final VoidCallback onStartVoting;
  final VoidCallback onSubmitVote;

  const GameHud({
    super.key,
    required this.screenSize,
    required this.round,
    required this.phase,
    required this.isAfterNight,
    required this.logs,
    required this.players,
    required this.selectedVoteTargetId,
    required this.myPlayer,
    required this.hasVotedInCurrentRound,
    required this.onShowRoleCard,
    required this.onShowDebugDialog,
    required this.onSelectPlayer,
    required this.onStartNight,
    required this.onStartDay,
    required this.onStartVoting,
    required this.onSubmitVote,
  });

  String get _phaseText {
    switch (phase) {
      case GamePhase.night:
        return 'Gece 🌙';
      case GamePhase.dayDiscussion:
        return 'Gündüz ☀️';
      case GamePhase.voting:
        return 'Oylama 🗳️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool amIAlive = myPlayer.isAlive; // Canlı oyuncu kontrolü

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0, left: 16.0, right: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎯 CANLI OYUNCULAR İÇİN KONTROL ÇUBUĞU
              if (amIAlive)
                Container(
                  constraints: const BoxConstraints(maxWidth: 550),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0D2A).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(
                      color: const Color(0xFF00D2FF).withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // BİLGİ BARI
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildInfoChip(Icons.numbers, 'Tur $round', Colors.amber),
                          Container(width: 1, height: 14, color: Colors.white24),
                          _buildInfoChip(Icons.person_outline, myPlayer.role, const Color(0xFF00D2FF)),
                          Container(width: 1, height: 14, color: Colors.white24),
                          _buildInfoChip(Icons.timelapse, _phaseText, Colors.purpleAccent),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // AKSİYON BARI
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.article_outlined, color: Color(0xFF00D2FF), size: 28),
                            onPressed: onShowRoleCard,
                            tooltip: 'Rol Kartım',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00D2FF),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: () {
                                  // 🎯 TAM İSTEDİĞİN MÜKEMMEL AKIŞ:
                                  if (phase == GamePhase.dayDiscussion) {
                                    if (isAfterNight) {
                                      onStartVoting(); // Geceden çıkılmışsa -> Oylamaya git
                                    } else {
                                      onStartNight(); // Oylamadan çıkılmışsa -> Geceye git
                                    }
                                  } else if (phase == GamePhase.night) {
                                    onStartDay(); // Gecedeyken -> Gündüzü Başlat
                                  } else if (phase == GamePhase.voting) {
                                    onStartNight();
                                  }
                                },
                                child: Text(
                                  _getActionButtonText(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.people_alt_outlined,
                              color: Color(0xFF00D2FF),
                              size: 28,
                            ),
                            onPressed: onShowDebugDialog,
                            tooltip: 'Oyuncular & Debug',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // 👻 ÖLEN OYUNCULAR İÇİN (Ruh Modu)
              if (!amIAlive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded, color: Colors.white70, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Ruh Modundasın (İzleyici) 👻",
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 BUTON METİN DÖNGÜSÜ
  String _getActionButtonText() {
    if (phase == GamePhase.dayDiscussion) {
      return isAfterNight ? 'OYLAMAYI BAŞLAT 🗳️' : 'GECEYE GEÇ 🌙';
    } else if (phase == GamePhase.night) {
      return 'GÜNDÜZÜ BAŞLAT ☀️';
    } else if (phase == GamePhase.voting) {
      return 'GECEYE GEÇ 🌙';
    }
    return '';
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}