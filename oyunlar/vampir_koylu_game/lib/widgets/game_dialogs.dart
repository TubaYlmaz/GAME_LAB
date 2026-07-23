import 'package:flutter/material.dart';
import '../player_model.dart';

class GameDialogs {
  // Debug / Algoritma Çıktı Dialogu
  static void showRoleDistributionDebug(BuildContext context, List<PlayerModel> players) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A3E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00D2FF), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.bug_report, color: Color(0xFF00D2FF)),
              const SizedBox(width: 8),
              Text(
                'TOPLAM OYUNCU: ${players.length}',
                style: const TextStyle(
                  color: Color(0xFF00D2FF),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: players.length,
              itemBuilder: (context, index) {
                final p = players[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.avatarColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          color: p.avatarColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        p.role,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D2FF),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'ANLADIM, OYUNA GEÇ',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Kullanıcının Kendi Gizli Rol Kartı
  static void showMyRoleCard(BuildContext context, PlayerModel myPlayer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13132B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: myPlayer.avatarColor, width: 2),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GİZLİ ROLÜN',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                myPlayer.role,
                style: TextStyle(
                  color: myPlayer.avatarColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}