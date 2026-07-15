from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict

from app.models.enums import Rank, Rarity


class PackLevelOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    level: int
    price: int
    guaranteed_min_rank: Optional[Rank]


class PackLevelUpdateRequest(BaseModel):
    price: int
    guaranteed_min_rank: Optional[Rank] = None


class RankProbabilitiesOut(BaseModel):
    level: int
    hero: Decimal
    demigod: Decimal
    minor_god: Decimal
    major_god: Decimal


class RankProbabilitiesUpdateRequest(BaseModel):
    hero: Decimal
    demigod: Decimal
    minor_god: Decimal
    major_god: Decimal


class RarityProbabilitiesOut(BaseModel):
    level: int
    common: Decimal
    rare: Decimal
    epic: Decimal
    legendary: Decimal


class RarityProbabilitiesUpdateRequest(BaseModel):
    common: Decimal
    rare: Decimal
    epic: Decimal
    legendary: Decimal


class RarityBonusOut(BaseModel):
    common: Decimal
    rare: Decimal
    epic: Decimal
    legendary: Decimal


class RarityBonusUpdateRequest(BaseModel):
    common: Decimal
    rare: Decimal
    epic: Decimal
    legendary: Decimal


class GachaConfigDump(BaseModel):
    pack_levels: list[PackLevelOut]
    rank_probabilities: list[RankProbabilitiesOut]
    rarity_probabilities: list[RarityProbabilitiesOut]
    rarity_bonus: RarityBonusOut


RANK_FIELDS = (Rank.hero, Rank.demigod, Rank.minor_god, Rank.major_god)
RARITY_FIELDS = (Rarity.common, Rarity.rare, Rarity.epic, Rarity.legendary)
