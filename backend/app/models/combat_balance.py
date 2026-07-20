"""Configuración paramétrica de balance de combate (vida inicial, ataque
base por rango) — vive en DB, no hardcodeada en match_engine.py/
gacha_service.py, para que un superadmin la pueda ajustar sin deploy
(mismo criterio que gacha_config.py/deck_config.py). `base_attack`/
`base_defense` reemplazan a las columnas que antes vivían en
CardArchetype: eran idénticas para toda carta del mismo rango (ej. Aquiles
y Bochica, ambos Hero, tenían el mismo valor) — una fila por Rank acá es
la fuente de verdad única, en vez de 20+ filas de archetype repitiendo el
mismo número.
"""
from sqlalchemy import Integer
from sqlalchemy import Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.enums import Rank


class CombatBalanceConfig(Base):
    __tablename__ = "combat_balance_config"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    starting_life: Mapped[int] = mapped_column(Integer, nullable=False)


class RankBaseStat(Base):
    __tablename__ = "rank_base_stats"

    rank: Mapped[Rank] = mapped_column(SAEnum(Rank, name="rank"), primary_key=True)
    base_attack: Mapped[int] = mapped_column(Integer, nullable=False)
    base_defense: Mapped[int] = mapped_column(Integer, nullable=False)
