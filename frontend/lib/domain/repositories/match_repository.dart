/// Protocolo completo en docs/designs/realtime-match.md — cliente↔servidor
/// sobre un único WebSocket (`/ws/match?token=<jwt>`), matchmaking y
/// partida comparten la misma conexión.
abstract class MatchRepository {
  /// Conecta y devuelve el stream de mensajes del servidor ya parseados
  /// (`{"type": "queued" | "match_found" | "state_update" | "match_over" |
  /// "error", ...}`). Lanza [ApiException] 401 si no hay sesión.
  Future<Stream<Map<String, dynamic>>> connect();

  void queue(List<String> deck);
  void leaveQueue();
  void playCard(String playerCardId);
  void attackFace(String attackerId);
  void attackCard({required String attackerId, required String targetCardId});
  void endTurn();
  void forfeit();

  Future<void> disconnect();
}
