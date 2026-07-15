from app.core.security import create_access_token, hash_password
from app.db.seed import seed_archetypes
from app.db.seed_gacha_config import seed_gacha_config
from app.models.player_card import PlayerCard
from app.models.user import User

VALID_PASSWORD = "supersecret123"


def _create_user(db_session, **overrides):
    defaults = {
        "email": "player1@example.com",
        "username": "player_one",
        "avatar_id": "avatar_1",
        "email_verified": True,
        "coins": 10000,
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


def test_open_pack_without_token_is_rejected(client):
    response = client.post("/api/packs/open", json={"level": 1})
    assert response.status_code == 401


def test_open_pack_with_invalid_level_is_rejected(client, db_session):
    seed_archetypes(db_session)
    seed_gacha_config(db_session)
    user = _create_user(db_session)

    response = client.post(
        "/api/packs/open", headers=_auth_header(user), json={"level": 6}
    )
    assert response.status_code == 400


def test_open_pack_returns_five_cards_and_discounts_coins(client, db_session):
    seed_archetypes(db_session)
    seed_gacha_config(db_session)
    user = _create_user(db_session)

    response = client.post(
        "/api/packs/open", headers=_auth_header(user), json={"level": 1}
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["cards"]) == 5
    assert body["remaining_coins"] == 10000 - 1000
    for card in body["cards"]:
        assert set(card.keys()) == {
            "archetype_id", "name", "faction", "rank", "rarity", "attack", "defense",
        }

    stored_cards = (
        db_session.query(PlayerCard).filter_by(user_id=user.id).all()
    )
    assert len(stored_cards) == 5


def test_open_pack_with_insufficient_coins_is_rejected_without_side_effects(client, db_session):
    seed_archetypes(db_session)
    seed_gacha_config(db_session)
    user = _create_user(db_session, coins=500)

    response = client.post(
        "/api/packs/open", headers=_auth_header(user), json={"level": 1}
    )

    assert response.status_code == 402

    db_session.refresh(user)
    assert user.coins == 500
    stored_cards = (
        db_session.query(PlayerCard).filter_by(user_id=user.id).all()
    )
    assert len(stored_cards) == 0


def test_open_pack_price_scales_with_level(client, db_session):
    seed_archetypes(db_session)
    seed_gacha_config(db_session)
    user = _create_user(db_session, coins=5000)

    response = client.post(
        "/api/packs/open", headers=_auth_header(user), json={"level": 5}
    )

    assert response.status_code == 200
    assert response.json()["remaining_coins"] == 5000 - 5000
