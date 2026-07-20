"""Seed de usuarios de prueba regulares (no superadmin) para testear la
app con varias cuentas reales — mismo criterio de password genérica que
seed_superadmin.py, solo para desarrollo/VPS de prueba, nunca correr
contra un ambiente real.

Run con `python -m app.db.seed_test_users`.
"""
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.user import User

TEST_USER_PASSWORD = "12345678"

TEST_USERS = [
    ("jr@test.co", "jr"),
    ("vero@test.co", "vero"),
    ("zaida@test.co", "zaida"),
    ("luis@test.co", "luis"),
]


def seed_test_users(session: Session) -> None:
    """Idempotente por usuario individual (email o username), no por "¿hay
    algo sembrado?" -- mismo criterio que seed_archetypes: si el catálogo
    de usuarios de prueba crece más adelante, una corrida nueva siembra
    solo los que faltan sin duplicar ni pisar los que ya existían."""
    for email, username in TEST_USERS:
        existing = (
            session.query(User)
            .filter(or_(User.email == email, User.username == username))
            .first()
        )
        if existing is not None:
            continue

        session.add(
            User(
                email=email,
                username=username,
                password_hash=hash_password(TEST_USER_PASSWORD),
                avatar_id="avatar_1",
                email_verified=True,
                is_superadmin=False,
            )
        )
    session.commit()


if __name__ == "__main__":
    from app.db.session import SessionLocal

    db = SessionLocal()
    try:
        seed_test_users(db)
    finally:
        db.close()
