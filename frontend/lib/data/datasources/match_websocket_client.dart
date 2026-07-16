import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api_config.dart';

/// Wrapper fino sobre [WebSocketChannel] para `/ws/match` — conecta, manda
/// acciones como JSON y expone los mensajes del servidor ya decodificados
/// como `Map`. Ver docs/designs/realtime-match.md para la forma exacta de
/// cada mensaje del protocolo cliente↔servidor. Sin lógica de reconexión a
/// propósito: el spec de juego define desconexión = derrota inmediata, sin
/// gracia de reconexión.
class MatchWebSocketClient {
  final WebSocketChannel Function(Uri uri) _connectFn;
  WebSocketChannel? _channel;

  MatchWebSocketClient({WebSocketChannel Function(Uri uri)? connect})
      : _connectFn = connect ?? WebSocketChannel.connect;

  Stream<Map<String, dynamic>> connect(String token) {
    final channel = _connectFn(_matchUri(token));
    _channel = channel;
    return channel.stream.map((raw) => jsonDecode(raw as String) as Map<String, dynamic>);
  }

  void send(Map<String, dynamic> action) {
    final channel = _channel;
    if (channel == null) {
      throw StateError('MatchWebSocketClient.send llamado antes de connect()');
    }
    channel.sink.add(jsonEncode(action));
  }

  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
  }

  Uri _matchUri(String token) {
    final base = Uri.parse(ApiConfig.baseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: wsScheme,
      path: '/ws/match',
      queryParameters: {'token': token},
    );
  }
}
