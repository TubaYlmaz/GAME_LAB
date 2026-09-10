import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/throw_history.dart';

class ChanceGameSocketService {
  ChanceGameSocketService._();

  static final ChanceGameSocketService instance = ChanceGameSocketService._();

  io.Socket? _socket;

  String get _serverUrl {
    const configuredServerUrl = String.fromEnvironment('SERVER_URL');
    if (configuredServerUrl.isNotEmpty) return configuredServerUrl;
    if (kIsWeb) return Uri.base.origin;
    return 'http://10.0.2.2:3000';
  }

  void connect() {
    if (_socket != null) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }

    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    )..connect();
  }

  Future<void> recordAction(ThrowHistory history) async {
    connect();
    final socket = _socket;
    if (socket == null) return;

    final acknowledgement = Completer<void>();
    socket.emitWithAck(
      'sp_record_action',
      history.toActionPayload(),
      ack: (dynamic response) {
        if (!acknowledgement.isCompleted) acknowledgement.complete();
      },
    );

    // Oyun yerel olarak devam eder; sunucu gecici olarak kapaliysa UI kilitlenmez.
    await acknowledgement.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
