import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? socket;
  String? currentRoomCode;

  void connect() {
    if (socket != null && socket!.connected) return;

    if (socket != null && !socket!.connected) {
      socket!.connect();
      return;
    }

    socket = io.io(
      AppConfig.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(500)
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      print('🟢 Sunucuya soket ile başarıyla bağlandı! Socket ID: ${socket?.id}');
      if (currentRoomCode != null && currentRoomCode!.isNotEmpty) {
        socket?.emit('vk_get_players', {'roomCode': currentRoomCode});
      }
    });

    socket!.onDisconnect((_) {
      print('🔴 Soket bağlantısı koptu.');
    });
  }

  void clearAllListeners() {
    socket?.off('vk_game_started');
    socket?.off('vk_players_updated');
    socket?.off('vk_vote_progress');
    socket?.off('vk_round_ended');
    socket?.off('vk_game_over');
    socket?.off('vk_phase_changed');
    socket?.off('players_updated');
    socket?.off('game_started');
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