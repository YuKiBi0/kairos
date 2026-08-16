import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/io.dart';

abstract interface class RealtimeSocket {
  Future<void> get ready;

  Stream<Object?> get messages;

  void send(Object? message);

  Future<void> close([int? code, String? reason]);
}

abstract interface class RealtimeConnector {
  RealtimeSocket connect(Uri endpoint, String accessToken);
}

class IoRealtimeConnector implements RealtimeConnector {
  const IoRealtimeConnector();

  @override
  RealtimeSocket connect(Uri endpoint, String accessToken) => _IoRealtimeSocket(
    IOWebSocketChannel.connect(
      endpoint,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      pingInterval: const Duration(seconds: 20),
      connectTimeout: const Duration(seconds: 15),
    ),
  );
}

class _IoRealtimeSocket implements RealtimeSocket {
  const _IoRealtimeSocket(this._channel);

  final IOWebSocketChannel _channel;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<Object?> get messages => _channel.stream;

  @override
  void send(Object? message) => _channel.sink.add(message);

  @override
  Future<void> close([int? code, String? reason]) =>
      _channel.sink.close(code, reason);
}

abstract interface class NetworkMonitor {
  Future<bool> isOnline();

  Stream<bool> get changes;
}

class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
