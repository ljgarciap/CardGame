"""Configuración paramétrica del motor de gacha (probabilidades, precio,
bono de rareza) — vive en DB, no hardcodeada en `gacha_service.py`, para que
un superadmin la pueda ajustar sin deploy (ver docs/designs/gacha-engine.md,
sección "Configuración paramétrica").
"""
from decimal import Decimal
from typing import Optional

from sqlalchemy import Enum as SAEnum
from sqlalchemy import ForeignKey, Integer, Numeric
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.enums import Rank, Rarity


class GachaPackLevel(Base):
    __tablename__ = "gacha_pack_levels"

    level: Mapped[int] = mapped_column(Integer, primary_key=True)
    price: Mapped[int] = mapped_column(Integer, nullable=False)
    cards_per_pack: Mapped[int] = mapped_column(Integer, nullable=False)
    guaranteed_min_rank: Mapped[Optional[Rank]] = mapped_column(
        SAEnum(Rank, name="rank"), nullable=True
    )


class GachaRankProbability(Base):
    __tablename__ = "gacha_rank_probabilities"

    level: Mapped[int] = mapped_column(
        Integer, ForeignKey("gacha_pack_levels.level"), primary_key=True
    )
    rank: Mapped[Rank] = mapped_column(SAEnum(Rank, name="rank"), primary_key=True)
    probability: Mapped[Decimal] = mapped_column(Numeric(6, 5), nullable=False)


class GachaRarityProbability(Base):
    __tablename__ = "gacha_rarity_probabilities"

    level: Mapped[int] = mapped_column(
        Integer, ForeignKey("gacha_pack_levels.level"), primary_key=True
    )
    rarity: Mapped[Rarity] = mapped_column(
        SAEnum(Rarity, name="rarity"), primary_key=True
    )
    probability: Mapped[Decimal] = mapped_column(Numeric(6, 5), nullable=False)


class GachaRarityBonus(Base):
    __tablename__ = "gacha_rarity_bonus"

    rarity: Mapped[Rarity] = mapped_column(SAEnum(Rarity, name="rarity"), primary_key=True)
    bonus: Mapped[Decimal] = mapped_column(Numeric(6, 5), nullable=False)
