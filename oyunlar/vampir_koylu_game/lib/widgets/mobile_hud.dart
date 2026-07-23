import 'package:flutter/material.dart';
import '../screens/entry_screen.dart';
import '../player_model.dart';

class MobileHud extends StatelessWidget {
  final Size screenSize;
  final String roomCode;
  final int round;
  final GamePhase phase;
  final List<String> logs;
  final List<PlayerModel> players;
  final String? selectedVoteTargetId;
  final VoidCallback onShowRoleCard;
  final VoidCallback onShowDebugDialog;
  final Function(String id) onSelectPlayer;
  final VoidCallback onStartDay;
  final VoidCallback onStartVoting;
  final VoidCallback onSubmitVote;

  const MobileHud({
    super.key,
    required this.screenSize,
    required this.roomCode,
    required this.round,
    required this.phase,
    required this.logs,
    required this.players,
    required this.selectedVoteTargetId,
    required this.onShowRoleCard,
    required this.onShowDebugDialog,
    required this.onSelectPlayer,
    required this.onStartDay,
    required this.onStartVoting,
    required this.onSubmitVote,
  });

  // Mobil Log Panelini Alt Katmandan Aç (BottomSheet)
  void _openLogSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: screenSize.height * 0.45,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D2A).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: const Color(0xFF00D2FF), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'KÖY GÜNLÜĞÜ',
                style: TextStyle(
                  color: Color(0xFF00D2FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  itemCount: logs.length,
                  reverse: true,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      logs[logs.length - 1 - i],

                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Mobil Oyuncu Listesi & Oylama Panelini Aç (BottomSheet)
  void _openPlayerListSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: screenSize.height * 0.55,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D2A).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: const Color(0xFF00D2FF), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OYUNCU LİSTESİ',
                        style: TextStyle(
                          color: Color(0xFF00D2FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (phase == GamePhase.voting)
                        const Text(
                          'Oy vermek için kişiye dokun',
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final p = players[index];
                        final isSelected = selectedVoteTargetId == p.id;
                        return InkWell(
                          onTap: () {
                            if (phase == GamePhase.voting && p.isAlive) {
                              onSelectPlayer(p.id);
                              setSheetState(() {});
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.redAccent.withOpacity(0.3)
                                  : const Color(0xFF13132B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.redAccent : p.avatarColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 6,
                                  backgroundColor: p.isAlive ? p.avatarColor : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: TextStyle(
                                      color: isSelected ? Colors.yellow : (p.isAlive ? Colors.white : Colors.white30),
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Text(
                                  p.isAlive ? 'Hayatta' : 'Elendi',
                                  style: TextStyle(
                                    color: p.isAlive ? Colors.greenAccent : Colors.red,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mobil Üst Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D2A).withOpacity(0.9),
              border: const Border(bottom: BorderSide(color: Color(0xFF00D2FF), width: 1)),
            ),
            child: Row(
              children: [
                Text(
                  'KÖY: $roomCode',
                  style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.style, color: Color(0xFF00D2FF), size: 20),
                  onPressed: onShowRoleCard,
                ),
                IconButton(
                  icon: const Icon(Icons.bug_report_outlined, color: Colors.orangeAccent, size: 20),
                  onPressed: onShowDebugDialog,
                ),
                Text('Tur $round', style: const TextStyle(color: Color(0xFF8888BB), fontSize: 12)),
              ],
            ),
          ),
        ),

        // Mobil Yüzen Alt Aksiyon Barı
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D2A).withOpacity(0.92),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF00D2FF).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Log Butonu
                IconButton(
                  icon: const Icon(Icons.article_outlined, color: Color(0xFF00D2FF)),
                  onPressed: () => _openLogSheet(context),
                  tooltip: 'Günlük',
                ),

                // Oyun Aşama Butonları
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildPhaseButton(),
                  ),
                ),

                // Oyuncu Listesi / Oylama Butonu
                IconButton(
                  icon: Icon(
                    Icons.people_alt_outlined,
                    color: phase == GamePhase.voting ? Colors.redAccent : const Color(0xFF00D2FF),
                  ),
                  onPressed: () => _openPlayerListSheet(context),
                  tooltip: 'Oyuncular',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseButton() {
    if (phase == GamePhase.night) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D2FF)),
        onPressed: onStartDay,
        child: const Text('GÜNDÜZÜ BAŞLAT', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    } else if (phase == GamePhase.dayDiscussion) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
        onPressed: onStartVoting,
        child: const Text('OYLAMAYI BAŞLAT', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    } else {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: selectedVoteTargetId != null ? Colors.redAccent : Colors.grey[700],
        ),
        onPressed: selectedVoteTargetId != null ? onSubmitVote : null,
        child: Text(
          selectedVoteTargetId != null ? 'OYU GÖNDER' : 'KİŞİ SEÇİN',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
  }
}