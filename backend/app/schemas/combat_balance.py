from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.enums import Rank


class RankBaseStatOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    rank: Rank
    base_attack: int
    base_defense: int


class CombatBalanceConfigOut(BaseModel):
    starting_life: int
    rank_base_stats: list[RankBaseStatOut]


class RankBaseStatIn(BaseModel):
    rank: Rank
    base_attack: int = Field(gt=0)
    base_defense: int = Field(gt=0)


class CombatBalanceConfigUpdateRequest(BaseModel):
    starting_life: int = Field(gt=0)
    rank_base_stats: list[RankBaseStatIn]

    @field_validator("rank_base_stats")
    @classmethod
    def _require_every_rank_exactly_once(cls, value: list[RankBaseStatIn]) -> list[RankBaseStatIn]:
        ranks = [entry.rank for entry in value]
        if set(ranks) != set(Rank) or len(ranks) != len(set(Rank)):
            raise ValueError(f"rank_base_stats debe traer exactamente un valor por rango: {[r.value for r in Rank]}")
        return value
