// lib/screens/player_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart'; 
import 'game_screen.dart'; 

class PlayerScreen extends StatefulWidget {
  final String playerName;
  final String roomCode;
  final dynamic socket; 

  const PlayerScreen({
    super.key,
    required this.playerName,
    required this.roomCode,
    required this.socket, 
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Timer? _statusTimer;
  bool _isChecking = false;

  final List<String> joinedPlayers = [];
  List<String> returnedPlayers = []; // 🎯 YEŞİL OK TAKİBİ İÇİN

  @override
  void initState() {
    super.initState();
    _joinRoomOnServer(); 
    
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkGameStatus();
    });
  }

  void _joinRoomOnServer() {
    if (widget.socket != null) {
      widget.socket.emit('join_room', {
        'roomCode': widget.roomCode,
        'playerName': widget.playerName,
      });

      widget.socket.on('room_updated', (data) {
        if (!mounted) return;
        var incomingPlayers = data['players'];
        if (incomingPlayers is List) {
          setState(() {
            joinedPlayers.clear();
            joinedPlayers.addAll(incomingPlayers.map((e) => e.toString()).toList());
          });
        }
      });

      // 🎯 ANLIK YEŞİL OK GÜNCELLEMESİ
      widget.socket.on('lobby_return_status', (data) {
        if (!mounted) return;
        setState(() {
          returnedPlayers = List<String>.from(data['returnedPlayers'] ?? []);
        });
      });

      // Odaya girer girmez sunucuya "Ben de buradayım" desin kanka
      widget.socket.emit('player_returned_to_lobby', {
        'roomCode': widget.roomCode,
        'playerName': widget.playerName,
      });
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkGameStatus() async {
    if (_isChecking) return;
    if (!mounted) return;
    setState(() => _isChecking = true);

    final url = Uri.parse('${AppConfig.serverUrl}/api/game-status/${widget.roomCode}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'started') {
          _statusTimer?.cancel(); 

          String secretWord = data['secretWord'] ?? '';
          String impWord = data['impostorWord'] ?? '';
          
          var impostorData = data['impostor'];
          List<String> impostors = [];
          if (impostorData is List) {
            impostors = impostorData.map((e) => e.toString()).toList();
          } else if (impostorData != null) {
            impostors = [impostorData.toString()];
          }

          bool isMeImpostor = impostors.contains(widget.playerName);

          var serverPlayers = data['players'];
          List<String> activePlayersList = [...joinedPlayers];
          if (serverPlayers is List) {
            activePlayersList = serverPlayers.map((e) => e.toString()).toList();
          }

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(
                playerName: widget.playerName,
                secretWord: isMeImpostor ? impWord : secretWord,
                isImpostor: isMeImpostor,
                socket: widget.socket, 
                roomCode: widget.roomCode, 
                players: activePlayersList, 
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Oda durumu sorgulanamadı: $e");
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!joinedPlayers.contains(widget.playerName)) {
      joinedPlayers.add(widget.playerName);
    }

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
            key: const ValueKey('player_screen_padding'),
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
                          'BAĞLANILAN ODA KODU',
                          style: TextStyle(color: Color(0xFF8E8EAF), fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.roomCode,
                          style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: 5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Odada Kimler Var?',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text('${joinedPlayers.length} Oyuncu'),
                          backgroundColor: const Color(0xFF2E2E5C),
                          padding: EdgeInsets.zero,
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      label: const Text('Odadan Çık', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: joinedPlayers.length,
                    itemBuilder: (context, index) {
                      bool isMe = joinedPlayers[index] == widget.playerName;
                      bool isReturned = returnedPlayers.contains(joinedPlayers[index]); // 🎯 YEŞİL OK
                      return Card(
                        color: const Color(0xFF101026),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isMe ? const Color(0xFF00D2FF) : const Color(0xFF2E2E5C), width: isMe ? 1.5 : 1),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.person, color: isMe ? const Color(0xFF00D2FF) : const Color(0xFF8E8EAF)),
                          title: Text(
                            joinedPlayers[index] + (isMe ? " (Sen)" : ""),
                            style: TextStyle(color: isMe ? const Color(0xFF00D2FF) : Colors.white, fontSize: 16, fontWeight: isMe ? FontWeight.bold : FontWeight.w500),
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
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181832).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E2E5C)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D2FF)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Hostun oyunu başlatması bekleniyor...',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF8E8EAF)),
                      ),
                    ],
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