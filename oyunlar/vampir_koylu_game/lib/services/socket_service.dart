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

    socket = io.io(
      AppConfig.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    socket?.connect();
  }

  void clearAllListeners() {
    if (socket == null) return;
    // During GameScreen -> LobbyScreen pushReplacement, GameScreen.dispose can
    // run after the new lobby registered these listeners. They are removed by
    // the next screen before it registers its own handlers.
    socket?.off('vk_vote_progress');
    socket?.off('vk_round_ended');
    socket?.off('vk_voting_results');
    socket?.off('vk_game_over');
    socket?.off('vk_host_status');
    socket?.off('vk_phase_changed');
    socket?.off('vk_navigate_to_voting');
    socket?.off('vk_vote_status_updated');
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
  }
}
