from app.core.security import create_access_token, hash_password
from app.models.card_archetype import CardArchetype
from app.models.enums import Faction, Rank, Rarity
from app.models.player_card import PlayerCard
from app.models.user import User

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


def _give_card(db_session, user, *, name="Achilles"):
    archetype = CardArchetype(
        name=name,
        faction=Faction.greek,
        rank=Rank.hero,
        base_attack=30,
        base_defense=30,
        description="test",
    )
    db_session.add(archetype)
    db_session.flush()
    card = PlayerCard(
        user_id=user.id,
        archetype_id=archetype.id,
        rarity=Rarity.common,
        attack=30,
        defense=30,
    )
    db_session.add(card)
    db_session.commit()
    db_session.refresh(card)
    return card


def test_list_my_cards_without_token_is_rejected(client):
    response = client.get("/api/cards/mine")
    assert response.status_code == 401


def test_list_my_cards_returns_only_the_caller_owned_cards(client, db_session):
    user_a = _create_user(db_session, email="a@example.com", username="alice")
    user_b = _create_user(db_session, email="b@example.com", username="bob")
    card_a = _give_card(db_session, user_a, name="Achilles")
    _give_card(db_session, user_b, name="Odin")  # de otro usuario, no debe aparecer

    response = client.get("/api/cards/mine", headers=_auth_header(user_a))

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["player_card_id"] == str(card_a.id)
    assert body[0]["name"] == "Achilles"
    assert set(body[0].keys()) == {
        "player_card_id", "archetype_id", "name", "faction", "rank", "rarity", "attack", "defense",
    }


def test_list_my_cards_returns_empty_list_when_no_cards_owned(client, db_session):
    user = _create_user(db_session)

    response = client.get("/api/cards/mine", headers=_auth_header(user))

    assert response.status_code == 200
    assert response.json() == []
