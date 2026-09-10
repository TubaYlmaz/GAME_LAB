import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'jh_entry_screen.dart';
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
  bool _leaving = false;
  String _roomStatus = 'waiting';
  int _returnedCount = 0;
  int _totalPlayers = 0;

  List<String> _returnedPlayers = [];
  String _inspectionMode = 'free';
  String get _myName => _socket.playerName ?? '';
  String get _roomCode => _socket.roomCode ?? '';

  bool get _isHost => _players.any(
    (player) =>
        player['isHost'] == true &&
        player['name']?.toString().toLowerCase() == _myName.toLowerCase(),
  );

  bool get _hasReturnedToLobby => _returnedPlayers.any(
    (name) => name.toLowerCase() == _myName.toLowerCase(),
  );

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _socket.socket?.on('jh_room_updated', _onRoomUpdated);
    _socket.socket?.on('jh_game_started', _onGameStarted);
    _socket.socket?.on('jh_game_state', _onGameState);
    _socket.socket?.on('jh_error', _onError);
    _socket.socket?.on('jh_left_room', _onLeftRoom);
    _socket.socket?.emit('jh_get_state', {'roomCode': _roomCode});
  }

  @override
  void dispose() {
    _socket.socket?.off('jh_room_updated', _onRoomUpdated);
    _socket.socket?.off('jh_game_started', _onGameStarted);
    _socket.socket?.off('jh_game_state', _onGameState);
    _socket.socket?.off('jh_error', _onError);
    _socket.socket?.off('jh_left_room', _onLeftRoom);
    super.dispose();
  }

  void _onRoomUpdated(dynamic data) {
    if (!mounted || data is! Map) return;
    final raw = data['players'];
    setState(() {
      _roomStatus = data['status']?.toString() ?? _roomStatus;
      _inspectionMode = data['inspectionMode']?.toString() ?? _inspectionMode;
      _returnedCount = _number(data['returnedCount']);
      _totalPlayers = _number(data['totalPlayers']);
      _returnedPlayers = data['returnedPlayers'] is List
          ? (data['returnedPlayers'] as List)
                .map((item) => item.toString())
                .toList()
          : [];
      _players = raw is List
          ? raw.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : [];
    });
  }

  void _onGameState(dynamic data) {
    if (!mounted || data is! Map) return;
    final raw = data['players'];
    setState(() {
      _roomStatus = data['status']?.toString() ?? _roomStatus;
      _inspectionMode = data['inspectionMode']?.toString() ?? _inspectionMode;
      _returnedCount = _number(data['returnedCount']);
      _totalPlayers = _number(data['totalPlayers']);
      _returnedPlayers = data['returnedPlayers'] is List
          ? (data['returnedPlayers'] as List)
                .map((item) => item.toString())
                .toList()
          : [];
      if (raw is List) {
        _players = raw
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    });
    if (_roomStatus != 'started') return;
    _goToGame(_matchId(data));
  }

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  void _onGameStarted(dynamic data) => _goToGame(_matchId(data));

  String? _matchId(dynamic data) {
    if (data is! Map) return null;
    final matchId = data['matchId']?.toString();
    return matchId == null || matchId.isEmpty ? null : matchId;
  }

  void _goToGame([String? expectedMatchId]) {
    if (!mounted || _moving) return;
    _moving = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => JhGameScreen(expectedMatchId: expectedMatchId),
      ),
    );
  }

  void _onError(dynamic data) {
    if (!mounted) return;
    final message = data is Map ? data['message']?.toString() : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Bir hata olu\u015ftu.'),
        backgroundColor: Colors.redAccent,
      ),
    );
    setState(() => _starting = false);
    setState(() => _leaving = false);
  }

  void _setInspectionMode(String mode) {
    _socket.socket?.emit('jh_update_settings', {
      'roomCode': _roomCode,
      'inspectionMode': mode,
    });
  }

  String _modeLabel(String mode) => switch (mode) {
    'single' => 'Tek inceleme',
    'random' => 'Rastgele inceleme',
    _ => 'Serbest inceleme',
  };

  void _startGame() {
    setState(() => _starting = true);
    _socket.socket?.emit('jh_start_game', {'roomCode': _roomCode});
  }

  void _returnToLobby() {
    _socket.socket?.emit('jh_return_to_lobby', {'roomCode': _roomCode});
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF352B26),
        title: const Text('Odadan cikilsin mi?'),
        content: const Text(
          'Odadan cikarsan oyuncu listesinden silinirsin. Tekrar girmek icin oda kodunu kullanman gerekir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('VAZGEC'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ODADAN CIK'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _leaving = true);
    _socket.socket?.emit('jh_leave_room', {'roomCode': _roomCode});
  }

  Future<void> _copyRoomCode() async {
    await Clipboard.setData(ClipboardData(text: _roomCode));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oda kodu kopyalandı.')));
  }

  Future<void> _onLeftRoom(dynamic _) async {
    await _socket.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JhEntryScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart =
        _isHost &&
        _roomStatus == 'waiting' &&
        _players.length >= 2 &&
        !_starting;
    final lobbyHeight = (MediaQuery.sizeOf(context).height - 145)
        .clamp(560.0, 720.0)
        .toDouble();
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Odadan çık',
            child: IconButton.filled(
              onPressed: _leaving ? null : _leaveRoom,
              icon: _leaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF49372F),
                foregroundColor: const Color(0xFFE7A08D),
                side: const BorderSide(color: Color(0x99E7A08D)),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: JhBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
                // Üst sağdaki "Oyunlara dön" düğmesi için ayrı alan bırak.
                // Böylece düğme, lobi amblemi ve başlığıyla üst üste gelmez.
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: SizedBox(
                  height: lobbyHeight,
                  child: JhPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const JhSymbolMark(size: 38),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'SEMBOL AVI LOB\u0130S\u0130',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: 'Oda kodunu kopyala',
                              child: InkWell(
                                onTap: _copyRoomCode,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x22FFFFFF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0x44FFFFFF),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _roomCode,
                                        style: const TextStyle(
                                          letterSpacing: 2,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      const Icon(
                                        Icons.copy_rounded,
                                        size: 17,
                                        color: Color(0xFFE7C98A),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
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
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _isHost && _roomStatus == 'waiting'
                                  ? Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: ['free', 'single', 'random']
                                          .map(
                                            (mode) => ChoiceChip(
                                              label: Text(_modeLabel(mode)),
                                              selected: _inspectionMode == mode,
                                              onSelected: (_) =>
                                                  _setInspectionMode(mode),
                                            ),
                                          )
                                          .toList(),
                                    )
                                  : const Text(
                                      'Bu ayarı yalnızca kurucu, oyun başlamadan önce değiştirebilir.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(
                              Icons.groups_rounded,
                              color: Color(0xFF9CAF96),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'ODADAKİ OYUNCULAR',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .7,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x22789276),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0x66789276),
                                ),
                              ),
                              child: Text(
                                '${_players.length} oyuncu',
                                style: const TextStyle(
                                  color: Color(0xFFB9CCB5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _players.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final player = _players[index];
                              final host = player['isHost'] == true;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x5549372F),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: host
                                        ? const Color(0x66FF426E)
                                        : const Color(0x33FFFFFF),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              player['name']?.toString() ??
                                                  'Oyuncu',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          if (host) ...[
                                            const SizedBox(width: 9),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0x22E7A08D),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(
                                                    0x66E7A08D,
                                                  ),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.star_rounded,
                                                    size: 14,
                                                    color: Color(0xFFE7A08D),
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'KURUCU',
                                                    style: TextStyle(
                                                      color: Color(0xFFE7A08D),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x22789276),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0x66789276),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 15,
                                            color: Color(0xFFB9CCB5),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'LOBİDE',
                                            style: TextStyle(
                                              color: Color(0xFFB9CCB5),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const Spacer(),
                        if (_players.length < 2)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0x18789276),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0x44789276),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 19,
                                  color: Color(0xFFE7C98A),
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Oda hazır. Bir oyuncunun katılması bekleniyor.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFFE7C98A)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_roomStatus != 'waiting')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Yeni oyun için tüm oyuncuların lobiye dönmesi bekleniyor ($_returnedCount / $_totalPlayers).',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFE7C98A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (_roomStatus == 'finished' && !_hasReturnedToLobby)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: JhButton(
                              label: 'LOBİYE DÖN',
                              icon: Icons.home_rounded,
                              onPressed: _returnToLobby,
                              color: const Color(0xFF789276),
                            ),
                          ),
                        JhButton(
                          label: _isHost
                              ? 'OYUNU BA\u015ELAT'
                              : 'KURUCU OYUNU BA\u015ELATACAK',
                          icon: Icons.play_arrow_rounded,
                          enabled: canStart,
                          onPressed: _startGame,
                          color: const Color(0xFF789276),
                        ),
                      ],
                    ),
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
