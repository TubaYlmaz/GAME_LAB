import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? socket;
  String? currentRoomCode;
  String? _playerName;
  String? _gender;

  void connect() {
    if (socket == null) {
      socket = io.io(
        AppConfig.serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .build(),
      );
      // This listener is registered once and must not be removed by screens.
      socket!.on('connect', (_) => rejoinCurrentSession());
    }

    if (!socket!.connected) socket!.connect();
  }

  void setPlayerSession({
    required String roomCode,
    required String playerName,
    required String gender,
  }) {
    currentRoomCode = roomCode;
    _playerName = playerName;
    _gender = gender;
    rejoinCurrentSession();
  }

  void rejoinCurrentSession() {
    if (!(socket?.connected ?? false) ||
        currentRoomCode == null ||
        _playerName == null ||
        _gender == null) {
      return;
    }

    socket!.emit('vk_join_room', {
      'roomCode': currentRoomCode,
      'playerName': _playerName,
      'gender': _gender,
    });
  }

  void notifyAppLifecycle(bool isBackgrounded) {
    if (isBackgrounded) {
      socket?.emit('vk_app_lifecycle', {'state': 'background'});
      return;
    }

    connect();
    socket?.emit('vk_app_lifecycle', {'state': 'foreground'});
    rejoinCurrentSession();
  }

  void clearAllListeners() {
    if (socket == null) return;
    // During GameScreen -> LobbyScreen pushReplacement, GameScreen.dispose can
    // run after the new lobby registered these listeners. They are removed by
    // the next screen before it registers its own handlers.
    socket?.off('vk_vote_progress');
    socket?.off('vk_voting_results');
    socket?.off('vk_game_over');
    socket?.off('vk_host_status');
    socket?.off('vk_phase_changed');
    socket?.off('vk_navigate_to_voting');
    socket?.off('vk_vote_status_updated');
  }

  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    currentRoomCode = null;
    _playerName = null;
    _gender = null;
  }
}
