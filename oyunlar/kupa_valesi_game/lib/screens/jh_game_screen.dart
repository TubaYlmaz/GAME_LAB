// ignore_for_file: unnecessary_brace_in_string_interps, prefer_interpolation_to_compose_strings
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/jh_socket_service.dart';
import '../widgets/jh_ui.dart';
import 'jh_guess_dialog.dart';
import 'jh_lobby_screen.dart';

class JhGameScreen extends StatefulWidget {
  const JhGameScreen({super.key});

  @override
  State<JhGameScreen> createState() => _JhGameScreenState();
}

class _JhGameScreenState extends State<JhGameScreen> {
  final _socket = JhSocketService.instance;
  final List<Map<String, dynamic>> _players = [];
  Timer? _ticker;
  String _phase = 'discussion';
  int _discussionEndsAt = 0;
  int _cellEndsAt = 0;
  int _readyCount = 0;
  int _lockedCount = 0;
  int _totalAlive = 0;
  List<String> _readyPlayers = [];
  bool _guessDialogOpen = false;
  bool _resultDialogOpen = false;
  bool _gameOverDialogOpen = false;
  bool _returning = false;

  String get _roomCode => _socket.roomCode ?? '';
  String get _myName => _socket.playerName ?? '';

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _socket.socket?.on('jh_game_state', _onGameState);
    _socket.socket?.on('jh_phase_changed', _onPhaseChanged);
    _socket.socket?.on('jh_ready_status', _onReadyStatus);
    _socket.socket?.on('jh_guess_status', _onGuessStatus);
    _socket.socket?.on('jh_round_result', _onRoundResult);
    _socket.socket?.on('jh_game_over', _onGameOver);
    _socket.socket?.on('jh_lobby_reset', _onLobbyReset);
    _socket.socket?.on('jh_error', _onError);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _socket.socket?.emit('jh_get_state', {'roomCode': _roomCode});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _socket.socket?.off('jh_game_state', _onGameState);
    _socket.socket?.off('jh_phase_changed', _onPhaseChanged);
    _socket.socket?.off('jh_ready_status', _onReadyStatus);
    _socket.socket?.off('jh_guess_status', _onGuessStatus);
    _socket.socket?.off('jh_round_result', _onRoundResult);
    _socket.socket?.off('jh_game_over', _onGameOver);
    _socket.socket?.off('jh_lobby_reset', _onLobbyReset);
    _socket.socket?.off('jh_error', _onError);
    super.dispose();
  }

  Map<String, dynamic>? get _me {
    for (final player in _players) {
      if (player['name']?.toString().toLowerCase() == _myName.toLowerCase()) {
        return player;
      }
    }
    return null;
  }

  bool get _amAlive => _me?['isAlive'] != false;

  bool get _amReady => _readyPlayers.any(
        (name) => name.toLowerCase() == _myName.toLowerCase(),
      );

  int get _activeDeadline => _phase == 'cell' ? _cellEndsAt : _discussionEndsAt;

  void _onGameState(dynamic data) {
    if (!mounted || data is! Map) return;
    final rawPlayers = data['players'];
    setState(() {
      _players
        ..clear()
        ..addAll(
          rawPlayers is List
              ? rawPlayers.map((item) => Map<String, dynamic>.from(item as Map))
              : const <Map<String, dynamic>>[],
        );
      _phase = data['phase']?.toString() ?? _phase;
      _discussionEndsAt = _number(data['discussionEndsAt']);
      _cellEndsAt = _number(data['cellEndsAt']);
      _readyCount = _number(data['readyCount']);
      _lockedCount = _number(data['lockedCount']);
      _totalAlive = _number(data['totalAlive']);
      _readyPlayers = data['readyPlayers'] is List
          ? (data['readyPlayers'] as List).map((item) => item.toString()).toList()
          : [];
    });
    if (_phase == 'cell' && _amAlive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showGuessDialog());
    }
  }

  int _number(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  void _onPhaseChanged(dynamic data) {
    if (!mounted || data is! Map) return;
    final phase = data['phase']?.toString();
    if (phase == null) return;
    setState(() {
      _phase = phase;
      if (data['discussionEndsAt'] != null) {
        _discussionEndsAt = _number(data['discussionEndsAt']);
      }
      if (data['cellEndsAt'] != null) {
        _cellEndsAt = _number(data['cellEndsAt']);
      }
      if (phase != 'discussion') _readyPlayers = [];
    });
    if (phase == 'cell' && _amAlive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showGuessDialog());
    }
  }

  void _onReadyStatus(dynamic data) {
    if (!mounted || data is! Map) return;
    setState(() {
      _readyCount = _number(data['readyCount']);
      _totalAlive = _number(data['totalAlive']);
      _readyPlayers = data['readyPlayers'] is List
          ? (data['readyPlayers'] as List).map((item) => item.toString()).toList()
          : _readyPlayers;
    });
  }

  void _onGuessStatus(dynamic data) {
    if (!mounted || data is! Map) return;
    setState(() {
      _lockedCount = _number(data['lockedCount']);
      _totalAlive = _number(data['totalAlive']);
    });
  }

  void _showGuessDialog() {
    if (!mounted || _guessDialogOpen || _phase != 'cell' || !_amAlive) return;
    _guessDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => JhGuessDialog(
        roomCode: _roomCode,
        playerName: _myName,
        cellEndsAt: _cellEndsAt,
      ),
    ).whenComplete(() => _guessDialogOpen = false);
  }

  void _dismissTransientDialog() {
    if (!_guessDialogOpen && !_resultDialogOpen) return;
    Navigator.of(context, rootNavigator: true).maybePop();
    _guessDialogOpen = false;
    _resultDialogOpen = false;
  }

  void _onRoundResult(dynamic data) {
    if (!mounted || data is! Map || _gameOverDialogOpen) return;
    _dismissTransientDialog();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted && !_gameOverDialogOpen) _showRoundResult(data);
    });
  }

  void _showRoundResult(Map<dynamic, dynamic> data) {
    if (_resultDialogOpen || _gameOverDialogOpen) return;
    _resultDialogOpen = true;
    final raw = data['eliminated'];
    final eliminated = raw is List
        ? raw.map((item) => Map<String, dynamic>.from(item as Map)).toList()
        : <Map<String, dynamic>>[];
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1C2F),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Color(0xFFFFD166)),
            SizedBox(width: 8),
            Text('TUR SONUCU'),
          ],
        ),
        content: eliminated.isEmpty
            ? const Text('Herkes do\u011Fru tahmin etti. Yeni tur ba\u015Fl\u0131yor.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: eliminated.map((player) {
                  final role = player['role'] == 'jack' ? 'Kupa Valesi' : 'Masum';
                  final afk = player['reason'] == 'afk';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.close_rounded, color: Color(0xFFFF426E)),
                    title: Text(player['name']?.toString() ?? 'Oyuncu'),
                    subtitle: Text(role + (afk ? ' ? Kilitlemedi' : ' ? Yanl?? tahmin')),
                  );
                }).toList(),
              ),
      ),
    ).whenComplete(() => _resultDialogOpen = false);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && _resultDialogOpen) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });
  }

  void _onGameOver(dynamic data) {
    if (!mounted || _gameOverDialogOpen || data is! Map) return;
    _dismissTransientDialog();
    _gameOverDialogOpen = true;
    final winner = data['winner']?.toString() ?? 'DRAW';
    final title = winner == 'JACK'
        ? 'KUPA VALES? KAZANDI'
        : winner == 'INNOCENTS'
            ? 'MASUMLAR KAZANDI'
            : 'HERKES KAYBETT?';
    final detail = winner == 'JACK'
        ? 'Masumlar\u0131n tamam\u0131 elendi. V\u00E2le hayatta kald\u0131.'
        : winner == 'INNOCENTS'
            ? 'Kupa Valesi elendi. Hayatta kalan masumlar kazand?.'
            : 'Kupa Valesi ve kalan masumlar ayn? turda elendi.';
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1B1C2F),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text(detail),
          actions: [
            JhButton(
              label: 'LOB\u0130YE D\u00D6N',
              icon: Icons.home_rounded,
              onPressed: () {
                _returning = true;
                _socket.socket?.emit('jh_return_to_lobby', {'roomCode': _roomCode});
              },
            ),
          ],
        ),
      );
    });
  }

  void _onLobbyReset(dynamic _) {
    if (!mounted || _returning) {
      _returning = false;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JhLobbyScreen()),
      (_) => false,
    );
  }

  void _onError(dynamic data) {
    if (!mounted) return;
    final message = data is Map ? data['message']?.toString() : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Bir hata olu\u015ftu.'), backgroundColor: Colors.redAccent),
    );
  }

  void _readyForCell() {
    _socket.socket?.emit('jh_ready_for_cell', {'roomCode': _roomCode});
  }

  String _phaseTitle() {
    switch (_phase) {
      case 'cell':
        return 'H\u00DCCRE FAZI';
      case 'result':
        return 'YARGI';
      default:
        return 'TARTI\u015EMA FAZI';
    }
  }

  String _phaseHint() {
    if (_phase == 'cell') return 'Ekran karard\u0131. Sembol\u00FCn\u00FC se\u00E7 ve kilitle.';
    if (_phase == 'result') return 'Yeni semboller da\u011F\u0131t\u0131l\u0131yor...';
    return 'Y\u00FCz y\u00FCze konu\u015Fun; ensendeki sembol\u00FC \u00F6\u011Frenmeye \u00E7al\u0131\u015F\u0131n.';
  }

  @override
  Widget build(BuildContext context) {
    final ownRole = _me?['role']?.toString();
    final buttonLabel = _amAlive
        ? 'H\u00DCCREYE GE\u00C7MEYE HAZIRIM (${_readyCount} / ${_totalAlive})'
        : '\u0130ZLEY\u0130C\u0130 MODUNDASIN';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: JhBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                JhPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_rounded, color: Color(0xFFFF426E)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_phaseTitle(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                            Text(_phaseHint(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (_activeDeadline > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            remainingText(_activeDeadline),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF77E6FF), fontSize: 18),
                          ),
                        ),
                    ],
                  ),
                ),
                if (ownRole == 'jack')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'G\u0130ZL\u0130 ROL\u00DCN: KUPA VALES\u0130',
                      style: TextStyle(color: Color(0xFFFF426E), fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    itemCount: _players.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 190,
                      mainAxisExtent: 164,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (_, index) {
                      final player = _players[index];
                      final isMe = player['name']?.toString().toLowerCase() == _myName.toLowerCase();
                      final alive = player['isAlive'] != false;
                      final symbol = isMe ? '?' : player['symbol']?.toString();
                      final female = player['gender'] == 'female';
                      return Opacity(
                        opacity: alive ? 1 : .42,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF302037) : const Color(0xDD181A2C),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isMe ? const Color(0xFFFF426E) : const Color(0x44FFFFFF),
                              width: isMe ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: female ? const Color(0xFF7654D9) : const Color(0xFF1679B9),
                                    child: Icon(female ? Icons.person_2 : Icons.person, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      player['name']?.toString() ?? 'Oyuncu',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                alive ? (symbol ?? '?') : '?',
                                style: TextStyle(
                                  fontSize: alive ? 58 : 40,
                                  height: 1,
                                  color: alive && (symbol == '?' || symbol == '?')
                                      ? const Color(0xFFFF426E)
                                      : Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                alive
                                    ? (isMe ? 'SEN\u0130N KARTIN G\u0130ZL\u0130' : 'ENSE KARTI')
                                    : 'ELEND?',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: alive ? Colors.white60 : const Color(0xFFFF426E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                JhPanel(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    children: [
                      if (_phase == 'cell')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Text(
                            'Kilitlenen tahmin: ' + _lockedCount.toString() + ' / ' + _totalAlive.toString(),
                            style: const TextStyle(color: Color(0xFF77E6FF), fontWeight: FontWeight.bold),
                          ),
                        ),
                      JhButton(
                        label: buttonLabel,
                        icon: _amReady ? Icons.check_circle_rounded : Icons.lock_open_rounded,
                        enabled: _phase == 'discussion' && _amAlive && !_amReady,
                        onPressed: _readyForCell,
                        color: const Color(0xFF13B98B),
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
