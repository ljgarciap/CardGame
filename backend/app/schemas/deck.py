import uuid
from datetime import datetime
from typing import List

from pydantic import BaseModel, Field

from app.schemas.collection import OwnedCardOut


class DeckCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    player_card_ids: List[uuid.UUID]


class DeckUpdateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    player_card_ids: List[uuid.UUID]


class DeckOut(BaseModel):
    id: uuid.UUID
    name: str
    cards: List[OwnedCardOut]
    created_at: datetime
    updated_at: datetime
