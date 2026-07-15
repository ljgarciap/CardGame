import uuid

from sqlalchemy import Enum as SAEnum
from sqlalchemy import Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.enums import Faction, Rank


class CardArchetype(Base):
    __tablename__ = "card_archetypes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    faction: Mapped[Faction] = mapped_column(
        SAEnum(Faction, name="faction"), nullable=False
    )
    rank: Mapped[Rank] = mapped_column(SAEnum(Rank, name="rank"), nullable=False)
    base_attack: Mapped[int] = mapped_column(Integer, nullable=False)
    base_defense: Mapped[int] = mapped_column(Integer, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
