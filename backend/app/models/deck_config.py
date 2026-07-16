"""Configuración paramétrica de mazos guardados (tope de mazos por usuario)
— vive en DB, no hardcodeada en `app/api/decks.py`, para que un superadmin
la pueda ajustar sin deploy (mismo criterio que `gacha_config.py`). Fila
única (id=1): no hay más de un parámetro todavía, no amerita una tabla
key-value genérica.
"""
from sqlalchemy import Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class DeckConfig(Base):
    __tablename__ = "deck_config"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    max_decks_per_user: Mapped[int] = mapped_column(Integer, nullable=False)
