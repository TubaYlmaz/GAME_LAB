// ignore_for_file: unnecessary_brace_in_string_interps, prefer_interpolation_to_compose_strings
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/jh_socket_service.dart';
import '../widgets/jh_ui.dart';
import 'jh_guess_dialog.dart';
import 'jh_lobby_screen.dart';

class JhGameScreen extends StatefulWidget {
  const JhGameScreen({super.key, this.expectedMatchId});

  final String? expectedMatchId;

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
  int _resultEndsAt = 0;
  int _readyCount = 0;
  int _lockedCount = 0;
  int _totalAlive = 0;
  List<String> _readyPlayers = [];
  List<String> _lockedPlayers = [];
  String? _matchId;
  bool _guessDialogOpen = false;
  int _guessDialogCellEndsAt = 0;
  int _serverTimeOffsetMs = 0;
  bool _resultDialogOpen = false;
  bool _gameOverDialogOpen = false;
  bool _returning = false;
  int _myNumber = 0;
  String _inspectionMode = 'free';
  List<int> _visibleNumbers = [];
  List<Map<String, dynamic>> _inspectionNotes = [];
  int? _openedNumber;

  String get _roomCode => _socket.roomCode ?? '';
  String get _myName => _socket.playerName ?? '';

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _socket.socket?.on('jh_game_state', _onGameState);
    _socket.socket?.on('jh_phase_changed', _onPhaseChanged);
    _socket.socket?.on('jh_inspection_result', _onInspectionResult);
    _socket.socket?.on('jh_ready_status', _onReadyStatus);
    _socket.socket?.on('jh_guess_status', _onGuessStatus);
    _socket.socket?.on('jh_round_result', _onRoundResult);
    _socket.socket?.on('jh_game_over', _onGameOver);
    _socket.socket?.on('jh_lobby_returned', _onLobbyReturned);
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
    _socket.socket?.off('jh_inspection_result', _onInspectionResult);
    _socket.socket?.off('jh_guess_status', _onGuessStatus);
    _socket.socket?.off('jh_round_result', _onRoundResult);
    _socket.socket?.off('jh_game_over', _onGameOver);
    _socket.socket?.off('jh_lobby_returned', _onLobbyReturned);
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

  bool get _amAlive => _me?['isAlive'] == true;

  bool get _shouldShowGuessDialog =>
      _phase == 'cell' && _amAlive && _cellEndsAt > _serverNow;

  bool get _amReady =>
      _readyPlayers.any((name) => name.toLowerCase() == _myName.toLowerCase());

  bool get _amLocked =>
      _lockedPlayers.any((name) => name.toLowerCase() == _myName.toLowerCase());

  int get _activeDeadline {
    if (_phase == 'cell') return _cellEndsAt;
    if (_phase == 'result') return _resultEndsAt;
    return _discussionEndsAt;
  }

  int get _serverNow =>
      DateTime.now().millisecondsSinceEpoch + _serverTimeOffsetMs;

  int _serverOffset(dynamic data) {
    if (data is! Map) return _serverTimeOffsetMs;
    final serverNow = _number(data['serverNow']);
    return serverNow > 0
        ? serverNow - DateTime.now().millisecondsSinceEpoch
        : _serverTimeOffsetMs;
  }

  bool _isCurrentMatch(dynamic data) {
    if (data is! Map) return false;
    final eventMatchId = data['matchId']?.toString();
    final expectedMatchId = widget.expectedMatchId ?? _matchId;
    if (expectedMatchId != null) return eventMatchId == expectedMatchId;
    return _matchId == null || eventMatchId == null || eventMatchId == _matchId;
  }

  void _rememberMatch(dynamic data) {
    final eventMatchId = data is Map ? data['matchId']?.toString() : null;
    if (eventMatchId != null && eventMatchId.isNotEmpty) {
      _matchId = eventMatchId;
    }
  }

  void _onGameState(dynamic data) {
    if (!mounted || data is! Map) return;
    if (!_isCurrentMatch(data)) return;
    _rememberMatch(data);
    final rawPlayers = data['players'];
    setState(() {
      _serverTimeOffsetMs = _serverOffset(data);
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
      _resultEndsAt = _number(data['resultEndsAt']);
      _readyCount = _number(data['readyCount']);
      _lockedCount = _number(data['lockedCount']);
      _totalAlive = _number(data['totalAlive']);
      _myNumber = _number(data['myNumber']);
      _inspectionMode = data['inspectionMode']?.toString() ?? _inspectionMode;
      _visibleNumbers = data['visibleNumbers'] is List
          ? (data['visibleNumbers'] as List)
                .map(_number)
                .where((number) => number > 0)
                .toList()
          : [];
      _inspectionNotes = data['inspectionNotes'] is List
          ? (data['inspectionNotes'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : [];
      if (_openedNumber != null &&
          !_inspectionNotes.any(
            (note) => _number(note['number']) == _openedNumber,
          )) {
        _openedNumber = null;
      }
      _readyPlayers = data['readyPlayers'] is List
          ? (data['readyPlayers'] as List)
                .map((item) => item.toString())
                .toList()
          : [];
      _lockedPlayers = data['lockedPlayers'] is List
          ? (data['lockedPlayers'] as List)
                .map((item) => item.toString())
                .toList()
          : [];
    });
    _scheduleGuessDialogSync();
    if (data['status']?.toString() == 'finished' || _phase == 'game_over') {
      _showGameOver(data);
    }
  }

  void _onInspectionResult(dynamic data) {
    if (!mounted || data is! Map || !_isCurrentMatch(data)) return;
    final number = _number(data['number']);
    final symbol = data['symbol']?.toString();
    if (number <= 0 || symbol == null || symbol.isEmpty) return;
    setState(() {
      if (!_inspectionNotes.any((note) => _number(note['number']) == number)) {
        _inspectionNotes.add({'number': number, 'symbol': symbol});
      }
    });
    _showInspectionCard(number);
  }

  Map<String, dynamic>? _inspectionFor(int number) {
    for (final item in _inspectionNotes) {
      if (_number(item['number']) == number) return item;
    }
    return null;
  }

  void _showInspectionCard(int number) {
    if (_inspectionFor(number) == null) return;
    setState(() => _openedNumber = number);
  }

  Widget _numberCard(int number) {
    final note = _inspectionFor(number);
    final known = note != null;
    final revealed = _openedNumber == number;
    final canInspect =
        _amAlive &&
        _phase == 'discussion' &&
        _inspectionMode != 'random' &&
        !(_inspectionMode == 'single' && _inspectionNotes.isNotEmpty && !known);
    final action = known
        ? () => setState(() => _openedNumber = revealed ? null : number)
        : (canInspect ? () => _inspectNumber(number) : null);
    final borderColor = revealed
        ? const Color(0xFFFFD166)
        : known
        ? const Color(0xFF77E6FF)
        : const Color(0x66FFFFFF);

    return InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: action == null ? .4 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: revealed ? const Color(0xFF302037) : const Color(0xFF181A2C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: revealed ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NUMARA',
                style: TextStyle(
                  color: known ? const Color(0xFFFFD166) : Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$number',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Spacer(),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    revealed ? note!['symbol'].toString() : '?',
                    key: ValueKey('$number-$revealed'),
                    style: TextStyle(
                      color: revealed
                          ? const Color(0xFFFFD166)
                          : const Color(0xFFFFFFFF),
                      fontSize: 54,
                      height: .9,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    revealed
                        ? Icons.visibility_off_rounded
                        : known
                        ? Icons.visibility_rounded
                        : Icons.touch_app_rounded,
                    size: 15,
                    color: known ? const Color(0xFFFFD166) : Colors.white60,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    revealed
                        ? 'GİZLE'
                        : known
                        ? 'TEKRAR AÇ'
                        : 'İNCELE',
                    style: TextStyle(
                      color: known ? const Color(0xFFFFD166) : Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .45,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _myNumberHeader() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: const Color(0xFF302037),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFFF426E)),
    ),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFFF426E),
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SENİN NUMARAN',
              style: TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _myNumber == 0 ? '?' : '$_myNumber',
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const Spacer(),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'SEMBOLÜN',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'GİZLİ',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _gameSurface() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _myNumberHeader(),
        const SizedBox(height: 26),
        const Text(
          'MASADAKİ NUMARALAR',
          style: TextStyle(
            color: Color(0xFF77E6FF),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bir numarayı seçerek sembolünü incele.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            itemCount: _visibleNumbers.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 156,
              mainAxisExtent: 184,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, index) => _numberCard(_visibleNumbers[index]),
          ),
        ),
        if (!_amAlive)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text(
                'İZLEYİCİ MODUNDASIN',
                style: TextStyle(
                  color: Color(0xFFFF8AA1),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    ),
  );
  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  void _onPhaseChanged(dynamic data) {
    if (!mounted || data is! Map) return;
    if (!_isCurrentMatch(data)) return;
    _rememberMatch(data);
    final phase = data['phase']?.toString();
    if (phase == null) return;
    setState(() {
      _serverTimeOffsetMs = _serverOffset(data);
      _phase = phase;
      if (data['discussionEndsAt'] != null) {
        _discussionEndsAt = _number(data['discussionEndsAt']);
      }
      if (data['cellEndsAt'] != null) {
        _cellEndsAt = _number(data['cellEndsAt']);
      }
      if (phase != 'discussion') _readyPlayers = [];
      if (phase != 'cell') _lockedPlayers = [];
      if (phase != 'result') _resultEndsAt = 0;
    });
    _scheduleGuessDialogSync();
  }

  void _onReadyStatus(dynamic data) {
    if (!mounted || data is! Map) return;
    if (!_isCurrentMatch(data)) return;
    _rememberMatch(data);
    setState(() {
      _serverTimeOffsetMs = _serverOffset(data);
      _readyCount = _number(data['readyCount']);
      _totalAlive = _number(data['totalAlive']);
      _readyPlayers = data['readyPlayers'] is List
          ? (data['readyPlayers'] as List)
                .map((item) => item.toString())
                .toList()
          : _readyPlayers;
    });
  }

  void _onGuessStatus(dynamic data) {
    if (!mounted || data is! Map) return;
    if (!_isCurrentMatch(data)) return;
    _rememberMatch(data);
    setState(() {
      _serverTimeOffsetMs = _serverOffset(data);
      _lockedCount = _number(data['lockedCount']);
      _totalAlive = _number(data['totalAlive']);
      _lockedPlayers = data['lockedPlayers'] is List
          ? (data['lockedPlayers'] as List)
                .map((item) => item.toString())
                .toList()
          : _lockedPlayers;
    });
  }

  void _scheduleGuessDialogSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncGuessDialog());
    });
  }

  Future<void> _syncGuessDialog() async {
    if (!mounted) return;
    if (_phase != 'result' && _resultDialogOpen) {
      _resultDialogOpen = false;
      await Navigator.of(context, rootNavigator: true).maybePop();
    }
    if (!mounted) return;
    final staleDialog =
        _guessDialogOpen &&
        (!_shouldShowGuessDialog || _guessDialogCellEndsAt != _cellEndsAt);
    if (staleDialog) await _dismissGuessDialog();
    if (!mounted || !_shouldShowGuessDialog || _guessDialogOpen) return;
    _showGuessDialog();
  }

  void _showGuessDialog() {
    if (!mounted || _guessDialogOpen || !_shouldShowGuessDialog) return;
    final dialogCellEndsAt = _cellEndsAt;
    _guessDialogOpen = true;
    _guessDialogCellEndsAt = dialogCellEndsAt;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => JhGuessDialog(
        roomCode: _roomCode,
        playerName: _myName,
        cellEndsAt: dialogCellEndsAt,
        serverTimeOffsetMs: _serverTimeOffsetMs,
        initiallyLocked: _amLocked,
      ),
    ).whenComplete(() {
      _guessDialogOpen = false;
      _guessDialogCellEndsAt = 0;
      _scheduleGuessDialogSync();
    });
  }

  Future<void> _dismissGuessDialog() async {
    if (!_guessDialogOpen) return;
    _guessDialogOpen = false;
    _guessDialogCellEndsAt = 0;
    await Navigator.of(context, rootNavigator: true).maybePop();
  }

  void _dismissTransientDialog() {
    if (_resultDialogOpen) {
      _resultDialogOpen = false;
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }
    if (_guessDialogOpen) unawaited(_dismissGuessDialog());
  }

  void _onRoundResult(dynamic data) {
    if (!mounted || data is! Map || _gameOverDialogOpen) return;
    if (!_isCurrentMatch(data)) return;
    _rememberMatch(data);
    setState(() => _resultEndsAt = _number(data['resultEndsAt']));
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
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1729), Color(0xFF131522)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0x99FFD166)),
              boxShadow: const [
                BoxShadow(color: Color(0xAA000000), blurRadius: 28),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x44FFD166), Color(0x11FFD166)],
                    ),
                  ),
                  child: const Row(
                    children: [
                      _ResultSeal(),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TUR TAMAMLANDI',
                              style: TextStyle(
                                color: Color(0xFFFFD166),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'KARAR AÇIKLANDI',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: eliminated.isEmpty
                      ? const Column(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF4DE4B5),
                              size: 44,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Herkes doğru tahmin etti.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Yeni tur için semboller yeniden dağıtılıyor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        )
                      : Column(
                          children: eliminated.map((player) {
                            final afk = player['reason'] == 'afk';
                            final reason = afk
                                ? 'Sembolünü kilitlemedi'
                                : 'Yanlış sembolü seçti';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x33101524),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: const Color(0x55FF426E),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: Color(0x33FF426E),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_off_rounded,
                                      color: Color(0xFFFF8AA1),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          player['name']?.toString() ??
                                              'Oyuncu',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          reason,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFFFF426E),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: const Color(0x22000000),
                  child: const Text(
                    'YENİ TUR HAZIRLANIYOR...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      _resultDialogOpen = false;
      _scheduleGuessDialogSync();
    });
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && _resultDialogOpen) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });
  }

  void _onGameOver(dynamic data) {
    if (data is Map && _isCurrentMatch(data)) {
      _rememberMatch(data);
      _showGameOver(data);
    }
  }

  void _showGameOver(Map<dynamic, dynamic> data) {
    if (!mounted || _gameOverDialogOpen) return;
    _dismissTransientDialog();
    _gameOverDialogOpen = true;
    final winner = (data['winner'] ?? data['gameWinner'])?.toString() ?? 'NONE';
    final winnerName = data['winnerName']?.toString().trim() ?? '';
    final winnerNumber = _number(data['winnerNumber']);
    final hasPlayerWinner = winner == 'PLAYER' && winnerName.isNotEmpty;
    final playerPrefix = winnerNumber > 0
        ? '$winnerNumber numaralı oyuncu '
        : '';
    final title = hasPlayerWinner ? 'OYUN BİTTİ' : 'KAZANAN YOK';
    final detail = hasPlayerWinner
        ? '$playerPrefix$winnerName oyunu kazandı.'
        : 'Son turda herkes elendi. Kazanan yok.';
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1B1C2F),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(detail),
          actions: [
            JhButton(
              label: 'LOB\u0130YE D\u00D6N',
              icon: Icons.home_rounded,
              onPressed: () {
                if (_returning) return;
                _returning = true;
                _socket.socket?.emit('jh_return_to_lobby', {
                  'roomCode': _roomCode,
                });
                Future<void>.delayed(const Duration(milliseconds: 600), () {
                  if (mounted && _returning) _goToLobby();
                });
              },
            ),
          ],
        ),
      );
    });
  }

  void _onLobbyReturned(dynamic data) {
    if (!mounted) return;
    _goToLobby();
  }

  void _goToLobby() {
    _returning = false;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JhLobbyScreen()),
      (_) => false,
    );
  }

  void _onError(dynamic data) {
    if (!mounted) return;
    _returning = false;
    final message = data is Map ? data['message']?.toString() : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'Bir hata olu\u015ftu.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _readyForCell() {
    _socket.socket?.emit('jh_ready_for_cell', {'roomCode': _roomCode});
  }

  void _inspectNumber(int number) {
    _socket.socket?.emit('jh_inspect_number', {
      'roomCode': _roomCode,
      'targetNumber': number,
    });
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
    if (_phase == 'cell') {
      return 'Ekran karard\u0131. Sembol\u00FCn\u00FC se\u00E7 ve kilitle.';
    }
    if (_phase == 'result') {
      return 'Yeni semboller da\u011F\u0131t\u0131l\u0131yor...';
    }
    return 'Y\u00FCz y\u00FCze konu\u015Fun; ensendeki sembol\u00FC \u00F6\u011Frenmeye \u00E7al\u0131\u015F\u0131n.';
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF426E),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _phaseTitle(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              _phaseHint(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_activeDeadline > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            remainingText(
                              _activeDeadline,
                              nowMilliseconds: _serverNow,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF77E6FF),
                              fontSize: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _gameSurface()),
                const SizedBox(height: 10),
                JhPanel(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    children: [
                      if (_phase == 'cell')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Text(
                            'Kilitlenen tahmin: ' +
                                _lockedCount.toString() +
                                ' / ' +
                                _totalAlive.toString(),
                            style: const TextStyle(
                              color: Color(0xFF77E6FF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      JhButton(
                        label: buttonLabel,
                        icon: _amReady
                            ? Icons.check_circle_rounded
                            : Icons.lock_open_rounded,
                        enabled:
                            _phase == 'discussion' && _amAlive && !_amReady,
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

class _ResultSeal extends StatelessWidget {
  const _ResultSeal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0x33FFD166),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.gavel_rounded,
        color: Color(0xFFFFD166),
        size: 25,
      ),
    );
  }
}
