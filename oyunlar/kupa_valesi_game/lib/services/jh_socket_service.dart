import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';

class JhSocketService {
  JhSocketService._();

  static final JhSocketService instance = JhSocketService._();

  io.Socket? socket;
  String? roomCode;
  String? playerName;
  String? gender;

  void connect() {
    socket ??= io.io(
      AppConfig.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    )..onConnect((_) => _rejoin());
    if (!(socket?.connected ?? false)) socket!.connect();
  }

  Future<void> setSession({
    required String newRoomCode,
    required String newPlayerName,
    required String newGender,
  }) {
    roomCode = newRoomCode;
    playerName = newPlayerName;
    gender = newGender;
    _rejoin();
    return Future.value();
  }

  void _rejoin() {
    if (!(socket?.connected ?? false) ||
        roomCode == null ||
        playerName == null ||
        gender == null) {
      return;
    }
    socket!.emit('jh_join_room', {
      'roomCode': roomCode,
      'playerName': playerName,
      'gender': gender,
    });
  }

  Future<void> clearSession() {
    roomCode = null;
    playerName = null;
    gender = null;
    return Future.value();
  }

  /// Reconnect after returning to the foreground. Session data only lives in
  /// memory, so a full app/browser restart always opens the entry screen.
  void resumeActiveSession() {
    connect();
    _rejoin();
  }
}
