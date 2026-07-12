from datetime import datetime, timedelta, timezone

import pytest

from app.api import auth as auth_module
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


def test_register_creates_unverified_user_and_sends_email(client, sent_emails):
    response = client.post("/api/auth/register", json=_register_payload())

    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "player1@example.com"
    assert body["username"] == "player_one"
    assert len(sent_emails) == 1
    assert sent_emails[0]["to"] == "player1@example.com"


def test_register_rejects_duplicate_email(client, sent_emails):
    client.post("/api/auth/register", json=_register_payload())
    response = client.post(
        "/api/auth/register", json=_register_payload(username="player_two")
    )
    assert response.status_code == 409


def test_register_rejects_duplicate_username(client, sent_emails):
    client.post("/api/auth/register", json=_register_payload())
    response = client.post(
        "/api/auth/register", json=_register_payload(email="other@example.com")
    )
    assert response.status_code == 409


def test_register_rejects_short_password(client, sent_emails):
    response = client.post(
        "/api/auth/register", json=_register_payload(password="short")
    )
    assert response.status_code == 422


def test_register_rejects_invalid_avatar(client, sent_emails):
    response = client.post(
        "/api/auth/register", json=_register_payload(avatar_id="not-a-preset")
    )
    assert response.status_code == 422


def test_verify_email_with_valid_token(client, db_session, sent_emails):
    client.post("/api/auth/register", json=_register_payload())
    user = db_session.query(User).filter(User.email == "player1@example.com").one()
    token = user.verification_token

    response = client.get(f"/api/auth/verify-email?token={token}")
    assert response.status_code == 200

    db_session.refresh(user)
    assert user.email_verified is True
    assert user.verification_token is None


def test_verify_email_with_invalid_token(client):
    response = client.get("/api/auth/verify-email?token=not-a-real-token")
    assert response.status_code == 400


def test_verify_email_with_expired_token(client, db_session, sent_emails):
    client.post("/api/auth/register", json=_register_payload())
    user = db_session.query(User).filter(User.email == "player1@example.com").one()
    user.verification_token_expires_at = datetime.now(timezone.utc) - timedelta(hours=1)
    db_session.commit()

    response = client.get(f"/api/auth/verify-email?token={user.verification_token}")
    assert response.status_code == 400


def test_resend_verification_same_message_for_existing_and_unknown_email(
    client, sent_emails
):
    client.post("/api/auth/register", json=_register_payload())
    sent_emails.clear()

    known = client.post(
        "/api/auth/resend-verification", json={"email": "player1@example.com"}
    )
    unknown = client.post(
        "/api/auth/resend-verification", json={"email": "doesnotexist@example.com"}
    )

    assert known.status_code == 200
    assert unknown.status_code == 200
    assert known.json()["message"] == unknown.json()["message"]
    # solo el email existente y no verificado recibe un correo de verdad
    assert len(sent_emails) == 1


def test_resend_verification_skips_already_verified_user(
    client, db_session, sent_emails
):
    client.post("/api/auth/register", json=_register_payload())
    user = db_session.query(User).filter(User.email == "player1@example.com").one()
    user.email_verified = True
    db_session.commit()
    sent_emails.clear()

    response = client.post(
        "/api/auth/resend-verification", json={"email": "player1@example.com"}
    )
    assert response.status_code == 200
    assert len(sent_emails) == 0
