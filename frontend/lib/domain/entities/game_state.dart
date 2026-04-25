import 'player.dart';
import 'deck.dart';

enum GameStatus {
  waiting,
  starting,
  playing,
  finished,
}

class GameStateEntity {
  final String roomId;
  final List<PlayerEntity> players;
  final DeckEntity? deck;
  final int turnIndex;
  final GameStatus status;

  GameStateEntity({
    required this.roomId,
    this.players = const [],
    this.deck,
    this.turnIndex = 0,
    this.status = GameStatus.waiting,
  });

  PlayerEntity? get currentPlayer {
    if (players.isEmpty) return null;
    return players[turnIndex % players.length];
  }

  GameStateEntity copyWith({
    String? roomId,
    List<PlayerEntity>? players,
    DeckEntity? deck,
    int? turnIndex,
    GameStatus? status,
  }) {
    return GameStateEntity(
      roomId: roomId ?? this.roomId,
      players: players ?? this.players,
      deck: deck ?? this.deck,
      turnIndex: turnIndex ?? this.turnIndex,
      status: status ?? this.status,
    );
  }
}
