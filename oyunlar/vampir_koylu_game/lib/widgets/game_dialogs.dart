import 'package:flutter/material.dart';
import '../player_model.dart';
import '../services/socket_service.dart';
import '../widgets/role_reveal_card.dart';

class GameDialogs {
  // 🎯 Ekranda aktif rol kartı modalı var mı takibi (Çift dialog açılmasını engeller)
  static bool _isRoleCardShowing = false;

  // Debug / Algoritma Çıktı Dialogu
  static void showRoleDistributionDebug(
    BuildContext context,
    List<PlayerModel> players,
  ) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Kullanıcının Kendi Gizli Rol Kartı (Tekil Dialog ve Timer Garantili)
  static void showMyRoleCard(
    BuildContext context,
    PlayerModel myPlayer, {
    required String roomCode,
    required SocketService socketService,
    List<String> teamMates = const [],
  }) {
    // 🛑 Ekranda zaten bir rol kartı açıksa ikincisini AÇMA!
    if (_isRoleCardShowing) {
      print("⚠️ [DIALOG] Ekranda zaten açık rol kartı var, tekrar açılmadı.");
      return;
    }
    _isRoleCardShowing = true;

    Color roleColor = myPlayer.avatarColor;
    final String lowerRole = myPlayer.role.toLowerCase();

    if (lowerRole.contains('vampir')) {
      roleColor = Colors.redAccent;
    } else if (lowerRole.contains('doktor')) {
      roleColor = Colors.greenAccent;
    } else if (lowerRole.contains('katil')) {
      roleColor = Colors.purpleAccent;
    }

    // Modal Güvenli Kapatma Metodu
    void safeCloseCard(BuildContext ctx) {
      if (_isRoleCardShowing) {
        _isRoleCardShowing = false;
        if (Navigator.of(ctx, rootNavigator: true).canPop()) {
          Navigator.of(ctx, rootNavigator: true).pop();
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        // Eski dinleyiciyi kaldır
        socketService.socket?.off('vk_all_roles_seen');

        // Sunucudan Herkes Onayladı Sinyali Gelirse
        socketService.socket?.once('vk_all_roles_seen', (_) {
          print("📥 [DIALOG] vk_all_roles_seen SİNYALİ GELDİ! KART KAPATILIYOR...");
          safeCloseCard(dialogContext);
        });

        return PopScope(
          canPop: false,
          child: RoleRevealCard(
            roleName: myPlayer.role,
            roleDescription:
                'Köydeki rolünü gizli tut ve stratejini buna göre belirle.',
            roleColor: roleColor,
            teamMates: teamMates,
            onDismiss: () {
              // 🎯 Butona basılınca veya 10sn Timer dolunca çağrılır
              safeCloseCard(dialogContext);
            },
            onReadySubmitted: () {
              print("🚀 [DIALOG] SOCKET EMIT EDİLİYOR! Oda: $roomCode, İsim: ${myPlayer.name}");
              
              final activeSocket = SocketService().socket ?? socketService.socket;
              
              if (activeSocket != null && activeSocket.connected) {
                activeSocket.emit('vk_player_role_seen', {
                  'roomCode': roomCode,
                  'playerName': myPlayer.name,
                });
                print("✅ [DIALOG] EMIT BAŞARIYLA GÖNDERİLDİ!");
              } else {
                print("❌ [DIALOG HATA] Socket bağlantısı kopuk!");
              }
            },
          ),
        );
      },
    ).then((_) {
      // Modal dışarıdan bir şekilde kapandığında bayrağı temizle
      _isRoleCardShowing = false;
    });
  }
}