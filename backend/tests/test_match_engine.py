import uuid

import pytest

from app.models.enums import Faction, Rank, Rarity
from app.services.match_engine import (
    DECK_SIZE,
    MAX_BOARD_SIZE,
    STARTING_HAND_SIZE,
    CardInPlay,
    MatchRuleViolation,
    attack,
    build_state_view,
    end_turn,
    forfeit,
    handle_disconnect,
    play_card,
    start_match,
)

# La vida inicial ya no es una constante de match_engine (ahora vive en
# combat_balance_config, ver docs/memory.md 2026-07-19) -- estos tests
# ejercitan las reglas puras del motor, así que el valor concreto no
# importa, solo que sea consistente entre `_new_match` y las assertions.
TEST_STARTING_LIFE = 20


def _make_card(attack_stat: int = 30, defense: int = 30, name: str = "Test Card") -> CardInPlay:
    return CardInPlay(
        player_card_id=uuid.uuid4(),
        name=name,
        faction=Faction.greek,
        rank=Rank.hero,
        rarity=Rarity.common,
        attack=attack_stat,
        max_defense=defense,
        current_defense=defense,
    )


def _make_deck(n: int = DECK_SIZE, attack_stat: int = 30, defense: int = 30) -> list[CardInPlay]:
    return [_make_card(attack_stat, defense, name=f"Card {i}") for i in range(n)]


def _new_match():
    a_id, b_id = uuid.uuid4(), uuid.uuid4()
    match = start_match(
        match_id=uuid.uuid4(),
        player_a=(a_id, "alice", _make_deck()),
        player_b=(b_id, "bob", _make_deck()),
        starting_life=TEST_STARTING_LIFE,
    )
    return match, a_id, b_id


def _first_and_second(match, a_id, b_id):
    first = match.turn_order[0]
    second = b_id if first == a_id else a_id
    return first, second


def test_start_match_deals_opening_hands_and_random_first_player():
    match, a_id, b_id = _new_match()

    assert len(match.players[a_id].hand) == STARTING_HAND_SIZE
    assert len(match.players[b_id].hand) == STARTING_HAND_SIZE
    assert len(match.players[a_id].deck) == DECK_SIZE - STARTING_HAND_SIZE
    assert match.turn_order[0] in (a_id, b_id)
    assert match.turn_number == 0


def test_first_player_does_not_draw_on_turn_zero():
    match, a_id, b_id = _new_match()
    first, _ = _first_and_second(match, a_id, b_id)

    # turno 0: el que arranca ya tiene su mano inicial, no roba una extra.
    assert len(match.players[first].hand) == STARTING_HAND_SIZE


def test_second_player_draws_normally_on_their_first_turn():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)

    end_turn(match, first)  # pasa al turno del segundo jugador

    assert len(match.players[second].hand) == STARTING_HAND_SIZE + 1


def test_cannot_act_out_of_turn():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    card_id = match.players[second].hand[0].player_card_id

    with pytest.raises(MatchRuleViolation, match="no es tu turno"):
        play_card(match, second, card_id)


def test_cannot_play_more_than_one_card_per_turn():
    match, a_id, b_id = _new_match()
    first, _ = _first_and_second(match, a_id, b_id)
    hand = match.players[first].hand

    play_card(match, first, hand[0].player_card_id)

    with pytest.raises(MatchRuleViolation, match="ya jugaste una carta"):
        play_card(match, first, hand[1].player_card_id)


def test_cannot_play_card_when_board_is_full():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    player = match.players[first]
    player.board = _make_deck(MAX_BOARD_SIZE)
    extra_card = player.hand[0]

    with pytest.raises(MatchRuleViolation, match="tablero está lleno"):
        play_card(match, first, extra_card.player_card_id)


def test_newly_played_card_cannot_attack_same_turn():
    match, a_id, b_id = _new_match()
    first, _ = _first_and_second(match, a_id, b_id)
    card_id = match.players[first].hand[0].player_card_id

    play_card(match, first, card_id)

    with pytest.raises(MatchRuleViolation, match="mareo de invocación"):
        attack(match, first, card_id, target="face")


def test_attack_face_reduces_opponent_life():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    attacker = _make_card(attack_stat=7)
    attacker.summoning_sick = False
    match.players[first].board.append(attacker)

    attack(match, first, attacker.player_card_id, target="face")

    assert match.players[second].life == TEST_STARTING_LIFE - 7


def test_life_is_clamped_at_zero_not_negative():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    attacker = _make_card(attack_stat=999)
    attacker.summoning_sick = False
    match.players[first].board.append(attacker)

    attack(match, first, attacker.player_card_id, target="face")

    assert match.players[second].life == 0
    assert match.is_over is True
    assert match.winner_user_id == first
    assert match.reason == "life_zero"


def test_attack_card_reduces_its_defense_and_destroys_at_zero():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    attacker = _make_card(attack_stat=10)
    attacker.summoning_sick = False
    defender = _make_card(defense=15)
    match.players[first].board.append(attacker)
    match.players[second].board.append(defender)

    attack(match, first, attacker.player_card_id, target=defender.player_card_id)
    assert match.players[second].board[0].current_defense == 5
    assert match.players[second].board[0] in match.players[second].board

    attacker.has_attacked_this_turn = False  # simula otro ataque disponible
    attack(match, first, attacker.player_card_id, target=defender.player_card_id)

    assert len(match.players[second].board) == 0


def test_defense_does_not_go_negative():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    attacker = _make_card(attack_stat=999)
    attacker.summoning_sick = False
    defender = _make_card(defense=5)
    match.players[first].board.append(attacker)
    match.players[second].board.append(defender)

    attack(match, first, attacker.player_card_id, target=defender.player_card_id)

    assert len(match.players[second].board) == 0


def test_damaged_card_does_not_heal_between_turns():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    attacker = _make_card(attack_stat=10)
    attacker.summoning_sick = False
    defender = _make_card(defense=30)
    match.players[first].board.append(attacker)
    match.players[second].board.append(defender)

    attack(match, first, attacker.player_card_id, target=defender.player_card_id)
    assert defender.current_defense == 20

    end_turn(match, first)
    end_turn(match, second)  # vuelve a ser el turno de `first`

    assert defender.current_defense == 20


def test_cannot_attack_own_card_or_destroyed_card():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    attacker = _make_card(attack_stat=10)
    attacker.summoning_sick = False
    own_card = _make_card()
    match.players[first].board.extend([attacker, own_card])

    with pytest.raises(MatchRuleViolation, match="no está en el tablero rival"):
        attack(match, first, attacker.player_card_id, target=own_card.player_card_id)

    with pytest.raises(MatchRuleViolation, match="no está en el tablero rival"):
        attack(match, first, attacker.player_card_id, target=uuid.uuid4())


def test_cannot_attack_twice_same_turn():
    match, a_id, b_id = _new_match()
    first, _ = _first_and_second(match, a_id, b_id)
    attacker = _make_card(attack_stat=1)
    attacker.summoning_sick = False
    match.players[first].board.append(attacker)

    attack(match, first, attacker.player_card_id, target="face")

    with pytest.raises(MatchRuleViolation, match="ya atacó este turno"):
        attack(match, first, attacker.player_card_id, target="face")


def test_summoning_sickness_clears_at_start_of_owners_next_turn():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    card_id = match.players[first].hand[0].player_card_id
    play_card(match, first, card_id)

    end_turn(match, first)
    end_turn(match, second)  # vuelve a ser el turno de `first`

    played_card = next(c for c in match.players[first].board if c.player_card_id == card_id)
    assert played_card.summoning_sick is False
    attack(match, first, card_id, target="face")  # no debe lanzar


def test_drawing_from_empty_deck_causes_fatigue_loss():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)
    match.players[second].deck = []

    end_turn(match, first)  # dispara el draw del segundo jugador

    assert match.is_over is True
    assert match.winner_user_id == first
    assert match.reason == "fatigue"


def test_forfeit_gives_victory_to_opponent():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)

    forfeit(match, first)

    assert match.is_over is True
    assert match.winner_user_id == second
    assert match.reason == "forfeit"


def test_disconnect_gives_victory_to_opponent():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)

    handle_disconnect(match, second)

    assert match.is_over is True
    assert match.winner_user_id == first
    assert match.reason == "disconnect"


def test_cannot_act_after_match_is_over():
    match, a_id, b_id = _new_match()
    first, _ = _first_and_second(match, a_id, b_id)
    forfeit(match, first)

    with pytest.raises(MatchRuleViolation, match="ya terminó"):
        end_turn(match, first)


def test_state_view_hides_opponent_hand_and_deck_order():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)

    view = build_state_view(match, first)

    assert view["your_turn"] is True
    assert len(view["your_hand"]) == STARTING_HAND_SIZE
    assert "opponent_hand" not in view
    assert view["opponent_hand_count"] == STARTING_HAND_SIZE
    assert "deck" not in view
    assert view["your_deck_count"] == DECK_SIZE - STARTING_HAND_SIZE


def test_state_view_your_turn_false_for_non_active_player():
    match, a_id, b_id = _new_match()
    first, second = _first_and_second(match, a_id, b_id)

    view = build_state_view(match, second)

    assert view["your_turn"] is False
