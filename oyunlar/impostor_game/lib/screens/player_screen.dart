// lib/screens/player_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
  String actualHost = '';

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
            actualHost = data['host']?.toString() ?? actualHost;
            joinedPlayers.clear();
            joinedPlayers.addAll(
              incomingPlayers.map((e) => e.toString()).toList(),
            );
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

  Future<void> _copyRoomCode() async {
    await Clipboard.setData(ClipboardData(text: widget.roomCode));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oda kodu kopyalandı.')));
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

    final url = Uri.parse(
      '${AppConfig.serverUrl}/api/game-status/${widget.roomCode}',
    );

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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Odadan çık',
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.logout_rounded),
              color: const Color(0xFFE08A6D),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      extendBodyBehindAppBar: true,
      bottomNavigationBar: Container(
        color: const Color(0xFF171315),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2023).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF584047)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFE08A6D),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Kurucunun oyunu başlatması bekleniyor...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC8B9B2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF33272A), Color(0xFF241C1E), Color(0xFF171315)],
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
                  color: const Color(0xFF2A2023).withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(
                      color: Color(0xFF584047),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          'ODA KODU',
                          style: TextStyle(
                            color: Color(0xFFC8B9B2),
                            fontSize: 13,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.roomCode,
                              style: const TextStyle(
                                color: Color(0xFFE08A6D),
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 5,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Oda kodunu kopyala',
                              onPressed: _copyRoomCode,
                              icon: const Icon(
                                Icons.copy_rounded,
                                color: Color(0xFFE08A6D),
                              ),
                            ),
                          ],
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
                          'Odadaki oyuncular',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text('${joinedPlayers.length} Oyuncu'),
                          backgroundColor: const Color(0xFF584047),
                          padding: EdgeInsets.zero,
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: joinedPlayers.length,
                    itemBuilder: (context, index) {
                      bool isMe = joinedPlayers[index] == widget.playerName;
                      bool isReturned = returnedPlayers.contains(
                        joinedPlayers[index],
                      ); // 🎯 YEŞİL OK
                      return Card(
                        color: const Color(0xFF281E21),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isMe
                                ? const Color(0xFFE08A6D)
                                : const Color(0xFF584047),
                            width: isMe ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.person,
                            color: isMe
                                ? const Color(0xFFE08A6D)
                                : const Color(0xFFC8B9B2),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  joinedPlayers[index] + (isMe ? " (Sen)" : ""),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isMe
                                        ? const Color(0xFFE08A6D)
                                        : Colors.white,
                                    fontSize: 16,
                                    fontWeight: isMe
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (joinedPlayers[index] == actualHost)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Chip(
                                    avatar: Icon(Icons.star_rounded, size: 16),
                                    label: Text('KURUCU'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                          trailing: isReturned
                              ? const Chip(
                                  avatar: Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF8FD6A8),
                                    size: 18,
                                  ),
                                  label: Text('LOBİDE'),
                                  visualDensity: VisualDensity.compact,
                                )
                              : const Icon(
                                  Icons.hourglass_empty_rounded,
                                  color: Colors.amberAccent,
                                  size: 20,
                                ),
                        ),
                      );
                    },
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
