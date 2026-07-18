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


# --- grant ---


def test_grant_rejects_regular_user(client, db_session):
    admin = _create_user(db_session, is_superadmin=False)
    target = _create_user(db_session, email="target@example.com", username="target_user")

    response = client.post(
        "/api/admin/coins/grant",
        headers=_auth_header(admin),
        json={"user_identifier": target.username, "amount": 100},
    )
    assert response.status_code == 403


def test_grant_by_username_adds_coins_and_logs_grant(client, db_session):
    admin = _create_user(db_session, is_superadmin=True)
    target = _create_user(db_session, email="target@example.com", username="target_user")

    response = client.post(
        "/api/admin/coins/grant",
        headers=_auth_header(admin),
        json={"user_identifier": "target_user", "amount": 250, "reason": "premio evento"},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["target_coins"] == 250
    assert body["grant"]["target_username"] == "target_user"
    assert body["grant"]["granted_by_username"] == admin.username
    assert body["grant"]["amount"] == 250
    assert body["grant"]["reason"] == "premio evento"

    db_session.refresh(target)
    assert target.coins == 250


def test_grant_by_email_adds_to_existing_balance(client, db_session):
    admin = _create_user(db_session, is_superadmin=True)
    target = _create_user(
        db_session, email="target@example.com", username="target_user", coins=50
    )

    response = client.post(
        "/api/admin/coins/grant",
        headers=_auth_header(admin),
        json={"user_identifier": "target@example.com", "amount": 100},
    )

    assert response.status_code == 201
    assert response.json()["target_coins"] == 150
    db_session.refresh(target)
    assert target.coins == 150


def test_grant_rejects_unknown_user(client, db_session):
    admin = _create_user(db_session, is_superadmin=True)

    response = client.post(
        "/api/admin/coins/grant",
        headers=_auth_header(admin),
        json={"user_identifier": "no-existe", "amount": 100},
    )
    assert response.status_code == 404


def test_grant_rejects_non_positive_amount(client, db_session):
    admin = _create_user(db_session, is_superadmin=True)
    target = _create_user(db_session, email="target@example.com", username="target_user")

    response = client.post(
        "/api/admin/coins/grant",
        headers=_auth_header(admin),
        json={"user_identifier": target.username, "amount": 0},
    )
    assert response.status_code == 422


# --- broadcast ---


def test_broadcast_rejects_regular_user(client, db_session):
    admin = _create_user(db_session, is_superadmin=False)

    response = client.post(
        "/api/admin/coins/broadcast",
        headers=_auth_header(admin),
        json={"amount": 100},
    )
    assert response.status_code == 403


def test_broadcast_adds_coins_to_every_user(client, db_session):
    admin = _create_user(db_session, is_superadmin=True)
    other_a = _create_user(db_session, email="a@example.com", username="user_a", coins=10)
    other_b = _create_user(db_session, email="b@example.com", username="user_b", coins=20)

    response = client.post(
        "/api/admin/coins/broadcast",
        headers=_auth_header(admin),
        json={"amount": 500, "reason": "evento de lanzamiento"},
    )

    assert response.status_code == 201
    body = response.json()
    # admin + other_a + other_b = 3 usuarios en la base para este test
    assert body["recipient_count"] == 3
    assert body["grant"]["target_username"] is None
    assert body["grant"]["recipient_count"] == 3

    db_session.refresh(admin)
    db_session.refresh(other_a)
    db_session.refresh(other_b)
    assert admin.coins == 500
    assert other_a.coins == 510
    assert other_b.coins == 520


def test_broadcast_rejects_non_positive_amount(client, db_session):
    admin = _create_user(db_session, is_superadmin=True)

    response = client.post(
        "/api/admin/coins/broadcast",
        headers=_auth_header(admin),
        json={"amount": -1},
    )
    assert response.status_code == 422


# --- history ---


def test_history_rejects_regular_user(client, db_session):
    admin = _create_user(db_session, is_superadmin=False)

    response = client.get("/api/admin/coins/history", headers=_auth_header(admin))
    assert response.status_code == 403


def test_history_lists_grants_newest_first(client, db_session):
    admin = _create_user(db_session, is_superadmin=True)
    target = _create_user(db_session, email="target@example.com", username="target_user")

    client.post(
        "/api/admin/coins/grant",
        headers=_auth_header(admin),
        json={"user_identifier": target.username, "amount": 100, "reason": "primero"},
    )
    client.post(
        "/api/admin/coins/broadcast",
        headers=_auth_header(admin),
        json={"amount": 50, "reason": "segundo"},
    )

    response = client.get("/api/admin/coins/history", headers=_auth_header(admin))

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 2
    assert body[0]["reason"] == "segundo"
    assert body[0]["target_username"] is None
    assert body[1]["reason"] == "primero"
    assert body[1]["target_username"] == "target_user"
