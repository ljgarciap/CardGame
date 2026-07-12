from datetime import datetime, timedelta, timezone

import pytest

from app.api import auth as auth_module
from app.core.security import decode_access_token
from app.models.user import User

VALID_PASSWORD = "supersecret123"


def _register_payload(**overrides):
    payload = {
        "email": "player1@example.com",
        "password": VALID_PASSWORD,
        "username": "player_one",
        "avatar_id": "avatar_1",
    }
    payload.update(overrides)
    return payload


@pytest.fixture
def sent_emails(monkeypatch):
    sent = []

    async def _fake_send_email(to, subject, body):
        sent.append({"to": to, "subject": subject, "body": body})

    monkeypatch.setattr(auth_module, "send_email", _fake_send_email)
    return sent


def _register_and_verify(client, db_session, **overrides):
    client.post("/api/auth/register", json=_register_payload(**overrides))
    user = (
        db_session.query(User)
        .filter(User.email == overrides.get("email", "player1@example.com"))
        .one()
    )
    user.email_verified = True
    db_session.commit()
    return user


# --- login ---


def test_login_with_correct_credentials_returns_valid_token(
    client, db_session, sent_emails
):
    user = _register_and_verify(client, db_session)

    response = client.post(
        "/api/auth/login",
        json={"email": "player1@example.com", "password": VALID_PASSWORD},
    )

    assert response.status_code == 200
    token = response.json()["access_token"]
    assert decode_access_token(token) == str(user.id)


def test_login_rejects_unverified_user(client, sent_emails):
    client.post("/api/auth/register", json=_register_payload())

    response = client.post(
        "/api/auth/login",
        json={"email": "player1@example.com", "password": VALID_PASSWORD},
    )
    assert response.status_code == 403


def test_login_rejects_wrong_password(client, db_session, sent_emails):
    _register_and_verify(client, db_session)

    response = client.post(
        "/api/auth/login",
        json={"email": "player1@example.com", "password": "wrongpassword"},
    )
    assert response.status_code == 401


def test_login_rejects_unknown_email_with_same_status_as_wrong_password(
    client, db_session, sent_emails
):
    _register_and_verify(client, db_session)
    wrong_password = client.post(
        "/api/auth/login",
        json={"email": "player1@example.com", "password": "wrongpassword"},
    )
    unknown_email = client.post(
        "/api/auth/login",
        json={"email": "doesnotexist@example.com", "password": VALID_PASSWORD},
    )

    assert wrong_password.status_code == unknown_email.status_code == 401
    assert wrong_password.json()["detail"] == unknown_email.json()["detail"]


# --- request password reset ---


def test_request_password_reset_same_message_for_existing_and_unknown_email(
    client, db_session, sent_emails
):
    _register_and_verify(client, db_session)
    sent_emails.clear()

    known = client.post(
        "/api/auth/request-password-reset", json={"email": "player1@example.com"}
    )
    unknown = client.post(
        "/api/auth/request-password-reset", json={"email": "doesnotexist@example.com"}
    )

    assert known.status_code == 200
    assert unknown.status_code == 200
    assert known.json()["message"] == unknown.json()["message"]
    assert len(sent_emails) == 1


# --- reset password ---


def test_reset_password_with_valid_token_changes_password(
    client, db_session, sent_emails
):
    user = _register_and_verify(client, db_session)
    client.post(
        "/api/auth/request-password-reset", json={"email": "player1@example.com"}
    )
    db_session.refresh(user)
    token = user.reset_token

    response = client.post(
        "/api/auth/reset-password",
        json={"token": token, "new_password": "brandnewpassword123"},
    )
    assert response.status_code == 200

    login_with_new_password = client.post(
        "/api/auth/login",
        json={"email": "player1@example.com", "password": "brandnewpassword123"},
    )
    assert login_with_new_password.status_code == 200

    login_with_old_password = client.post(
        "/api/auth/login",
        json={"email": "player1@example.com", "password": VALID_PASSWORD},
    )
    assert login_with_old_password.status_code == 401


def test_reset_password_invalidates_token_after_use(client, db_session, sent_emails):
    user = _register_and_verify(client, db_session)
    client.post(
        "/api/auth/request-password-reset", json={"email": "player1@example.com"}
    )
    db_session.refresh(user)
    token = user.reset_token

    first_attempt = client.post(
        "/api/auth/reset-password",
        json={"token": token, "new_password": "brandnewpassword123"},
    )
    assert first_attempt.status_code == 200

    replay_attempt = client.post(
        "/api/auth/reset-password",
        json={"token": token, "new_password": "anotherpassword456"},
    )
    assert replay_attempt.status_code == 400


def test_reset_password_rejects_invalid_token(client):
    response = client.post(
        "/api/auth/reset-password",
        json={"token": "not-a-real-token", "new_password": "brandnewpassword123"},
    )
    assert response.status_code == 400


def test_reset_password_rejects_expired_token(client, db_session, sent_emails):
    user = _register_and_verify(client, db_session)
    client.post(
        "/api/auth/request-password-reset", json={"email": "player1@example.com"}
    )
    db_session.refresh(user)
    user.reset_token_expires_at = datetime.now(timezone.utc) - timedelta(hours=1)
    db_session.commit()

    response = client.post(
        "/api/auth/reset-password",
        json={"token": user.reset_token, "new_password": "brandnewpassword123"},
    )
    assert response.status_code == 400
