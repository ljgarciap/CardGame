from pydantic import BaseModel, ConfigDict, Field


class DeckConfigOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    max_decks_per_user: int


class DeckConfigUpdateRequest(BaseModel):
    max_decks_per_user: int = Field(gt=0)
