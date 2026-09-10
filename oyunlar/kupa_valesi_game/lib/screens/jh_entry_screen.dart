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
  bool _moving = false;
  String _inspectionMode = 'free';

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
      newGender: _socket.gender ?? 'male',
    );
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const JhLobbyScreen()));
  }

  String _modeLabel(String mode) => switch (mode) {
    'single' => 'Tek inceleme',
    'random' => 'Rastgele inceleme',
    _ => 'Serbest inceleme',
  };

  void _showHowToPlay() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF352B26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x99E7C98A)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const JhSymbolMark(size: 52),
                const SizedBox(height: 12),
                const Text(
                  'NASIL OYNANIR?',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Amaç, diğer oyunculardan gelen ipuçlarını kullanarak göremediğin kendi sembolünü doğru tahmin etmek ve son oyuncu olarak oyunda kalmaktır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 16),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SymbolLegend(
                      symbol: '☀',
                      name: 'Güneş',
                      color: Color(0xFFE7C98A),
                    ),
                    _SymbolLegend(
                      symbol: '☾',
                      name: 'Ay',
                      color: Color(0xFF9CAF96),
                    ),
                    _SymbolLegend(
                      symbol: '★',
                      name: 'Yıldız',
                      color: Color(0xFFD9826B),
                    ),
                    _SymbolLegend(
                      symbol: '☁',
                      name: 'Bulut',
                      color: Color(0xFFF4EBDD),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _RuleRow(
                  number: '1',
                  text:
                      'Oyun başladığında herkese benzersiz bir numara ile Güneş, Ay, Yıldız veya Bulut sembollerinden biri verilir. Kendi numaranı görürsün ancak kendi sembolünü göremezsin.',
                ),
                const _RuleRow(
                  number: '2',
                  text:
                      'İpucu Zamanı bölümünde masadaki başka bir numarayı seçerek o oyuncunun sembolünü inceleyebilirsin. İnceleme hakkı, oda kurulurken seçilen oyun ayarına göre değişir.',
                ),
                const _RuleRow(
                  number: '3',
                  text:
                      'Oyuncular gördükleri sembolleri birbirleriyle paylaşır. Verilen bilgilerin doğru olup olmadığına karar vererek kendi sembolünü tahmin etmeye çalışırsın.',
                ),
                const _RuleRow(
                  number: '4',
                  text:
                      'Herkes hazır olduğunda Gizli Oda açılır. Dört sembolden birinin kapısını açarak tahminini seçer ve süre dolmadan kilitlersin.',
                ),
                const _RuleRow(
                  number: '5',
                  text:
                      'Doğru tahmin yapanlar sonraki tura geçer. Yanlış tahmin yapan veya süresinde sembolünü kilitlemeyen oyuncu elenir.',
                ),
                const _RuleRow(
                  number: '6',
                  text:
                      'Her yeni turda numaralar ve semboller yeniden dağıtılır. Oyunda kalan son oyuncu Sembol Avı’nı kazanır.',
                ),
                const SizedBox(height: 10),
                JhButton(
                  label: 'ANLADIM',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                  color: const Color(0xFF9CAF96),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        'gender': 'male',
        'inspectionMode': _inspectionMode,
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
      'gender': 'male',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.small(
        onPressed: _showHowToPlay,
        tooltip: 'Nasıl oynanır?',
        elevation: 5,
        backgroundColor: const Color(0xFF49372F),
        foregroundColor: const Color(0xFFE7C98A),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFFE7C98A), width: 1.5),
        ),
        child: const Icon(Icons.info_outline_rounded),
      ),
      body: JhBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: JhPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const JhSymbolMark(size: 72),
                      const SizedBox(height: 12),
                      const Text(
                        'SEMBOL AVI',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '\u0130pu\u00E7lar\u0131 de\u011Ferlendir, gizli sembol\u00FCn\u00FC bul.',
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
                      if (_creating) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          collapsedIconColor: const Color(0xFF9CAF96),
                          iconColor: const Color(0xFF9CAF96),
                          title: const Text(
                            'OYUN AYARLARI',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          subtitle: Text(
                            _modeLabel(_inspectionMode),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ['free', 'single', 'random']
                                    .map(
                                      (mode) => ChoiceChip(
                                        label: Text(_modeLabel(mode)),
                                        selected: _inspectionMode == mode,
                                        onSelected: (_) => setState(
                                          () => _inspectionMode = mode,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 26),
                      JhButton(
                        label: _creating ? 'ODA KUR' : 'ODAYA KATIL',
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

class _SymbolLegend extends StatelessWidget {
  const _SymbolLegend({
    required this.symbol,
    required this.name,
    required this.color,
  });

  final String symbol;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF49372F),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(symbol, style: TextStyle(color: color, fontSize: 27, height: 1)),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF49372F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33E7C98A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFD9826B),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF211B18),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
