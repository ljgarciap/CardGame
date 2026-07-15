"""Reglas puras de una partida en tiempo real — sin I/O (ni Redis ni
WebSocket ni Postgres acá), 100% testeable con objetos en memoria. Ver
docs/specs/realtime-match.md (regla de juego) y
docs/designs/realtime-match.md (protocolo/arquitectura).

Constantes de partida (mazo/vida/mano/tablero): son reglas de juego fijas
definidas por el Game Expert, no valores de negocio ajustables (misma
categoría que MIN_LEVEL/MAX_LEVEL en gacha_service.py) — no van a una tabla
paramétrica.
"""
import random
from typing import Optional, Union
from uuid import UUID

from pydantic import BaseModel

from app.models.enums import Faction, Rank, Rarity

DECK_SIZE = 10
STARTING_LIFE = 20
STARTING_HAND_SIZE = 3
MAX_BOARD_SIZE = 5

_rng = random.SystemRandom()


class MatchRuleViolation(ValueError):
    """Acción de cliente inválida contra las reglas de la partida — el
    servidor la rechaza sin aplicar ningún cambio de estado."""


class CardInPlay(BaseModel):
    player_card_id: UUID
    name: str
    faction: Faction
    rank: Rank
    rarity: Rarity
    attack: int
    max_defense: int
    current_defense: int
    summoning_sick: bool = True
    has_attacked_this_turn: bool = False


class MatchPlayerState(BaseModel):
    user_id: UUID
    username: str
    life: int = STARTING_LIFE
    deck: list[CardInPlay] = []
    hand: list[CardInPlay] = []
    board: list[CardInPlay] = []
    has_played_card_this_turn: bool = False


class Match(BaseModel):
    id: UUID
    players: dict[UUID, MatchPlayerState]
    turn_order: list[UUID]
    current_turn_index: int = 0
    turn_number: int = 0
    is_over: bool = False
    winner_user_id: Optional[UUID] = None
    reason: Optional[str] = None


def _current_player_id(match: Match) -> UUID:
    return match.turn_order[match.current_turn_index]


def _other_player_id(match: Match, user_id: UUID) -> UUID:
    return next(uid for uid in match.turn_order if uid != user_id)


def _require_turn(match: Match, user_id: UUID) -> None:
    if match.is_over:
        raise MatchRuleViolation("la partida ya terminó")
    if user_id not in match.players:
        raise MatchRuleViolation("no sos parte de esta partida")
    if _current_player_id(match) != user_id:
        raise MatchRuleViolation("no es tu turno")


def _end_match(match: Match, winner_id: Optional[UUID], reason: str) -> None:
    match.is_over = True
    match.winner_user_id = winner_id
    match.reason = reason


def _draw_card(match: Match, player: MatchPlayerState) -> None:
    if not player.deck:
        _end_match(match, winner_id=_other_player_id(match, player.user_id), reason="fatigue")
        return
    player.hand.append(player.deck.pop(0))


def _start_turn(match: Match) -> None:
    """Efectos de inicio de turno del jugador activo: se le quita el mareo
    de invocación a sus cartas, resetea si ya atacaron/jugó una carta este
    turno, y roba — salvo que sea el primerísimo turno de toda la partida
    (turn_number == 0), donde el jugador que arranca no roba (evita ventaja
    de salida, convención estándar de TCG)."""
    player = match.players[_current_player_id(match)]
    for card in player.board:
        card.summoning_sick = False
        card.has_attacked_this_turn = False
    player.has_played_card_this_turn = False

    if match.turn_number != 0:
        _draw_card(match, player)


def _shuffled(cards: list[CardInPlay]) -> list[CardInPlay]:
    shuffled = cards.copy()
    _rng.shuffle(shuffled)
    return shuffled


def start_match(
    match_id: UUID,
    player_a: tuple[UUID, str, list[CardInPlay]],
    player_b: tuple[UUID, str, list[CardInPlay]],
) -> Match:
    """player_a/player_b: (user_id, username, cartas del deck elegido —
    exactamente DECK_SIZE, ya resueltas desde player_cards por el caller)."""
    (a_id, a_name, a_cards), (b_id, b_name, b_cards) = player_a, player_b

    players = {
        a_id: MatchPlayerState(user_id=a_id, username=a_name, deck=_shuffled(a_cards)),
        b_id: MatchPlayerState(user_id=b_id, username=b_name, deck=_shuffled(b_cards)),
    }

    turn_order = [a_id, b_id]
    _rng.shuffle(turn_order)  # quién arranca es al azar

    match = Match(id=match_id, players=players, turn_order=turn_order)

    for state in match.players.values():
        for _ in range(STARTING_HAND_SIZE):
            if state.deck:
                state.hand.append(state.deck.pop(0))

    _start_turn(match)  # aplica la regla de "no roba en el turno 0"
    return match


def play_card(match: Match, user_id: UUID, player_card_id: UUID) -> Match:
    _require_turn(match, user_id)
    player = match.players[user_id]

    if player.has_played_card_this_turn:
        raise MatchRuleViolation("ya jugaste una carta este turno")
    if len(player.board) >= MAX_BOARD_SIZE:
        raise MatchRuleViolation("el tablero está lleno")

    card = next((c for c in player.hand if c.player_card_id == player_card_id), None)
    if card is None:
        raise MatchRuleViolation("esa carta no está en tu mano")

    player.hand.remove(card)
    card.summoning_sick = True
    card.has_attacked_this_turn = False
    player.board.append(card)
    player.has_played_card_this_turn = True
    return match


def attack(
    match: Match, user_id: UUID, attacker_id: UUID, target: Union[str, UUID]
) -> Match:
    """target: el string "face", o el player_card_id de una carta rival."""
    _require_turn(match, user_id)
    player = match.players[user_id]
    opponent_id = _other_player_id(match, user_id)
    opponent = match.players[opponent_id]

    attacker = next((c for c in player.board if c.player_card_id == attacker_id), None)
    if attacker is None:
        raise MatchRuleViolation("esa carta no está en tu tablero")
    if attacker.summoning_sick:
        raise MatchRuleViolation("esa carta tiene mareo de invocación")
    if attacker.has_attacked_this_turn:
        raise MatchRuleViolation("esa carta ya atacó este turno")

    if target == "face":
        opponent.life = max(0, opponent.life - attacker.attack)
    else:
        target_card = next((c for c in opponent.board if c.player_card_id == target), None)
        if target_card is None:
            raise MatchRuleViolation("esa carta no está en el tablero rival")
        target_card.current_defense = max(0, target_card.current_defense - attacker.attack)
        if target_card.current_defense == 0:
            opponent.board.remove(target_card)

    attacker.has_attacked_this_turn = True

    if opponent.life <= 0:
        _end_match(match, winner_id=user_id, reason="life_zero")

    return match


def end_turn(match: Match, user_id: UUID) -> Match:
    _require_turn(match, user_id)
    match.current_turn_index = (match.current_turn_index + 1) % len(match.turn_order)
    match.turn_number += 1
    _start_turn(match)
    return match


def forfeit(match: Match, user_id: UUID) -> Match:
    if match.is_over:
        raise MatchRuleViolation("la partida ya terminó")
    if user_id not in match.players:
        raise MatchRuleViolation("no sos parte de esta partida")
    _end_match(match, winner_id=_other_player_id(match, user_id), reason="forfeit")
    return match


def handle_disconnect(match: Match, user_id: UUID) -> Match:
    """A diferencia de las demás acciones, no la dispara un mensaje de
    cliente sino la capa de WebSocket al detectar el corte de conexión —
    no valida turno (te podés desconectar en cualquier momento)."""
    if match.is_over or user_id not in match.players:
        return match
    _end_match(match, winner_id=_other_player_id(match, user_id), reason="disconnect")
    return match


def _card_view(card: CardInPlay, *, in_play: bool) -> dict:
    view = {
        "player_card_id": str(card.player_card_id),
        "name": card.name,
        "faction": card.faction.value,
        "rank": card.rank.value,
        "rarity": card.rarity.value,
        "attack": card.attack,
        "max_defense": card.max_defense,
    }
    if in_play:
        view["current_defense"] = card.current_defense
        view["summoning_sick"] = card.summoning_sick
        view["has_attacked_this_turn"] = card.has_attacked_this_turn
    return view


def build_state_view(match: Match, viewer_id: UUID) -> dict:
    """Vista del estado de la partida desde la perspectiva de `viewer_id` —
    tu mano completa, solo la cantidad de la mano rival, nunca el orden del
    mazo de nadie."""
    opponent_id = _other_player_id(match, viewer_id)
    viewer = match.players[viewer_id]
    opponent = match.players[opponent_id]

    return {
        "your_turn": (not match.is_over) and _current_player_id(match) == viewer_id,
        "your_life": viewer.life,
        "opponent_life": opponent.life,
        "your_hand": [_card_view(c, in_play=False) for c in viewer.hand],
        "your_board": [_card_view(c, in_play=True) for c in viewer.board],
        "opponent_board": [_card_view(c, in_play=True) for c in opponent.board],
        "opponent_hand_count": len(opponent.hand),
        "your_deck_count": len(viewer.deck),
        "opponent_deck_count": len(opponent.deck),
    }
