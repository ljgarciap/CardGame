from app.core.security import create_access_token, hash_password
from app.models.user import User

VALID_PASSWORD = "supersecret123"

DEFAULT_RANK_BASE_STATS = [
    {"rank": "hero", "base_attack": 2, "base_defense": 2},
    {"rank": "demigod", "base_attack": 3, "base_defense": 3},
    {"rank": "minor_god", "base_attack": 4, "base_defense": 4},
    {"rank": "major_god", "base_attack": 6, "base_defense": 6},
]


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


def _sorted_by_rank(rank_base_stats: list[dict]) -> list[dict]:
    order = {"hero": 0, "demigod": 1, "minor_god": 2, "major_god": 3}
    return sorted(rank_base_stats, key=lambda r: order[r["rank"]])


def test_get_combat_balance_without_token_is_rejected(client):
    response = client.get("/api/admin/combat-balance")
    assert response.status_code == 401


def test_get_combat_balance_rejects_regular_user(client, db_session):
    user = _create_user(db_session, is_superadmin=False)
    response = client.get("/api/admin/combat-balance", headers=_auth_header(user))
    assert response.status_code == 403


def test_get_combat_balance_creates_default_rows_for_superadmin(client, db_session):
    """Sin migración corrida (schema armado con create_all en el fixture de
    test), ni la fila de starting_life ni las de rank_base_stats existen
    todavía -- el primer GET las crea con el default en vez de devolver 500."""
    user = _create_user(db_session, is_superadmin=True)

    response = client.get("/api/admin/combat-balance", headers=_auth_header(user))

    assert response.status_code == 200
    body = response.json()
    assert body["starting_life"] == 20
    assert _sorted_by_rank(body["rank_base_stats"]) == DEFAULT_RANK_BASE_STATS


def test_update_combat_balance_changes_starting_life_and_rank_stats(client, db_session):
    user = _create_user(db_session, is_superadmin=True)
    payload = {
        "starting_life": 30,
        "rank_base_stats": [
            {"rank": "hero", "base_attack": 5, "base_defense": 5},
            {"rank": "demigod", "base_attack": 7, "base_defense": 7},
            {"rank": "minor_god", "base_attack": 10, "base_defense": 10},
            {"rank": "major_god", "base_attack": 13, "base_defense": 13},
        ],
    }

    update_response = client.put(
        "/api/admin/combat-balance", headers=_auth_header(user), json=payload
    )
    assert update_response.status_code == 200
    body = update_response.json()
    assert body["starting_life"] == 30
    assert _sorted_by_rank(body["rank_base_stats"]) == _sorted_by_rank(payload["rank_base_stats"])

    get_response = client.get("/api/admin/combat-balance", headers=_auth_header(user))
    assert get_response.json()["starting_life"] == 30


def test_update_combat_balance_rejects_non_positive_starting_life(client, db_session):
    user = _create_user(db_session, is_superadmin=True)
    payload = {"starting_life": 0, "rank_base_stats": DEFAULT_RANK_BASE_STATS}

    response = client.put("/api/admin/combat-balance", headers=_auth_header(user), json=payload)
    assert response.status_code == 422


def test_update_combat_balance_rejects_missing_rank(client, db_session):
    user = _create_user(db_session, is_superadmin=True)
    payload = {
        "starting_life": 20,
        "rank_base_stats": [r for r in DEFAULT_RANK_BASE_STATS if r["rank"] != "major_god"],
    }

    response = client.put("/api/admin/combat-balance", headers=_auth_header(user), json=payload)
    assert response.status_code == 422


def test_update_combat_balance_rejects_regular_user(client, db_session):
    user = _create_user(db_session, is_superadmin=False)
    payload = {"starting_life": 20, "rank_base_stats": DEFAULT_RANK_BASE_STATS}

    response = client.put("/api/admin/combat-balance", headers=_auth_header(user), json=payload)
    assert response.status_code == 403
