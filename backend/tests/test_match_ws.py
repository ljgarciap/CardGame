import uuid

import pytest

from app.core.security import create_access_token
from app.models.card_archetype import CardArchetype
from app.models.enums import Faction, Rank, Rarity
from app.models.player_card import PlayerCard
from app.models.user import User
from app.services.match_engine import DECK_SIZE


def _make_player(db_session, *, username: str) -> tuple[User, list[str]]:
    user = User(
        email=f"{username}@example.com",
        password_hash="x",
        username=username,
        avatar_id="default",
        email_verified=True,
        coins=0,
    )
    db_session.add(user)
    db_session.flush()

    archetype = CardArchetype(
        name="Achilles",
        faction=Faction.greek,
        rank=Rank.hero,
        base_attack=30,
        base_defense=30,
        description="test",
    )
    db_session.add(archetype)
    db_session.flush()

    cards = []
    for _ in range(DECK_SIZE):
        card = PlayerCard(
            user_id=user.id,
            archetype_id=archetype.id,
            rarity=Rarity.common,
            attack=30,
            defense=30,
        )
        db_session.add(card)
        cards.append(card)
    db_session.flush()
    db_session.commit()

    return user, [str(c.id) for c in cards]


def _token(user: User) -> str:
    return create_access_token(str(user.id))


def test_connect_without_token_is_rejected(client):
    with pytest.raises(Exception):
        with client.websocket_connect("/ws/match"):
            pass


def test_queue_and_match_found_broadcasts_initial_state(client, db_session):
    user_a, deck_a = _make_player(db_session, username="alice_ws")
    user_b, deck_b = _make_player(db_session, username="bob_ws")

    with client.websocket_connect(f"/ws/match?token={_token(user_a)}") as ws_a, \
            client.websocket_connect(f"/ws/match?token={_token(user_b)}") as ws_b:
        ws_a.send_json({"action": "queue", "deck": deck_a})
        assert ws_a.receive_json()["type"] == "queued"
        ws_b.send_json({"action": "queue", "deck": deck_b})
        assert ws_b.receive_json()["type"] == "queued"

        found_a = ws_a.receive_json()
        state_a = ws_a.receive_json()
        found_b = ws_b.receive_json()
        state_b = ws_b.receive_json()

        assert found_a["type"] == "match_found"
        assert found_a["opponent_username"] == "bob_ws"
        assert found_b["type"] == "match_found"
        assert found_b["opponent_username"] == "alice_ws"
        assert found_a["match_id"] == found_b["match_id"]

        assert state_a["type"] == "state_update"
        assert state_b["type"] == "state_update"
        assert len(state_a["state"]["your_hand"]) == 3
        assert state_a["state"]["opponent_hand_count"] == 3
        assert state_a["state"]["your_turn"] != state_b["state"]["your_turn"]


def test_end_turn_broadcasts_updated_state_to_both_players(client, db_session):
    user_a, deck_a = _make_player(db_session, username="carol_ws")
    user_b, deck_b = _make_player(db_session, username="dave_ws")

    with client.websocket_connect(f"/ws/match?token={_token(user_a)}") as ws_a, \
            client.websocket_connect(f"/ws/match?token={_token(user_b)}") as ws_b:
        ws_a.send_json({"action": "queue", "deck": deck_a})
        ws_a.receive_json()  # queued
        ws_b.send_json({"action": "queue", "deck": deck_b})
        ws_b.receive_json()  # queued

        ws_a.receive_json()  # match_found
        state_a = ws_a.receive_json()  # state_update
        ws_b.receive_json()  # match_found
        state_b = ws_b.receive_json()  # state_update

        active_ws, active_state, waiting_ws = (
            (ws_a, state_a, ws_b) if state_a["state"]["your_turn"] else (ws_b, state_b, ws_a)
        )

        active_ws.send_json({"action": "end_turn"})

        active_update = active_ws.receive_json()
        waiting_update = waiting_ws.receive_json()

        assert active_update["type"] == "state_update"
        assert waiting_update["type"] == "state_update"
        assert active_update["state"]["your_turn"] is False
        assert waiting_update["state"]["your_turn"] is True


def test_action_out_of_turn_returns_error_only_to_sender(client, db_session):
    user_a, deck_a = _make_player(db_session, username="erin_ws")
    user_b, deck_b = _make_player(db_session, username="frank_ws")

    with client.websocket_connect(f"/ws/match?token={_token(user_a)}") as ws_a, \
            client.websocket_connect(f"/ws/match?token={_token(user_b)}") as ws_b:
        ws_a.send_json({"action": "queue", "deck": deck_a})
        ws_a.receive_json()  # queued
        ws_b.send_json({"action": "queue", "deck": deck_b})
        ws_b.receive_json()  # queued

        ws_a.receive_json()  # match_found
        state_a = ws_a.receive_json()  # state_update
        ws_b.receive_json()  # match_found
        state_b = ws_b.receive_json()  # state_update

        waiting_ws = ws_a if not state_a["state"]["your_turn"] else ws_b

        waiting_ws.send_json({"action": "end_turn"})

        error = waiting_ws.receive_json()
        assert error["type"] == "error"
        assert "turno" in error["detail"]


def test_queue_while_already_in_a_match_is_rejected(client, db_session):
    user_a, deck_a = _make_player(db_session, username="ivan_ws")
    user_b, deck_b = _make_player(db_session, username="judy_ws")

    with client.websocket_connect(f"/ws/match?token={_token(user_a)}") as ws_a, \
            client.websocket_connect(f"/ws/match?token={_token(user_b)}") as ws_b:
        ws_a.send_json({"action": "queue", "deck": deck_a})
        ws_a.receive_json()  # queued
        ws_b.send_json({"action": "queue", "deck": deck_b})
        ws_b.receive_json()  # queued

        ws_a.receive_json()  # match_found
        ws_a.receive_json()  # state_update
        ws_b.receive_json()  # match_found
        ws_b.receive_json()  # state_update

        ws_a.send_json({"action": "queue", "deck": deck_a})
        error = ws_a.receive_json()

        assert error["type"] == "error"
        assert "partida" in error["detail"]


def test_disconnect_ends_match_and_declares_opponent_winner(client, db_session):
    user_a, deck_a = _make_player(db_session, username="grace_ws")
    user_b, deck_b = _make_player(db_session, username="heidi_ws")

    with client.websocket_connect(f"/ws/match?token={_token(user_a)}") as ws_a:
        ws_b = client.websocket_connect(f"/ws/match?token={_token(user_b)}").__enter__()
        try:
            ws_a.send_json({"action": "queue", "deck": deck_a})
            ws_a.receive_json()  # queued
            ws_b.send_json({"action": "queue", "deck": deck_b})
            ws_b.receive_json()  # queued

            ws_a.receive_json()  # match_found
            ws_a.receive_json()  # state_update
            ws_b.receive_json()  # match_found
            ws_b.receive_json()  # state_update

            # Cierre "prolijo": solo manda el frame de disconnect y deja que
            # el servidor procese su `finally` (incluida la baja de la
            # partida) a su propio ritmo. Salir del `with` de más arriba
            # ADEMÁS cancela por la fuerza la tarea de esa conexión del lado
            # del servidor apenas termina el bloque — si hacemos eso antes
            # de que el servidor haya terminado de correr `_resolve_disconnect`
            # (que hace varios awaits reales contra Redis), la cancelación
            # puede interrumpir esa limpieza a mitad de camino y dejar la
            # conexión Redis compartida en un estado inconsistente. Por eso
            # esperamos la confirmación de match_over en ws_a ANTES de
            # dejar que el `__exit__` de ws_b corra.
            ws_b.close()
            match_over = ws_a.receive_json()
        finally:
            ws_b.__exit__(None, None, None)

        assert match_over["type"] == "match_over"
        assert match_over["reason"] == "disconnect"
        assert match_over["winner_user_id"] == str(user_a.id)
