import 'dart:async';
import 'package:flutter/material.dart';
import 'entry_screen.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final Gender gender;
  final bool isHost;
  final int vampireCount;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.gender,
    required this.isHost,
    required this.vampireCount,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late List<Map<String, dynamic>> _players;
  Timer? _mockJoinTimer;

  // Katılacak mock oyuncular
  final List<Map<String, dynamic>> _mockPool = [
    {'name': 'Esmanur', 'gender': Gender.male},
    {'name': 'Tuğba', 'gender': Gender.female},
    {'name': 'Esengül', 'gender': Gender.male},
    {'name': 'Ayşe', 'gender': Gender.female},
    {'name': 'Ali', 'gender': Gender.male},
    {'name': 'Yusuf', 'gender': Gender.female},
    {'name': 'Veli', 'gender': Gender.male},
  ];

  @override
  void initState() {
    super.initState();
    // İlk oyuncu kurucu/muhtar
    _players = [
      {
        'name': widget.playerName,
        'gender': widget.gender,
        'isHost': widget.isHost,
        'isReady': true,
      },
    ];

    // Belirli aralıklarla mock oyuncuların köye katılması simülasyonu
    _startMockPlayerJoins();
  }

  void _startMockPlayerJoins() {
    int index = 0;
    _mockJoinTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (index < _mockPool.length) {
        if (mounted) {
          setState(() {
            _players.add({
              'name': _mockPool[index]['name'],
              'gender': _mockPool[index]['gender'],
              'isHost': false,
              'isReady': true,
            });
          });
        }
        index++;
      } else {
        timer.cancel();
      }
    });
  }

  void _startGame() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          roomCode: widget.roomCode,
          playerName: widget.playerName,
          gender: widget.gender,
          isHost: widget.isHost,
          vampireCount: widget.vampireCount,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mockJoinTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ÜST KISIM: Oda Kodu Kartı
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141432),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A5A)),
                ),
                child: Column(
                  children: [
                    Text(
                      'KÖYLÜLER İÇİN ODA KODU',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      widget.roomCode,
                      style: const TextStyle(
                        color: Color(0xFF00D2FF),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ORTA KISIM: Katılan Oyuncular Başlığı & Sayaç
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Katılan Oyuncular',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141432),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00D2FF).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      '${_players.length} Oyuncu',
                      style: const TextStyle(
                        color: Color(0xFF00D2FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Oyuncu Listesi
              Expanded(
                child: ListView.builder(
                  itemCount: _players.length,
                  itemBuilder: (context, index) {
                    final p = _players[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141432),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: p['isHost']
                              ? const Color(0xFF00D2FF).withOpacity(0.5)
                              : const Color(0xFF2A2A5A),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            p['gender'] == Gender.male
                                ? Icons.person
                                : Icons.person_outline,
                            color: const Color(0xFF00D2FF),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            p['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (p['isHost']) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D2FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'MUHTAR',
                                style: TextStyle(
                                  color: Color(0xFF00D2FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF00D2FF),
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ALT KISIM: Oyunu Başlat Butonu
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: widget.isHost || _players.length >= 2
                      ? _startGame
                      : null,
                  child: Text(
                    widget.isHost
                        ? 'OYUNU BAŞLAT'
                        : 'KÖYÜN BAŞLAMASI BEKLENİYOR...',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
