import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';
import '../models/game_state_model.dart';
import 'sound_service.dart';

class KzSocketService extends ChangeNotifier {
  KzSocketService._();
  static final instance = KzSocketService._();

  io.Socket? _socket;
  Timer? _syncTimer;
  bool _leaving = false;
  KzGameState? state;
  String? playerId, resumeToken, roomCode, playerName;
  String? error;
  bool connected = false;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    playerId ??= prefs.getString('kz_player_id');
    resumeToken ??= prefs.getString('kz_resume_token');
    roomCode ??= prefs.getString('kz_room_code');
    playerName ??= prefs.getString('kz_player_name');
    _socket ??=
        io.io(
            AppConfig.serverUrl,
            io.OptionBuilder()
                .setTransports(['websocket', 'polling'])
                .disableAutoConnect()
                .enableReconnection()
                .build(),
          )
          ..onConnect((_) {
            connected = true;
            _syncTimer?.cancel();
            _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
              if (roomCode != null && !_leaving) {
                _socket?.emit('kz_request_state', {});
              }
            });
            notifyListeners();
            if (roomCode != null && playerId != null) {
              join(roomCode!, playerName ?? '', resume: true);
            }
          })
          ..onDisconnect((_) {
            connected = false;
            _syncTimer?.cancel();
            notifyListeners();
          })
          ..on('kz_game_state', (data) {
            if (_leaving) return;
            state = KzGameState.fromJson(
              Map<String, dynamic>.from(data as Map),
            );
            notifyListeners();
          })
          ..on('kz_game_started', (_) {
            _socket?.emit('kz_request_state', {});
          });
    if (!(_socket?.connected ?? false)) {
      _socket!.connect();
    }
  }

  Future<void> _remember(Map<dynamic, dynamic> response, String name) async {
    playerId = '${response['playerId']}';
    resumeToken = '${response['resumeToken']}';
    roomCode = '${response['roomCode']}';
    playerName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kz_player_id', playerId!);
    await prefs.setString('kz_resume_token', resumeToken!);
    await prefs.setString('kz_room_code', roomCode!);
    await prefs.setString('kz_player_name', playerName!);
  }

  void _ack(
    String event,
    Object? payload, {
    void Function(Map<dynamic, dynamic>)? success,
  }) {
    error = null;
    _socket?.emitWithAck(
      event,
      payload,
      ack: (data) async {
        final response = data is Map ? data : <dynamic, dynamic>{};
        if (response['ok'] != true) {
          error = '${response['error'] ?? 'İşlem başarısız'}';
        } else {
          success?.call(response);
        }
        notifyListeners();
      },
    );
  }

  void create(String name, int playerCount, {String gameMode = 'solo'}) => _ack(
    'kz_create_room',
    {'playerName': name, 'playerCount': playerCount, 'gameMode': gameMode},
    success: (r) => _remember(r, name),
  );
  void join(String code, String name, {bool resume = false}) =>
      _ack('kz_join_room', {
        'roomCode': code,
        'playerName': name,
        if (resume) 'playerId': playerId,
        if (resume) 'resumeToken': resumeToken,
      }, success: (r) => _remember(r, name));
  void setReady(bool ready) => _ack('kz_set_ready', {'ready': ready});
  void startGame() => _ack('kz_start_game', {});
  void drawDeck() => _ack('kz_draw_deck', {});
  void takeOpenCard() => _ack('kz_take_open_card', {});
  void discard(String cardId) => _ack('kz_discard_card', {'cardId': cardId});
  void pressBell() {
    KzSoundService.instance.playBell();
    _ack('kz_press_bell', {});
  }

  void restart() => _ack('kz_restart_game', {});
  void updateRoomSettings(int playerCount, String gameMode) => _ack(
    'kz_update_room_settings',
    {'playerCount': playerCount, 'gameMode': gameMode},
  );
  void stopGame() => _ack('kz_stop_game', {});

  Future<void> leave() async {
    if (_leaving) return;
    _leaving = true;
    state = null;
    playerId = null;
    resumeToken = null;
    roomCode = null;
    playerName = null;
    notifyListeners();
    final done = Completer<void>();
    _socket?.emitWithAck(
      'kz_leave_room',
      {},
      ack: (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(
      const Duration(milliseconds: 800),
      onTimeout: () {},
    );
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'kz_player_id',
      'kz_resume_token',
      'kz_room_code',
      'kz_player_name',
    ]) {
      await prefs.remove(key);
    }
    _leaving = false;
    notifyListeners();
  }
}
