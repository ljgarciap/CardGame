import uuid

from app.db.seed import seed_archetypes
from app.models.enums import Faction, Rank, Rarity
from app.services import bot
from app.services.match_engine import DECK_SIZE, CardInPlay, Match, MatchPlayerState
from tests.test_match_ws import _make_player, _token


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


def _new_bot_match(*, bot_hand=None, bot_board=None, human_board=None) -> tuple[Match, uuid.UUID]:
    """Arma un Match a mano (sin pasar por start_match, que baraja el orden
    al azar) con el bot como jugador activo -- da control total para
    probar la heurística sin depender de qué lado ganó el shuffle."""
    human_id = uuid.uuid4()
    match = Match(
        id=uuid.uuid4(),
        players={
            bot.BOT_USER_ID: MatchPlayerState(
                user_id=bot.BOT_USER_ID,
                username=bot.BOT_USERNAME,
                life=20,
                deck=_make_deck(),
                hand=bot_hand or [],
                board=bot_board or [],
            ),
            human_id: MatchPlayerState(
                user_id=human_id,
                username="human",
                life=20,
                deck=_make_deck(),
                board=human_board or [],
            ),
        },
        turn_order=[bot.BOT_USER_ID, human_id],
        current_turn_index=0,
    )
    return match, human_id


def test_build_bot_deck_returns_deck_size_distinct_cards(db_session):
    seed_archetypes(db_session)

    deck = bot.build_bot_deck(db_session)

    assert len(deck) == DECK_SIZE
    assert len({c.player_card_id for c in deck}) == DECK_SIZE
    assert all(c.rarity == Rarity.common for c in deck)


def test_is_bot_turn_reflects_current_turn_order():
    match, human_id = _new_bot_match()
    assert bot.is_bot_turn(match) is True

    match.current_turn_index = 1
    assert bot.is_bot_turn(match) is False


def test_run_bot_turn_does_nothing_when_not_its_turn():
    match, human_id = _new_bot_match()
    match.current_turn_index = 1  # le toca al humano
    before = match.model_copy(deep=True)

    bot.run_bot_turn(match)

    assert match == before


def test_run_bot_turn_plays_highest_attack_card_and_ends_turn():
    weak, strong = _make_card(attack_stat=10, name="Weak"), _make_card(attack_stat=90, name="Strong")
    match, human_id = _new_bot_match(bot_hand=[weak, strong])

    bot.run_bot_turn(match)

    bot_state = match.players[bot.BOT_USER_ID]
    assert len(bot_state.board) == 1
    assert bot_state.board[0].name == "Strong"
    # end_turn ya corrió: le toca al humano.
    assert match.turn_order[match.current_turn_index] == human_id


def test_run_bot_turn_attacks_face_when_opponent_board_is_empty():
    attacker = _make_card(attack_stat=15)
    attacker.summoning_sick = False
    match, human_id = _new_bot_match(bot_board=[attacker])

    bot.run_bot_turn(match)

    # attack() clampea la vida a un mínimo de 0 -- este ataque (15) es
    # menor a STARTING_LIFE (20) a propósito, para que el resultado no
    # quede pegado al piso y esta prueba distinga "restó lo que tenía que
    # restar" de "restó cualquier cosa porque total quedó en 0 igual".
    assert match.players[human_id].life == 20 - 15


def test_run_bot_turn_prefers_a_favorable_trade_over_attacking_face():
    attacker = _make_card(attack_stat=50)
    attacker.summoning_sick = False
    killable_target = _make_card(attack_stat=5, defense=30, name="Killable")
    match, human_id = _new_bot_match(bot_board=[attacker], human_board=[killable_target])

    bot.run_bot_turn(match)

    human_state = match.players[human_id]
    assert human_state.life == 20  # no le pegó a la cara
    assert killable_target not in human_state.board  # trade la mató


def test_run_bot_turn_attacks_face_when_no_favorable_trade_is_available():
    attacker = _make_card(attack_stat=10)
    attacker.summoning_sick = False
    tough_target = _make_card(attack_stat=5, defense=999, name="Tanque")
    match, human_id = _new_bot_match(bot_board=[attacker], human_board=[tough_target])

    bot.run_bot_turn(match)

    assert match.players[human_id].life == 20 - 10
    assert tough_target in match.players[human_id].board  # no lo pudo matar


def test_bot_going_first_draws_no_card_on_turn_zero():
    """El bot no tiene mano al arrancar la partida (turn_number == 0, nadie
    roba en el primer turno) -- run_bot_turn no debería intentar jugar una
    carta que no tiene."""
    match, human_id = _new_bot_match(bot_hand=[])
    match.turn_number = 0

    bot.run_bot_turn(match)  # no debe tirar excepción

    assert match.players[bot.BOT_USER_ID].hand == []
    assert match.turn_order[match.current_turn_index] == human_id
    # Al pasarle el turno al humano, _start_turn lo hace robar (turn_number
    # ya no es 0) -- el humano arrancó con la mano vacía en este test (no
    # se pasó por start_match, que reparte la mano inicial), así que 1
    # confirma exactamente un draw, ni más ni menos.
    assert len(match.players[human_id].hand) == 1


# --- integración vía WebSocket real ---


def test_start_bot_match_puts_the_human_on_a_turn_immediately(client, db_session):
    seed_archetypes(db_session)
    user, deck = _make_player(db_session, username="erin_ws")

    with client.websocket_connect(f"/ws/match?token={_token(user)}") as ws:
        ws.send_json({"action": "start_bot_match", "deck": deck})

        found = ws.receive_json()
        state = ws.receive_json()

        assert found["type"] == "match_found"
        assert found["opponent_username"] == bot.BOT_USERNAME
        assert state["type"] == "state_update"
        # Sea cual sea el resultado del orden de turno al azar: si le tocaba
        # arrancar al bot, ya jugó su turno entero antes de que el humano se
        # entere -- acá siempre debería ser el turno del humano.
        assert state["state"]["your_turn"] is True


def test_end_turn_against_bot_comes_back_to_the_human(client, db_session):
    seed_archetypes(db_session)
    user, deck = _make_player(db_session, username="frank_ws")

    with client.websocket_connect(f"/ws/match?token={_token(user)}") as ws:
        ws.send_json({"action": "start_bot_match", "deck": deck})
        ws.receive_json()  # match_found
        ws.receive_json()  # state_update inicial

        ws.send_json({"action": "end_turn"})
        after_bot_turn = ws.receive_json()

        # Con el balance actual (combat_balance_config, ver docs/memory.md
        # 2026-07-19) ninguna carta mata de un solo golpe, así que en la
        # práctica esto va a ser casi siempre state_update -- pero se
        # acepta también match_over en vez de asumirlo, para no acoplar
        # este test de integración a los valores concretos de balance
        # (que son ajustables sin deploy y pueden volver a cambiar).
        assert after_bot_turn["type"] in ("state_update", "match_over")
        if after_bot_turn["type"] == "state_update":
            assert after_bot_turn["state"]["your_turn"] is True
