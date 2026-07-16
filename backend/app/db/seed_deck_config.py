"""Seed de la configuración paramétrica de mazos guardados (tope de mazos
por usuario) — mismo valor que estaba hardcodeado en `app/api/decks.py`
antes de la revisión 2026-07-16, el seed no cambia el comportamiento, solo
lo vuelve ajustable sin deploy. Run con `python -m app.db.seed_deck_config`.
"""
from sqlalchemy.orm import Session

from app.models.deck_config import DeckConfig

DEFAULT_MAX_DECKS_PER_USER = 20


def seed_deck_config(session: Session) -> None:
    """Idempotente: no toca nada si ya hay config sembrada (para no pisar
    un valor que un superadmin ya haya ajustado)."""
    if session.get(DeckConfig, 1) is not None:
        return
    session.add(DeckConfig(id=1, max_decks_per_user=DEFAULT_MAX_DECKS_PER_USER))
    session.commit()


if __name__ == "__main__":
    from app.db.session import SessionLocal

    db = SessionLocal()
    try:
        seed_deck_config(db)
    finally:
        db.close()
