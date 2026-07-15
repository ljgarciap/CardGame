import uuid

from pydantic import BaseModel

from app.models.enums import Faction, Rank, Rarity


class PackOpenRequest(BaseModel):
    level: int


class CardOut(BaseModel):
    archetype_id: uuid.UUID
    name: str
    faction: Faction
    rank: Rank
    rarity: Rarity
    attack: int
    defense: int


class PackOpenResponse(BaseModel):
    cards: list[CardOut]
    remaining_coins: int
