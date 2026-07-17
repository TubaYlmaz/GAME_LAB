// lib/screens/game_screen.dart

import 'package:flutter/material.dart';
import 'voting_screen.dart';

class GameScreen extends StatefulWidget {
  final String playerName;
  final String secretWord; // Köylünün kelimesi ya da İmpostor'ın yakın kelimesi buraya paslanıyor kanka!
  final bool isImpostor;
  final dynamic socket; 
  final String roomCode; 
  final List<String> players; 

  const GameScreen({
    super.key,
    required this.playerName,
    required this.secretWord,
    required this.isImpostor,
    required this.socket,
    required this.roomCode,
    required this.players,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _isWordVisible = false;
  bool amIHost = false; 

  @override
  void initState() {
    super.initState();
    
    if (widget.players.isNotEmpty && widget.players.first == widget.playerName) {
      amIHost = true;
    }

    _listenForVotingTrigger();
  }

  void _listenForVotingTrigger() {
    if (widget.socket != null) {
      widget.socket.on('navigate_to_voting', (_) {
        if (!mounted) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VotingScreen(
              socket: widget.socket,
              roomCode: widget.roomCode,
              myName: widget.playerName,
              players: widget.players,
              amIImpostor: widget.isImpostor,
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    if (widget.socket != null) {
      widget.socket.off('navigate_to_voting');
    }
    super.dispose();
  }

  void _triggerVotingOnServer() {
    if (widget.socket != null) {
      widget.socket.emit('start_voting', {
        'roomCode': widget.roomCode,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B1A),
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hoş geldin, ${widget.playerName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isImpostor
                      ? 'DİKKAT KİMSEYE BELLİ ETME!'
                      : 'Kelimeyi arkadaşlarına anlatmaya hazır ol!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.isImpostor
                        ? Colors.redAccent
                        : const Color(0xFF8E8EAF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),

                // GİZLİ KELİME KARTI
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isWordVisible = !_isWordVisible;
                    });
                  },
                  child: Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: const Color(0xFF181832).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isWordVisible
                            ? (widget.isImpostor
                                  ? Colors.redAccent
                                  : const Color(0xFF00D2FF))
                            : const Color(0xFF2E2E5C),
                        width: 2,
                      ),
                      boxShadow: _isWordVisible
                          ? [
                              BoxShadow(
                                color: widget.isImpostor
                                    ? Colors.redAccent.withValues(alpha: 0.3)
                                    : const Color(0xFF00D2FF).withValues(alpha: 0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isWordVisible) ...[
                          const Icon(
                            Icons.lock_rounded,
                            color: Color(0xFF8E8EAF),
                            size: 50,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'KELİMENİ GÖRMEK İÇİN TIKLA',
                            style: TextStyle(
                              color: Color(0xFF8E8EAF),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ] else ...[
                          Text(
                            widget.isImpostor ? 'ROLÜN' : 'GİZLİ KELİMEN',
                            style: TextStyle(
                              color: widget.isImpostor
                                  ? Colors.redAccent
                                  : const Color(0xFF8E8EAF),
                              fontSize: 13,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.isImpostor ? 'IMPOSTER' : widget.secretWord,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.isImpostor
                                  ? Colors.redAccent
                                  : const Color(0xFF00D2FF),
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: widget.isImpostor ? 3 : 1,
                            ),
                          ),
                          
                          // 🎯 GÜNCELLEME: Eğer İmpostor ise ve elinde bir yakın kelime varsa (Klasik modda 'Kelime Yok' veya boş gelebilir) bunu kartın altına şıkça yazıyoruz!
                          if (widget.isImpostor && widget.secretWord.isNotEmpty && widget.secretWord != 'Kelime Yok') ...[
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Yakın Kelimen: ${widget.secretWord}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E2E5C),
                          side: const BorderSide(
                            color: Color(0xFF00D2FF),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'LOBİYE DÖN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (amIHost) ...[
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _triggerVotingOnServer(); 
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E2E5C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(
                              color: Colors.redAccent,
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'OYLAMAYA GİT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}