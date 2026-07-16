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

  /// Código de cierre del último WebSocket (ej. 4401 = el servidor rechazó
  /// el JWT al conectar) — null si nunca se conectó o el cierre todavía no
  /// terminó. Lo expone el propio `WebSocketChannel` una vez cerrado.
  int? get closeCode => _channel?.closeCode;

  Stream<Map<String, dynamic>> connect(String token) {
    // Cerrar cualquier conexión previa antes de reemplazar la referencia —
    // sin esto, un segundo connect() (ej. doble tap en "BUSCAR PARTIDA")
    // deja el socket viejo abierto para siempre, nunca cerrado del lado
    // cliente.
    _channel?.sink.close();
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
    final channel = _channel;
    if (channel == null) return;
    await channel.sink.close();
    // Solo limpiar la referencia si nadie conectó una NUEVA mientras
    // esperábamos este cierre — si no, un close() tardío de la conexión
    // vieja pisaría la referencia a la conexión nueva que ya está en uso.
    if (identical(_channel, channel)) {
      _channel = null;
    }
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
