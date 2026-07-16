from app.core.security import create_access_token, hash_password
from app.models.user import User

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


def test_get_deck_config_without_token_is_rejected(client):
    response = client.get("/api/admin/deck-config")
    assert response.status_code == 401


def test_get_deck_config_rejects_regular_user(client, db_session):
    user = _create_user(db_session, is_superadmin=False)
    response = client.get("/api/admin/deck-config", headers=_auth_header(user))
    assert response.status_code == 403


def test_get_deck_config_creates_default_row_for_superadmin(client, db_session):
    """Sin migración corrida (schema armado con create_all en el fixture de
    test), la fila id=1 no existe todavía — el primer GET la crea con el
    default en vez de devolver 500."""
    user = _create_user(db_session, is_superadmin=True)

    response = client.get("/api/admin/deck-config", headers=_auth_header(user))

    assert response.status_code == 200
    assert response.json() == {"max_decks_per_user": 20}


def test_update_deck_config_changes_the_cap(client, db_session):
    user = _create_user(db_session, is_superadmin=True)

    update_response = client.put(
        "/api/admin/deck-config",
        headers=_auth_header(user),
        json={"max_decks_per_user": 5},
    )
    assert update_response.status_code == 200
    assert update_response.json() == {"max_decks_per_user": 5}

    get_response = client.get("/api/admin/deck-config", headers=_auth_header(user))
    assert get_response.json() == {"max_decks_per_user": 5}


def test_update_deck_config_rejects_non_positive_value(client, db_session):
    user = _create_user(db_session, is_superadmin=True)

    response = client.put(
        "/api/admin/deck-config",
        headers=_auth_header(user),
        json={"max_decks_per_user": 0},
    )
    assert response.status_code == 422


def test_update_deck_config_rejects_regular_user(client, db_session):
    user = _create_user(db_session, is_superadmin=False)

    response = client.put(
        "/api/admin/deck-config",
        headers=_auth_header(user),
        json={"max_decks_per_user": 5},
    )
    assert response.status_code == 403
