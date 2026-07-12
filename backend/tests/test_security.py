from datetime import datetime, timedelta, timezone

import pytest
from jose import jwt

from app.core.config import settings
from app.core.security import (
    ALGORITHM,
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)


def test_hash_password_does_not_return_plaintext():
    assert hash_password("supersecret123") != "supersecret123"


def test_verify_password_accepts_correct_password():
    hashed = hash_password("supersecret123")
    assert verify_password("supersecret123", hashed) is True


def test_verify_password_rejects_wrong_password():
    hashed = hash_password("supersecret123")
    assert verify_password("wrongpassword", hashed) is False


def test_hash_password_rejects_over_72_bytes():
    with pytest.raises(ValueError):
        hash_password("a" * 73)


def test_verify_password_rejects_over_72_bytes_without_raising():
    hashed = hash_password("a" * 72)
    assert verify_password("a" * 73, hashed) is False


def test_access_token_round_trip_returns_subject():
    token = create_access_token(subject="user-123")
    assert decode_access_token(token) == "user-123"


def test_decode_access_token_rejects_tampered_token():
    token = create_access_token(subject="user-123")
    assert decode_access_token(token + "tampered") is None


def test_decode_access_token_rejects_expired_token():
    expired_payload = {
        "sub": "user-123",
        "exp": datetime.now(timezone.utc) - timedelta(days=1),
    }
    expired_token = jwt.encode(expired_payload, settings.jwt_secret_key, algorithm=ALGORITHM)
    assert decode_access_token(expired_token) is None
