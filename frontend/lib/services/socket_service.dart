import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart'
    as io; // Prefix lowercase to fix lint error
import '../config/app_config.dart';
import 'storage_service.dart';

typedef MessageCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static final SocketService _i = SocketService._();
  factory SocketService() => _i;
  SocketService._();

  io.Socket? _socket;
  bool _connected = false;

  final Map<String, List<MessageCallback>> _handlers = {};

  bool get isConnected => _connected;

  Future<void> connect() async {
    // Agar pehle se connected hai ya socket initialize hai toh dubara na karein
    if (_connected && _socket != null) return;

    final token = await StorageService.getToken();
    if (token == null || token.isEmpty) return;

    // Create a Completer to wait for actual connection
    final completer = Completer<void>();

    try {
      // Socket.io initialization with dynamic URL from config
      final socketUrl = appConfig.wsUrl.endsWith('/ws')
          ? appConfig.wsUrl
          : '${appConfig.wsUrl.replaceAll(RegExp(r'/+$'), '')}/ws';

      _socket = io.io(
          socketUrl,
          io.OptionBuilder()
              .setTransports(['websocket', 'polling']) // For Web/Chrome support
              .setExtraHeaders({'Authorization': 'Bearer $token'})
              .setQuery({'token': token})
              .enableAutoConnect()
              .enableReconnection()
              .build());

      _socket!.onConnect((_) {
        debugPrint('✅ Socket Connected');
        _connected = true;
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('⚠️ Socket Disconnected');
        _connected = false;
      });

      _socket!.onConnectError((err) {
        debugPrint('⚠️ Connection Error: $err');
        if (!completer.isCompleted) {
          completer.completeError('Connection error: $err');
        }
      });

      // Listen to any event coming from NestJS
      _socket!.onAny((event, data) {
        if (_handlers.containsKey(event)) {
          for (final cb in _handlers[event]!) {
            // Socket.io already provides data as a Map
            cb(data is Map<String, dynamic> ? data : {'data': data});
          }
        }
      });

      // Wait for connection with timeout
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Socket connection timed out after 10 seconds');
        },
      );
    } catch (e) {
      debugPrint('❌ Socket Init Error: $e');
      _connected = false;
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    }
  }

  // Purana 'on' method as it is kaam karega
  void on(String event, MessageCallback cb) {
    _handlers.putIfAbsent(event, () => []).add(cb);
  }

  void off(String event) {
    _handlers.remove(event);
    _socket?.off(event);
  }

  void offAll() {
    _handlers.clear();
  }

  // Socket.io uses .emit() instead of .sink.add()
  Future<void> sendMessage(
      {required int jobId,
      required int receiverId,
      required String message}) async {
    if (_socket == null || !_socket!.connected) {
      try {
        await connect();
      } catch (e) {
        debugPrint('⚠️ Socket reconnect failed: $e');
      }
    }

    if (_socket != null && _socket!.connected) {
      _socket!.emit('send_message', {
        'jobId': jobId,
        'receiverId': receiverId,
        'message': message,
      });
    } else {
      debugPrint('⚠️ sendMessage failed because socket is not connected');
    }
  }

  // Mark Read method (Ab ChatScreen error nahi dega)
  Future<void> markRead(int jobId) async {
    if (_socket == null || !_socket!.connected) {
      try {
        await connect();
      } catch (e) {
        debugPrint('⚠️ Socket reconnect failed for markRead: $e');
      }
    }

    if (_socket != null && _socket!.connected) {
      _socket!.emit('mark_read', {
        'jobId': jobId,
      });
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _handlers.clear();
  }
}
