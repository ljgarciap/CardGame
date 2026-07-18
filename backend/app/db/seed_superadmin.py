"""Seed del usuario superadmin de Luis para desarrollo local.

Password genérica a propósito ("12345678") — solo para entornos de
desarrollo local, nunca correr este seed contra un ambiente real. No hay
forma de asignar `is_superadmin` vía API (por seguridad, ver
`app/api/deps.py::get_current_superadmin`), así que el primer superadmin
tiene que nacer sembrado o seteado a mano en la base.

Run con `python -m app.db.seed_superadmin`.
"""
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.user import User

SUPERADMIN_EMAIL = "lujogarpin78@gmail.com"
SUPERADMIN_USERNAME = "lionheartsq"
SUPERADMIN_PASSWORD = "12345678"


def seed_superadmin(session: Session) -> None:
    """Idempotente: no toca nada si el usuario ya existe (por email o
    username, evita chocar con el unique constraint si ya se creó con
    otro username por error)."""
    existing = (
        session.query(User)
        .filter(or_(User.email == SUPERADMIN_EMAIL, User.username == SUPERADMIN_USERNAME))
        .first()
    )
    if existing is not None:
        return

    session.add(
        User(
            email=SUPERADMIN_EMAIL,
            username=SUPERADMIN_USERNAME,
            password_hash=hash_password(SUPERADMIN_PASSWORD),
            avatar_id="avatar_1",
            email_verified=True,
            is_superadmin=True,
        )
    )
    session.commit()


if __name__ == "__main__":
    from app.db.session import SessionLocal

    db = SessionLocal()
    try:
        seed_superadmin(db)
    finally:
        db.close()
