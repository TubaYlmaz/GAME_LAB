import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? socket;

  void connect() {
    if (socket != null && socket!.connected) return;

    socket = io.io(
      AppConfig.serverUrl, // config.dart içindeki IP'ye bağlanır
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      print('🟢 Sunucuya soket ile başarıyla bağlandı!');
    });

    socket!.onDisconnect((_) {
      print('🔴 Soket bağlantısı koptu.');
    });
  }

  void createRoom(Map<String, dynamic> roomData) {
    socket?.emit('create_room', roomData);
  }

  void joinRoom(Map<String, dynamic> joinData) {
    socket?.emit('join_room', joinData);
  }

  void listenPlayersUpdate(Function(List<dynamic>) onPlayersUpdated) {
    socket?.on('players_updated', (data) {
      onPlayersUpdated(data);
    });
  }

  void listenGameStart(Function(Map<String, dynamic>) onGameStarted) {
    socket?.on('game_started', (data) {
      onGameStarted(data);
    });
  }
} 