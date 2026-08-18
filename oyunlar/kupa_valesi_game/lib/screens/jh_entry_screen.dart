import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/jh_socket_service.dart';
import '../widgets/jh_ui.dart';
import 'jh_lobby_screen.dart';

class JhEntryScreen extends StatefulWidget {
  const JhEntryScreen({super.key});

  @override
  State<JhEntryScreen> createState() => _JhEntryScreenState();
}

class _JhEntryScreenState extends State<JhEntryScreen> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();
  final _socket = JhSocketService.instance;
  bool _creating = true;
  bool _female = false;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _socket.socket?.on('jh_room_created', _onRoomCreated);
    _socket.socket?.on('jh_room_joined', _onRoomJoined);
    _socket.socket?.on('jh_error', _onError);
  }

  @override
  void dispose() {
    _socket.socket?.off('jh_room_created', _onRoomCreated);
    _socket.socket?.off('jh_room_joined', _onRoomJoined);
    _socket.socket?.off('jh_error', _onError);
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  String get _gender => _female ? 'female' : 'male';

  String _newRoomCode() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  void _onRoomCreated(dynamic data) {
    if (data is! Map) return;
    _enterLobby(
      (data['roomCode'] ?? '').toString(),
      _nameController.text.trim(),
    );
  }

  void _onRoomJoined(dynamic data) {
    if (data is! Map) return;
    _enterLobby(
      (data['roomCode'] ?? '').toString(),
      (data['playerName'] ?? _nameController.text).toString(),
    );
  }

  void _onError(dynamic data) {
    final message = data is Map ? data['message']?.toString() : null;
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Bağlantı hatası oluştu.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _enterLobby(String roomCode, String playerName) async {
    if (!mounted || _moving || roomCode.isEmpty) return;
    _moving = true;
    await _socket.setSession(
      newRoomCode: roomCode,
      newPlayerName: playerName.trim(),
      newGender: _socket.gender ?? _gender,
    );
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const JhLobbyScreen()));
  }

  void _continue() {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _onError({'message': 'Lütfen en az 2 karakterlik bir isim girin.'});
      return;
    }
    if (_creating) {
      _socket.socket?.emit('jh_create_room', {
        'roomCode': _newRoomCode(),
        'playerName': name,
        'gender': _gender,
      });
      return;
    }
    final roomCode = _roomController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(roomCode)) {
      _onError({'message': '6 haneli sayı olan oda kodunu girin.'});
      return;
    }
    _socket.socket?.emit('jh_join_room', {
      'roomCode': roomCode,
      'playerName': name,
      'gender': _gender,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: JhBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: JhPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF426E),
                        size: 58,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'KUPA VALES\u0130',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ensendeki sembol\u00FC \u00F6\u011Fren. Kime g\u00FCvenece\u011Fine karar ver.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 28),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('ODA KUR'),
                            icon: Icon(Icons.add_home_rounded),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('ODAYA KATIL'),
                            icon: Icon(Icons.login_rounded),
                          ),
                        ],
                        selected: {_creating},
                        onSelectionChanged: (value) =>
                            setState(() => _creating = value.first),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _nameController,
                        maxLength: 24,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Oyuncu ad\u0131',
                          prefixIcon: Icon(Icons.person_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (!_creating) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _roomController,
                          maxLength: 6,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: '6 haneli oda kodu',
                            prefixIcon: Icon(Icons.vpn_key_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Avatar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('ERKEK'),
                              avatar: const Icon(Icons.person, size: 18),
                              selected: !_female,
                              onSelected: (_) =>
                                  setState(() => _female = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('KADIN'),
                              avatar: const Icon(Icons.person_2, size: 18),
                              selected: _female,
                              onSelected: (_) => setState(() => _female = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      JhButton(
                        label: _creating
                            ? 'ODA OLU\u015ETUR'
                            : 'LOB\u0130YE KATIL',
                        icon: _creating
                            ? Icons.meeting_room_rounded
                            : Icons.arrow_forward_rounded,
                        onPressed: _continue,
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
