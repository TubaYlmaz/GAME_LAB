// lib/screens/host_screen.dart

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'game_screen.dart';

class HostScreen extends StatefulWidget {
  final String gameMode;
  final String category;
  final int impostorCount;
  final dynamic socket;
  final String hostName;
  final String?
  existingRoomCode; // 🎯 Oylamadan geri dönen oyuncular için opsiyonel eski oda kodu parametresi.

  const HostScreen({
    super.key,
    required this.gameMode,
    required this.category,
    required this.impostorCount,
    required this.socket,
    required this.hostName,
    this.existingRoomCode,
  });

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final List<String> joinedPlayers = [];

  String? debugSecretWord;
  List<String> debugImpostorNames = [];
  Map<String, String> debugDistribution = {};

  late String roomCode;
  bool isActualHost =
      false; // 🎯 Kullanıcının asıl host (kurucu) olup olmadığını tutar.

  @override
  void initState() {
    super.initState();
    if (widget.existingRoomCode != null) {
      roomCode = widget.existingRoomCode!;
    } else {
      roomCode = _generateRandomRoomCode();
    }
    _registerRoomOnServer();
    _checkHostStatus(); // 🎯 Sunucuya host kimliği sorgusu gönderir.
  }

  String _generateRandomRoomCode() {
    const chars = 'ABCDEFGHJKLMNOPQRSTUVWXYZ23456789';
    Random random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  void _registerRoomOnServer() {
    if (widget.socket != null) {
      widget.socket.emit('create_room', {
        'roomCode': roomCode,
        'hostName': widget.hostName,
      });

      widget.socket.on('room_updated', (data) {
        if (!mounted) return;
        var incomingPlayers = data['players'];
        if (incomingPlayers is List) {
          setState(() {
            joinedPlayers.clear();
            joinedPlayers.addAll(
              incomingPlayers.map((e) => e.toString()).toList(),
            );
          });
        }
      });

      // 🎯 HATA ÇÖZÜMÜ: Öğretmen oyunu başlattığında, lobi modunda bekleyen öğrencileri de yakalayıp GameScreen'e uçuracak soket dinleyicisi:
      widget.socket.on('game_started', (data) {
        if (!mounted) return;

        String secretWord = data['secretWord'] ?? '';
        String impWord = data['impostorWord'] ?? '';

        var impostorData = data['impostor'];
        List<String> impostors = [];
        if (impostorData is List) {
          impostors = impostorData.map((e) => e.toString()).toList();
        } else {
          impostors = [impostorData.toString()];
        }

        bool isMeImpostor = impostors.contains(widget.hostName);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              playerName: widget.hostName,
              secretWord: isMeImpostor ? impWord : secretWord,
              isImpostor: isMeImpostor,
              socket: widget.socket,
              roomCode: roomCode,
              players: joinedPlayers.isNotEmpty
                  ? joinedPlayers
                  : [widget.hostName],
            ),
          ),
        );
      });
    }
  }

  // 🎯 Geri dönen oyuncunun asıl yetkili olup olmadığını doğrular
  void _checkHostStatus() {
    if (widget.socket != null) {
      widget.socket.emit('check_host', {
        'roomCode': roomCode,
        'playerName': widget.hostName,
      });

      widget.socket.on('host_verification', (data) {
        if (!mounted) return;
        setState(() {
          isActualHost = data['isHost'] ?? false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!joinedPlayers.contains(widget.hostName)) {
      joinedPlayers.insert(0, widget.hostName);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
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
                Card(
                  color: const Color(0xFF181832).withValues(alpha: 0.9),
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
                            color: Color(0xFF00D2FF),
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

                // 🎯 Sadece asıl oda kurucusu (Öğretmen) başlatma butonunu görebilir.
                isActualHost
                    ? ElevatedButton(
                        onPressed: () async {
                          if (joinedPlayers.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Oyunu başlatmak için en az 2 oyuncu olmalıdır!',
                                ),
                              ),
                            );
                            return;
                          }

                          final url = Uri.parse(
                            '${AppConfig.serverUrl}/api/start-game',
                          );

                          try {
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

                            if (response.statusCode != 200) {
                              debugPrint("Sunucu hatası: ${response.body}");
                            }
                          } catch (e) {
                            debugPrint("Bağlantı hatası: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D2FF),
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
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E38),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2E2E5C)),
                        ),
                        child: const Center(
                          child: Text(
                            'ÖĞRETMENİN OYUNU BAŞLATMASI BEKLENİYOR... ⏳',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ),

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
                            Icon(
                              Icons.bug_report,
                              color: Color(0xFF00D2FF),
                              size: 20,
                            ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "😈 Seçilen Imposter(lar): ${debugImpostorNames.join(', ')}",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...debugDistribution.entries.map((entry) {
                          bool isImpostor = debugImpostorNames.contains(
                            entry.key,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    color: isImpostor
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
