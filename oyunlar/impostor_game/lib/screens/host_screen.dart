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
  final String? existingRoomCode; 

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
  List<String> returnedPlayers = []; // 🎯 YEŞİL OK TAKİBİ İÇİN
  bool isEveryoneBack = false;       // 🎯 BUTON KİLİDİ İÇİN

  String? debugSecretWord;
  List<String> debugImpostorNames = [];
  Map<String, String> debugDistribution = {};

  late String roomCode;
  bool isActualHost = false; 

  @override
  void initState() {
    super.initState();
    if (widget.existingRoomCode != null) {
      roomCode = widget.existingRoomCode!;
    } else {
      roomCode = _generateRandomRoomCode();
    }
    _registerRoomOnServer();
    _checkHostStatus(); 
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
        'gameMode': widget.gameMode,
        'category': widget.category,
        'impostorCount': widget.impostorCount,
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

      // 🎯 SİNKRONE LOBİ DİNLEYİCİSİ: Oylama bitip gelenleri yakalar
      widget.socket.on('lobby_return_status', (data) {
        if (!mounted) return;
        setState(() {
          returnedPlayers = List<String>.from(data['returnedPlayers'] ?? []);
          isEveryoneBack = data['isEveryoneBack'] ?? false;
        });
      });

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
              players: joinedPlayers.isNotEmpty ? joinedPlayers : [widget.hostName],
            ),
          ),
        );
      });
      
      // Giriş yapar yapmaz sunucuya "Buradayım" de kanka
      widget.socket.emit('player_returned_to_lobby', {
        'roomCode': roomCode,
        'playerName': widget.hostName,
      });
    }
  }

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

    // Tek başına oynuyorsa buton kilitlenmesin kanka
    bool canStart = isEveryoneBack || joinedPlayers.length <= 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
                    side: const BorderSide(color: Color(0xFF2E2E5C), width: 1.5),
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
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text('${joinedPlayers.length} Oyuncu'),
                      backgroundColor: const Color(0xFF2E2E5C),
                      side: const BorderSide(color: Color(0xFF00D2FF), width: 1),
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: joinedPlayers.isEmpty
                      ? const Center(
                          child: Text(
                            'Oyuncuların gelmesi bekleniyor...',
                            style: TextStyle(color: Color(0xFF8E8EAF), fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: joinedPlayers.length,
                          itemBuilder: (context, index) {
                            // 🎯 YEŞİL OK KONTROLÜ
                            bool isReturned = returnedPlayers.contains(joinedPlayers[index]);
                            return Card(
                              color: const Color(0xFF101026),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFF2E2E5C), width: 1),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.person, color: Color(0xFF8E8EAF)),
                                title: Text(
                                  joinedPlayers[index],
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                trailing: isReturned
                                    ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24)
                                    : const Icon(Icons.hourglass_empty_rounded, color: Colors.amberAccent, size: 20),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),

                isActualHost
                    ? ElevatedButton(
                        // 🎯 KİLİT MEKANİZMASI: Herkes dönmediyse buton kilitli (null)
                        onPressed: !canStart
                            ? null
                            : () async {
                                if (joinedPlayers.length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Oyunu başlatmak için en az 2 oyuncu olmalıdır!')),
                                  );
                                  return;
                                }

                                final url = Uri.parse('${AppConfig.serverUrl}/api/start-game');
                                try {
                                  await http.post(
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
                                } catch (e) {
                                  debugPrint("Bağlantı hatası: $e");
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !canStart ? Colors.grey.shade800 : const Color(0xFF00D2FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          !canStart
                              ? 'OYUNCULARIN ODALARA DÖNMESİ BEKLENİYOR... ⏳'
                              : 'OYUNU BAŞLAT',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: !canStart ? Colors.white30 : const Color(0xFF0B0B1A),
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
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white60),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}