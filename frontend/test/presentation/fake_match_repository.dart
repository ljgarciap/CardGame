import 'dart:async';

import 'package:card_game/domain/repositories/match_repository.dart';

class FakeMatchRepository implements MatchRepository {
  final StreamController<Map<String, dynamic>> _controller = StreamController.broadcast();
  final List<String> calls = [];
  Object? connectError;
  bool disconnected = false;

  @override
  Future<Stream<Map<String, dynamic>>> connect() async {
    if (connectError != null) throw connectError!;
    return _controller.stream;
  }

  void emit(Map<String, dynamic> message) => _controller.add(message);
  void emitError(Object error) => _controller.addError(error);
  void emitDone() => _controller.close();

  @override
  void queue(List<String> deck) => calls.add('queue($deck)');

  @override
  void startBotMatch(List<String> deck) => calls.add('startBotMatch($deck)');

  @override
  void leaveQueue() => calls.add('leaveQueue()');

  @override
  void playCard(String playerCardId) => calls.add('playCard($playerCardId)');

  @override
  void attackFace(String attackerId) => calls.add('attackFace($attackerId)');

  @override
  void attackCard({required String attackerId, required String targetCardId}) =>
      calls.add('attackCard($attackerId, $targetCardId)');

  @override
  void endTurn() => calls.add('endTurn()');

  @override
  void forfeit() => calls.add('forfeit()');

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

  int? lastCloseCodeToReturn;

  @override
  int? get lastCloseCode => lastCloseCodeToReturn;
}
