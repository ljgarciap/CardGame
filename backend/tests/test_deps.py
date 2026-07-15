import pytest
from fastapi import HTTPException

from app.api.deps import get_current_superadmin
from app.core.security import hash_password
from app.models.user import User


def _make_user(db_session, is_superadmin: bool) -> User:
    user = User(
        email="admin_check@example.com" if is_superadmin else "regular@example.com",
        password_hash=hash_password("supersecret123"),
        username="admin_user" if is_superadmin else "regular_user",
        avatar_id="avatar_1",
        email_verified=True,
        is_superadmin=is_superadmin,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def test_get_current_superadmin_rejects_regular_user(db_session):
    user = _make_user(db_session, is_superadmin=False)

    with pytest.raises(HTTPException) as exc_info:
        get_current_superadmin(current_user=user)

    assert exc_info.value.status_code == 403


def test_get_current_superadmin_allows_superadmin(db_session):
    user = _make_user(db_session, is_superadmin=True)

    result = get_current_superadmin(current_user=user)

    assert result is user
