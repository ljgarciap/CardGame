from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_superadmin
from app.db.session import get_db
from app.models.enums import Rank, Rarity
from app.models.gacha_config import (
    GachaPackLevel,
    GachaRankProbability,
    GachaRarityBonus,
    GachaRarityProbability,
)
from app.schemas.gacha_config import (
    RANK_FIELDS,
    RARITY_FIELDS,
    GachaConfigDump,
    PackLevelOut,
    PackLevelUpdateRequest,
    RankProbabilitiesOut,
    RankProbabilitiesUpdateRequest,
    RarityBonusOut,
    RarityBonusUpdateRequest,
    RarityProbabilitiesOut,
    RarityProbabilitiesUpdateRequest,
)

router = APIRouter(
    prefix="/api/admin/gacha-config",
    tags=["admin"],
    dependencies=[Depends(get_current_superadmin)],
)

_PROBABILITY_SUM_TOLERANCE = Decimal("0.0001")


def _get_pack_level_or_404(db: Session, level: int) -> GachaPackLevel:
    pack_level = db.get(GachaPackLevel, level)
    if pack_level is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"no existe config para level={level}"
        )
    return pack_level


def _validate_non_negative(values: dict) -> None:
    negative = {k: v for k, v in values.items() if v < 0}
    if negative:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"los valores no pueden ser negativos: {negative}",
        )


def _validate_probability_sum(values: dict) -> None:
    _validate_non_negative(values)
    total = sum(values.values(), Decimal(0))
    if abs(total - Decimal(1)) > _PROBABILITY_SUM_TOLERANCE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"las probabilidades deben sumar 1.0 (suma recibida: {total})",
        )


@router.get("", response_model=GachaConfigDump)
def get_gacha_config(db: Session = Depends(get_db)):
    pack_levels = db.execute(
        select(GachaPackLevel).order_by(GachaPackLevel.level)
    ).scalars().all()

    rank_rows = db.execute(
        select(GachaRankProbability).order_by(GachaRankProbability.level)
    ).scalars().all()
    rank_by_level: dict = {}
    for row in rank_rows:
        rank_by_level.setdefault(row.level, {})[row.rank.value] = row.probability

    rarity_rows = db.execute(
        select(GachaRarityProbability).order_by(GachaRarityProbability.level)
    ).scalars().all()
    rarity_by_level: dict = {}
    for row in rarity_rows:
        rarity_by_level.setdefault(row.level, {})[row.rarity.value] = row.probability

    bonus_rows = db.execute(select(GachaRarityBonus)).scalars().all()
    bonus_by_rarity = {row.rarity.value: row.bonus for row in bonus_rows}

    return GachaConfigDump(
        pack_levels=[PackLevelOut.model_validate(pl) for pl in pack_levels],
        rank_probabilities=[
            RankProbabilitiesOut(level=level, **values)
            for level, values in sorted(rank_by_level.items())
        ],
        rarity_probabilities=[
            RarityProbabilitiesOut(level=level, **values)
            for level, values in sorted(rarity_by_level.items())
        ],
        rarity_bonus=RarityBonusOut(**bonus_by_rarity),
    )


@router.put("/pack-levels/{level}", response_model=PackLevelOut)
def update_pack_level(
    level: int, payload: PackLevelUpdateRequest, db: Session = Depends(get_db)
):
    if payload.price <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"price debe ser positivo (recibido: {payload.price})",
        )

    pack_level = _get_pack_level_or_404(db, level)
    pack_level.price = payload.price
    pack_level.guaranteed_min_rank = payload.guaranteed_min_rank
    db.commit()
    db.refresh(pack_level)
    return pack_level


@router.put("/rank-probabilities/{level}", response_model=RankProbabilitiesOut)
def update_rank_probabilities(
    level: int, payload: RankProbabilitiesUpdateRequest, db: Session = Depends(get_db)
):
    _get_pack_level_or_404(db, level)
    values = {
        Rank.hero: payload.hero,
        Rank.demigod: payload.demigod,
        Rank.minor_god: payload.minor_god,
        Rank.major_god: payload.major_god,
    }
    _validate_probability_sum(values)

    for rank in RANK_FIELDS:
        row = db.get(GachaRankProbability, (level, rank))
        if row is None:
            row = GachaRankProbability(level=level, rank=rank, probability=values[rank])
            db.add(row)
        else:
            row.probability = values[rank]
    db.commit()

    return RankProbabilitiesOut(level=level, **{r.value: v for r, v in values.items()})


@router.put("/rarity-probabilities/{level}", response_model=RarityProbabilitiesOut)
def update_rarity_probabilities(
    level: int, payload: RarityProbabilitiesUpdateRequest, db: Session = Depends(get_db)
):
    _get_pack_level_or_404(db, level)
    values = {
        Rarity.common: payload.common,
        Rarity.rare: payload.rare,
        Rarity.epic: payload.epic,
        Rarity.legendary: payload.legendary,
    }
    _validate_probability_sum(values)

    for rarity in RARITY_FIELDS:
        row = db.get(GachaRarityProbability, (level, rarity))
        if row is None:
            row = GachaRarityProbability(level=level, rarity=rarity, probability=values[rarity])
            db.add(row)
        else:
            row.probability = values[rarity]
    db.commit()

    return RarityProbabilitiesOut(level=level, **{r.value: v for r, v in values.items()})


@router.put("/rarity-bonus", response_model=RarityBonusOut)
def update_rarity_bonus(payload: RarityBonusUpdateRequest, db: Session = Depends(get_db)):
    values = {
        Rarity.common: payload.common,
        Rarity.rare: payload.rare,
        Rarity.epic: payload.epic,
        Rarity.legendary: payload.legendary,
    }
    _validate_non_negative(values)

    for rarity in RARITY_FIELDS:
        row = db.get(GachaRarityBonus, rarity)
        if row is None:
            row = GachaRarityBonus(rarity=rarity, bonus=values[rarity])
            db.add(row)
        else:
            row.bonus = values[rarity]
    db.commit()

    return RarityBonusOut(**{r.value: v for r, v in values.items()})
