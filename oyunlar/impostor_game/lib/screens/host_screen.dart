// lib/screens/host_screen.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'game_screen.dart';

class HostScreen extends StatefulWidget {
  final String gameMode;
  final String category;
  final int impostorCount;

  const HostScreen({
    super.key,
    required this.gameMode,
    required this.category,
    required this.impostorCount,
  });

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  // Şimdilik test amaçlı yazdığımız öğrenci listesi kanka
  final List<String> joinedPlayers = ['Ceyda', 'Ahmet', 'Ayşe', 'Mehmet'];

  // =========================================================================
  // ⚙️ GÜNCELLENEN ALGORİTMA DOĞRULAMA DEĞİŞKENLERİ (Çoklu İmpostor Destekli)
  // =========================================================================
  String? debugSecretWord;
  List<String> debugImpostorNames = []; // Tekil String yerine Liste yaptık kanka!
  Map<String, String> debugDistribution = {};
  // =========================================================================

  late String roomCode;

  @override
  void initState() {
    super.initState();
    // Ekran ilk açıldığı an kodu 6 haneli ve rastgele üretiyoruz
    roomCode = _generateRandomRoomCode();
  }

  // 6 Haneli Rastgele Kod Üreten Fonksiyon
  String _generateRandomRoomCode() {
    const chars = 'ABCDEFGHJKLMNOPQRSTUVWXYZ23456789';
    Random random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1E38), Color(0xFF13132B), Color(0xFF0B0B1A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ÜST KISIM: Oda Kodu Bilgisi
                Card(
                  color: const Color(0xFF181832).withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(
                      color: Color(0xFF2E2E5C),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          'ÖĞRENCİLER İÇİN ODA KODU',
                          style: TextStyle(
                            color: Color(0xFF8E8EAF),
                            fontSize: 13,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          roomCode,
                          style: const TextStyle(
                            color: Color(0xFF00D2FF), // Orijinal turkuaz neon renginiz
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // ORTA KISIM: Katılan Oyuncu Sayısı ve Başlığı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Katılan Oyuncular',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Chip(
                      label: Text('${joinedPlayers.length} Oyuncu'),
                      backgroundColor: const Color(0xFF2E2E5C),
                      side: const BorderSide(
                        color: Color(0xFF00D2FF),
                        width: 1,
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // OYUNCU LİSTESİ: Anlık girenlerin listelendiği alan
                Expanded(
                  child: joinedPlayers.isEmpty
                      ? const Center(
                          child: Text(
                            'Oyuncuların gelmesi bekleniyor...',
                            style: TextStyle(
                              color: Color(0xFF8E8EAF),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: joinedPlayers.length,
                          itemBuilder: (context, index) {
                            return Card(
                              color: const Color(0xFF101026),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFF2E2E5C),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.person,
                                  color: Color(0xFF8E8EAF),
                                ),
                                title: Text(
                                  joinedPlayers[index],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF00D2FF),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),

                // EN ALT KISIM: Oyunu Başlatma Butonu
                ElevatedButton(
                  onPressed: () async {
                    if (joinedPlayers.isEmpty) return;

                    final url = Uri.parse('http://127.0.0.1:3000/api/start-game');

                    try {
                      // 1. Login ekranından constructor ile aldığımız tüm ayarları paketleyip backend'e fırlatıyoruz kanka 🚀
                      final response = await http.post(
                        url,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'roomCode': roomCode,
                          'players': joinedPlayers,
                          'gameMode': widget.gameMode,
                          'category': widget.category,
                          'impostorCount': widget.impostorCount,
                        }),
                      );

                      if (response.statusCode == 200) {
                        final data = jsonDecode(response.body);

                        String secretWord = data['secretWord'];
                        
                        // Backend'den gelen array yapısını güvenli listeye döküyoruz
                        var impostorData = data['impostor']; 
                        List<String> impostors = [];
                        
                        if (impostorData is List) {
                          impostors = impostorData.map((e) => e.toString()).toList();
                        } else {
                          impostors = [impostorData.toString()];
                        }

                        setState(() {
                          debugSecretWord = secretWord;
                          debugImpostorNames = impostors; // Sorun çıkaran liste artık eşitlendi kanka!

                          debugDistribution.clear();
                          for (var player in joinedPlayers) {
                            if (debugImpostorNames.contains(player)) {
                              String impWord = data['impostorWord'] ?? "Kelime Yok";
                              debugDistribution[player] = "😈 IMPOSTER ($impWord)";
                            } else {
                              debugDistribution[player] = "🧑‍🌾 Köylü (Kelime: $debugSecretWord)";
                            }
                          }
                        });

                        // Test için ilk oyuncunun ekran geçiş durumu
                        String currentTestPlayer = joinedPlayers[0];
                        bool isMeImpostor = debugImpostorNames.contains(currentTestPlayer);

                        if (!mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameScreen(
                              playerName: currentTestPlayer,
                              secretWord: isMeImpostor ? (data['impostorWord'] ?? '') : secretWord,
                              isImpostor: isMeImpostor,
                            ),
                          ),
                        );

                      } else {
                        debugPrint("Sunucu hatası: ${response.body}");
                      }
                    } catch (e) {
                      debugPrint("Bağlantı hatası: $e");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2FF), // Turkuaz buton renginiz
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'OYUNU BAŞLAT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B0B1A),
                      letterSpacing: 1,
                    ),
                  ),
                ),

                // =========================================================================
                // 🛠️ YENİ HALE GETİRİLEN: ÇOKLU CANLI KONTROL PANELİ WIDGET'I 🚀
                // =========================================================================
                if (debugImpostorNames.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C3A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00D2FF),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bug_report, color: Color(0xFF00D2FF), size: 20),
                            SizedBox(width: 8),
                            Text(
                              "HOST ALGORİTMA DOĞRULAMA PANELİ",
                              style: TextStyle(
                                color: Color(0xFF00D2FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24),
                        Text(
                          "🎯 Seçilen Kelime: $debugSecretWord",
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        // Tüm seçilen imposter'ları yan yana virgülle yazdırıyoruz kanka kanka
                        Text(
                          "😈 Seçilen Imposter(lar): ${debugImpostorNames.join(', ')}",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "📊 Oyuncu Rol Dağılım Listesi:",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ...debugDistribution.entries.map((entry) {
                          bool isImpostor = debugImpostorNames.contains(entry.key);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    color: isImpostor ? Colors.redAccent : Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                // =========================================================================
              ],
            ),
          ),
        ),
      ),
    );
  }
}