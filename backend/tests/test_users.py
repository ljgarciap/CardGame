from app.core.security import create_access_token
from app.models.user import User

VALID_PASSWORD = "supersecret123"


def _create_user(db_session, **overrides):
    from app.core.security import hash_password

    defaults = {
        "email": "player1@example.com",
        "username": "player_one",
        "avatar_id": "avatar_1",
        "email_verified": True,
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


def test_get_me_without_token_is_rejected(client):
    response = client.get("/api/users/me")
    assert response.status_code == 401


def test_get_me_with_garbage_token_is_rejected(client):
    response = client.get(
        "/api/users/me", headers={"Authorization": "Bearer not-a-real-token"}
    )
    assert response.status_code == 401


def test_get_me_with_valid_token_returns_profile(client, db_session):
    user = _create_user(db_session)

    response = client.get("/api/users/me", headers=_auth_header(user))

    assert response.status_code == 200
    body = response.json()
    assert body["email"] == "player1@example.com"
    assert body["username"] == "player_one"
    assert body["avatar_id"] == "avatar_1"
    assert body["coins"] == 0
    assert body["email_verified"] is True


def test_get_me_for_deleted_user_is_rejected(client, db_session):
    user = _create_user(db_session)
    header = _auth_header(user)
    db_session.delete(user)
    db_session.commit()

    response = client.get("/api/users/me", headers=header)
    assert response.status_code == 401


def test_patch_me_updates_username(client, db_session):
    user = _create_user(db_session)

    response = client.patch(
        "/api/users/me", headers=_auth_header(user), json={"username": "new_name"}
    )

    assert response.status_code == 200
    assert response.json()["username"] == "new_name"


def test_patch_me_rejects_duplicate_username(client, db_session):
    _create_user(db_session, email="other@example.com", username="taken_name")
    user = _create_user(db_session, email="player1@example.com", username="player_one")

    response = client.patch(
        "/api/users/me", headers=_auth_header(user), json={"username": "taken_name"}
    )
    assert response.status_code == 409


def test_patch_me_rejects_invalid_avatar(client, db_session):
    user = _create_user(db_session)

    response = client.patch(
        "/api/users/me", headers=_auth_header(user), json={"avatar_id": "not-a-preset"}
    )
    assert response.status_code == 422
