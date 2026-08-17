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

  void setSession({
    required String newRoomCode,
    required String newPlayerName,
    required String newGender,
  }) {
    roomCode = newRoomCode;
    playerName = newPlayerName;
    gender = newGender;
    _rejoin();
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
}
