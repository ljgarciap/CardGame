import uuid

from pydantic import BaseModel

from app.models.enums import Faction, Rank, Rarity


class OwnedCardOut(BaseModel):
    player_card_id: uuid.UUID
    archetype_id: uuid.UUID
    name: str
    faction: Faction
    rank: Rank
    rarity: Rarity
    attack: int
    defense: int
