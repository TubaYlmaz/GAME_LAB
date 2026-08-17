import 'package:flutter/material.dart';

import '../services/jh_socket_service.dart';
import '../widgets/jh_ui.dart';
import 'jh_game_screen.dart';

class JhLobbyScreen extends StatefulWidget {
  const JhLobbyScreen({super.key});

  @override
  State<JhLobbyScreen> createState() => _JhLobbyScreenState();
}

class _JhLobbyScreenState extends State<JhLobbyScreen> {
  final _socket = JhSocketService.instance;
  List<Map<String, dynamic>> _players = [];
  bool _starting = false;
  bool _moving = false;

  String get _myName => _socket.playerName ?? '';
  String get _roomCode => _socket.roomCode ?? '';

  bool get _isHost => _players.any(
        (player) =>
            player['isHost'] == true &&
            player['name']?.toString().toLowerCase() == _myName.toLowerCase(),
      );

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _socket.socket?.on('jh_room_updated', _onRoomUpdated);
    _socket.socket?.on('jh_game_started', _onGameStarted);
    _socket.socket?.on('jh_game_state', _onGameState);
    _socket.socket?.on('jh_error', _onError);
    _socket.socket?.emit('jh_get_state', {'roomCode': _roomCode});
  }

  @override
  void dispose() {
    _socket.socket?.off('jh_room_updated', _onRoomUpdated);
    _socket.socket?.off('jh_game_started', _onGameStarted);
    _socket.socket?.off('jh_game_state', _onGameState);
    _socket.socket?.off('jh_error', _onError);
    super.dispose();
  }

  void _onRoomUpdated(dynamic data) {
    if (!mounted || data is! Map) return;
    final raw = data['players'];
    setState(() {
      _players = raw is List
          ? raw.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : [];
    });
  }

  void _onGameState(dynamic data) {
    if (data is! Map || data['status']?.toString() != 'started') return;
    _goToGame();
  }

  void _onGameStarted(dynamic _) => _goToGame();

  void _goToGame() {
    if (!mounted || _moving) return;
    _moving = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const JhGameScreen()),
    );
  }

  void _onError(dynamic data) {
    if (!mounted) return;
    final message = data is Map ? data['message']?.toString() : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Bir hata olu\u015ftu.'), backgroundColor: Colors.redAccent),
    );
    setState(() => _starting = false);
  }

  void _startGame() {
    setState(() => _starting = true);
    _socket.socket?.emit('jh_start_game', {'roomCode': _roomCode});
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _isHost && _players.length >= 2 && !_starting;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: JhBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: JhPanel(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: Color(0xFFFF426E), size: 32),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'KUPA VALES\u0130 LOB\u0130S\u0130',
                              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0x22FFFFFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x44FFFFFF)),
                            ),
                            child: Text(_roomCode, style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Oda kodunu arkada\u015flar\u0131nla payla\u015f. Oyun ba\u015flad\u0131ktan sonra yeni oyuncu giremez.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(height: 300,
                        child: ListView.separated(
                          itemCount: _players.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final player = _players[index];
                            final female = player['gender'] == 'female';
                            final host = player['isHost'] == true;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0x55101524),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: host ? const Color(0x66FF426E) : const Color(0x33FFFFFF)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: female ? const Color(0xFF7654D9) : const Color(0xFF1679B9),
                                    child: Icon(female ? Icons.person_2 : Icons.person, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      player['name']?.toString() ?? 'Oyuncu',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  if (host)
                                    const Chip(
                                      label: Text('KURUCU'),
                                      avatar: Icon(Icons.star_rounded, size: 16),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_isHost && _players.length < 2)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text('Ba\u015flamak i\u00E7in en az 2 oyuncu gerekir.', style: TextStyle(color: Color(0xFFFFD166))),
                        ),
                      JhButton(
                        label: _isHost ? 'OYUNU BA\u015ELAT' : 'KURUCU OYUNU BA\u015ELATACAK',
                        icon: Icons.play_arrow_rounded,
                        enabled: canStart,
                        onPressed: _startGame,
                        color: const Color(0xFF13B98B),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
