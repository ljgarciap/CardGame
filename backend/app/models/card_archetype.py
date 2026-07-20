import uuid

from sqlalchemy import Enum as SAEnum
from sqlalchemy import String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.enums import Faction, Rank


class CardArchetype(Base):
    """El ataque/defensa base de una carta NO vive acá — es idéntico para
    toda carta del mismo rango (Aquiles y Bochica, ambos Hero, valen lo
    mismo), así que la fuente de verdad es `RankBaseStat`
    (app/models/combat_balance.py), una fila por Rank, no 20+ filas de
    archetype repitiendo el mismo número. Ver gacha_service._calculate_stats."""

    __tablename__ = "card_archetypes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    faction: Mapped[Faction] = mapped_column(
        SAEnum(Faction, name="faction"), nullable=False
    )
    rank: Mapped[Rank] = mapped_column(SAEnum(Rank, name="rank"), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
