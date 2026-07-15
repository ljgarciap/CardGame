from app.core.security import create_access_token, hash_password
from app.db.seed_gacha_config import seed_gacha_config
from app.models.user import User
from app.services.gacha_service import get_pack_price

VALID_PASSWORD = "supersecret123"


def _create_user(db_session, is_superadmin: bool = False, **overrides):
    defaults = {
        "email": "admin_check@example.com" if is_superadmin else "regular@example.com",
        "username": "admin_user" if is_superadmin else "regular_user",
        "avatar_id": "avatar_1",
        "email_verified": True,
        "is_superadmin": is_superadmin,
    }
    defaults.update(overrides)
    user = User(password_hash=hash_password(VALID_PASSWORD), **defaults)
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _auth_header(user) -> dict:
    return {"Authorization": f"Bearer {create_access_token(str(user.id))}"}


def test_get_config_without_token_is_rejected(client, db_session):
    seed_gacha_config(db_session)
    response = client.get("/api/admin/gacha-config")
    assert response.status_code == 401


def test_get_config_rejects_regular_user(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=False)

    response = client.get("/api/admin/gacha-config", headers=_auth_header(user))
    assert response.status_code == 403


def test_get_config_returns_full_dump_for_superadmin(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.get("/api/admin/gacha-config", headers=_auth_header(user))

    assert response.status_code == 200
    body = response.json()
    assert len(body["pack_levels"]) == 5
    assert len(body["rank_probabilities"]) == 5
    assert len(body["rarity_probabilities"]) == 5
    assert set(body["rarity_bonus"].keys()) == {"common", "rare", "epic", "legendary"}


def test_update_pack_level_price(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/pack-levels/1",
        headers=_auth_header(user),
        json={"price": 1500, "cards_per_pack": 5, "guaranteed_min_rank": None},
    )

    assert response.status_code == 200
    assert response.json()["price"] == 1500


def test_update_pack_level_rejects_regular_user(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=False)

    response = client.put(
        "/api/admin/gacha-config/pack-levels/1",
        headers=_auth_header(user),
        json={"price": 1500, "cards_per_pack": 5, "guaranteed_min_rank": None},
    )
    assert response.status_code == 403


def test_update_pack_level_nonexistent_level_is_404(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/pack-levels/99",
        headers=_auth_header(user),
        json={"price": 1000, "cards_per_pack": 5, "guaranteed_min_rank": None},
    )
    assert response.status_code == 404


def test_update_pack_level_rejects_zero_or_negative_price(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    for bad_price in (0, -1000):
        response = client.put(
            "/api/admin/gacha-config/pack-levels/1",
            headers=_auth_header(user),
            json={"price": bad_price, "cards_per_pack": 5, "guaranteed_min_rank": None},
        )
        assert response.status_code == 400, bad_price


def test_update_pack_level_rejects_zero_or_negative_cards_per_pack(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    for bad_count in (0, -3):
        response = client.put(
            "/api/admin/gacha-config/pack-levels/1",
            headers=_auth_header(user),
            json={"price": 1000, "cards_per_pack": bad_count, "guaranteed_min_rank": None},
        )
        assert response.status_code == 400, bad_count


def test_update_pack_level_cards_per_pack_changes_pack_size(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/pack-levels/1",
        headers=_auth_header(user),
        json={"price": 1000, "cards_per_pack": 8, "guaranteed_min_rank": None},
    )
    assert response.status_code == 200
    assert response.json()["cards_per_pack"] == 8


def test_update_rank_probabilities_valid_sum(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/rank-probabilities/1",
        headers=_auth_header(user),
        json={"hero": "0.5", "demigod": "0.3", "minor_god": "0.15", "major_god": "0.05"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["hero"] == "0.5"


def test_update_rank_probabilities_rejects_invalid_sum(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/rank-probabilities/1",
        headers=_auth_header(user),
        json={"hero": "0.5", "demigod": "0.3", "minor_god": "0.15", "major_god": "0.5"},
    )

    assert response.status_code == 400


def test_update_rank_probabilities_rejects_negative_value_even_if_sum_is_valid(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    # Suma exacta de 1.0, pero "hero" es negativo -- debe rechazarse igual.
    response = client.put(
        "/api/admin/gacha-config/rank-probabilities/1",
        headers=_auth_header(user),
        json={"hero": "-0.2", "demigod": "0.4", "minor_god": "0.4", "major_god": "0.4"},
    )

    assert response.status_code == 400
    # El mensaje debe ser legible ("hero: -0.2"), no la repr() de Python del
    # enum/Decimal ("{<Rank.hero: 'hero'>: Decimal('-0.2')}").
    detail = response.json()["detail"]
    assert "hero: -0.2" in detail
    assert "Rank." not in detail
    assert "Decimal(" not in detail


def test_update_rarity_probabilities_rejects_invalid_sum(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/rarity-probabilities/1",
        headers=_auth_header(user),
        json={"common": "0.5", "rare": "0.5", "epic": "0.5", "legendary": "0.5"},
    )

    assert response.status_code == 400


def test_update_rarity_probabilities_rejects_negative_value_even_if_sum_is_valid(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/rarity-probabilities/1",
        headers=_auth_header(user),
        json={"common": "-0.2", "rare": "0.4", "epic": "0.4", "legendary": "0.4"},
    )

    assert response.status_code == 400


def test_update_rarity_bonus_rejects_negative_value(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/rarity-bonus",
        headers=_auth_header(user),
        json={"common": "0.00", "rare": "-2.0", "epic": "0.25", "legendary": "0.40"},
    )

    assert response.status_code == 400


def test_update_rarity_bonus(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/rarity-bonus",
        headers=_auth_header(user),
        json={"common": "0.00", "rare": "0.15", "epic": "0.25", "legendary": "0.40"},
    )

    assert response.status_code == 200
    assert response.json()["rare"] == "0.15"


def test_gacha_service_reflects_price_update_without_stale_cache(client, db_session):
    seed_gacha_config(db_session)
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/gacha-config/pack-levels/2",
        headers=_auth_header(user),
        json={"price": 2500, "cards_per_pack": 5, "guaranteed_min_rank": None},
    )
    assert response.status_code == 200

    assert get_pack_price(db_session, 2) == 2500
