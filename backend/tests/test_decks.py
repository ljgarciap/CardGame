import threading

from app.core.security import create_access_token, hash_password
from app.models.card_archetype import CardArchetype
from app.models.deck import Deck
from app.models.deck_config import DeckConfig
from app.models.enums import Faction, Rank, Rarity
from app.models.player_card import PlayerCard
from app.models.user import User
from app.services.match_engine import DECK_SIZE

VALID_PASSWORD = "supersecret123"


def _create_user(db_session, **overrides):
    defaults = {
        "email": "player1@example.com",
        "username": "player_one",
        "avatar_id": "avatar_1",
        "email_verified": True,
        "coins": 0,
    }
    defaults.update(overrides)
    user = User(password_hash=hash_password(VALID_PASSWORD), **defaults)
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _auth_header(user) -> dict:
    token = create_access_token(subject=str(user.id))
    return {"Authorization": f"Bearer {token}"}


def _give_cards(db_session, user, count=DECK_SIZE, *, name="Achilles"):
    archetype = CardArchetype(
        name=name,
        faction=Faction.greek,
        rank=Rank.hero,
        description="test",
    )
    db_session.add(archetype)
    db_session.flush()
    cards = []
    for _ in range(count):
        card = PlayerCard(
            user_id=user.id,
            archetype_id=archetype.id,
            rarity=Rarity.common,
            attack=30,
            defense=30,
        )
        db_session.add(card)
        cards.append(card)
    db_session.commit()
    for card in cards:
        db_session.refresh(card)
    return cards


def test_list_decks_without_token_is_rejected(client):
    response = client.get("/api/decks")
    assert response.status_code == 401


def test_create_deck_without_token_is_rejected(client):
    response = client.post("/api/decks", json={"name": "x", "player_card_ids": []})
    assert response.status_code == 401


def test_create_deck_with_exactly_10_owned_cards_succeeds(client, db_session):
    user = _create_user(db_session)
    cards = _give_cards(db_session, user)

    response = client.post(
        "/api/decks",
        headers=_auth_header(user),
        json={"name": "Mazo Griego", "player_card_ids": [str(c.id) for c in cards]},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Mazo Griego"
    assert len(body["cards"]) == DECK_SIZE
    assert {c["player_card_id"] for c in body["cards"]} == {str(c.id) for c in cards}


def test_create_deck_with_wrong_card_count_is_rejected(client, db_session):
    user = _create_user(db_session)
    cards = _give_cards(db_session, user, count=5)

    response = client.post(
        "/api/decks",
        headers=_auth_header(user),
        json={"name": "Incompleto", "player_card_ids": [str(c.id) for c in cards]},
    )

    assert response.status_code == 400


def test_create_deck_with_duplicate_card_ids_is_rejected(client, db_session):
    user = _create_user(db_session)
    cards = _give_cards(db_session, user, count=9)
    ids = [str(c.id) for c in cards] + [str(cards[0].id)]  # 10 ids, uno repetido

    response = client.post(
        "/api/decks",
        headers=_auth_header(user),
        json={"name": "Repetido", "player_card_ids": ids},
    )

    assert response.status_code == 400


def test_create_deck_with_cards_not_owned_is_rejected(client, db_session):
    user_a = _create_user(db_session, email="a@example.com", username="alice")
    user_b = _create_user(db_session, email="b@example.com", username="bob")
    cards_a = _give_cards(db_session, user_a, count=9)
    cards_b = _give_cards(db_session, user_b, count=1)
    ids = [str(c.id) for c in cards_a] + [str(cards_b[0].id)]

    response = client.post(
        "/api/decks",
        headers=_auth_header(user_a),
        json={"name": "Ajeno", "player_card_ids": ids},
    )

    assert response.status_code == 400


def test_list_decks_returns_only_the_caller_decks(client, db_session):
    user_a = _create_user(db_session, email="a@example.com", username="alice")
    user_b = _create_user(db_session, email="b@example.com", username="bob")
    cards_a = _give_cards(db_session, user_a)
    cards_b = _give_cards(db_session, user_b)

    client.post(
        "/api/decks",
        headers=_auth_header(user_a),
        json={"name": "De Alice", "player_card_ids": [str(c.id) for c in cards_a]},
    )
    client.post(
        "/api/decks",
        headers=_auth_header(user_b),
        json={"name": "De Bob", "player_card_ids": [str(c.id) for c in cards_b]},
    )

    response = client.get("/api/decks", headers=_auth_header(user_a))

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["name"] == "De Alice"


def test_update_deck_renames_and_replaces_cards(client, db_session):
    user = _create_user(db_session)
    original_cards = _give_cards(db_session, user, count=10, name="Achilles")
    new_cards = _give_cards(db_session, user, count=10, name="Odin")

    create_response = client.post(
        "/api/decks",
        headers=_auth_header(user),
        json={"name": "Original", "player_card_ids": [str(c.id) for c in original_cards]},
    )
    deck_id = create_response.json()["id"]

    update_response = client.put(
        f"/api/decks/{deck_id}",
        headers=_auth_header(user),
        json={"name": "Actualizado", "player_card_ids": [str(c.id) for c in new_cards]},
    )

    assert update_response.status_code == 200
    body = update_response.json()
    assert body["name"] == "Actualizado"
    assert {c["player_card_id"] for c in body["cards"]} == {str(c.id) for c in new_cards}


def test_update_deck_owned_by_another_user_is_rejected(client, db_session):
    user_a = _create_user(db_session, email="a@example.com", username="alice")
    user_b = _create_user(db_session, email="b@example.com", username="bob")
    cards_a = _give_cards(db_session, user_a)

    create_response = client.post(
        "/api/decks",
        headers=_auth_header(user_a),
        json={"name": "De Alice", "player_card_ids": [str(c.id) for c in cards_a]},
    )
    deck_id = create_response.json()["id"]

    response = client.put(
        f"/api/decks/{deck_id}",
        headers=_auth_header(user_b),
        json={"name": "Robado", "player_card_ids": [str(c.id) for c in cards_a]},
    )

    assert response.status_code == 404


def test_delete_deck_removes_it_and_its_cards(client, db_session):
    user = _create_user(db_session)
    cards = _give_cards(db_session, user)
    create_response = client.post(
        "/api/decks",
        headers=_auth_header(user),
        json={"name": "A borrar", "player_card_ids": [str(c.id) for c in cards]},
    )
    deck_id = create_response.json()["id"]

    delete_response = client.delete(f"/api/decks/{deck_id}", headers=_auth_header(user))
    assert delete_response.status_code == 204

    list_response = client.get("/api/decks", headers=_auth_header(user))
    assert list_response.json() == []

    db_session.expire_all()
    assert db_session.get(Deck, deck_id) is None


def test_delete_deck_owned_by_another_user_is_rejected(client, db_session):
    user_a = _create_user(db_session, email="a@example.com", username="alice")
    user_b = _create_user(db_session, email="b@example.com", username="bob")
    cards_a = _give_cards(db_session, user_a)
    create_response = client.post(
        "/api/decks",
        headers=_auth_header(user_a),
        json={"name": "De Alice", "player_card_ids": [str(c.id) for c in cards_a]},
    )
    deck_id = create_response.json()["id"]

    response = client.delete(f"/api/decks/{deck_id}", headers=_auth_header(user_b))

    assert response.status_code == 404


def test_create_deck_beyond_max_per_user_is_rejected(client, db_session):
    user = _create_user(db_session)
    # 20 mazos independientes (10 cartas cada uno, todas del mismo usuario,
    # reusar player_card_id entre mazos distintos está permitido).
    cards = _give_cards(db_session, user)
    ids = [str(c.id) for c in cards]

    for i in range(20):
        response = client.post(
            "/api/decks", headers=_auth_header(user), json={"name": f"Mazo {i}", "player_card_ids": ids}
        )
        assert response.status_code == 201

    response = client.post(
        "/api/decks", headers=_auth_header(user), json={"name": "Mazo 21", "player_card_ids": ids}
    )
    assert response.status_code == 400


def test_create_deck_concurrent_requests_never_exceed_max_per_user(client, db_session):
    """Regresión del TOCTOU real de la revisión senior 793abf4: sin el lock
    de fila sobre `User`, N requests concurrentes leen el mismo
    `existing_count` antes de que cualquiera inserte, y todas pasan la
    validación del tope. Con `max_decks_per_user=1` y 5 requests a la vez,
    solo una debe poder crear el mazo."""
    user = _create_user(db_session)
    cards = _give_cards(db_session, user)
    ids = [str(c.id) for c in cards]
    db_session.add(DeckConfig(id=1, max_decks_per_user=1))
    db_session.commit()

    headers = _auth_header(user)
    statuses: list[int] = []
    lock = threading.Lock()

    def _create(i: int) -> None:
        response = client.post(
            "/api/decks", headers=headers, json={"name": f"Mazo {i}", "player_card_ids": ids}
        )
        with lock:
            statuses.append(response.status_code)

    threads = [threading.Thread(target=_create, args=(i,)) for i in range(5)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert statuses.count(201) == 1
    assert statuses.count(400) == 4

    list_response = client.get("/api/decks", headers=headers)
    assert len(list_response.json()) == 1
