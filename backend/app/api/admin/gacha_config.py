from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_superadmin
from app.db.session import get_db
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
        # k.value/str(v) en vez de dejar que el f-string use repr() del dict
        # -> antes el detail devuelto al cliente era literalmente
        # "{<Rank.hero: 'hero'>: Decimal('-0.2')}", no un mensaje legible.
        readable = ", ".join(f"{k.value}: {v}" for k, v in negative.items())
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"los valores no pueden ser negativos: {readable}",
        )


def _validate_probability_sum(values: dict) -> None:
    _validate_non_negative(values)
    total = sum(values.values(), Decimal(0))
    if abs(total - Decimal(1)) > _PROBABILITY_SUM_TOLERANCE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"las probabilidades deben sumar 1.0 (suma recibida: {total})",
        )


def _payload_to_values(payload, fields) -> dict:
    """{Rank.hero: payload.hero, ...} — el `.value` del enum matchea 1:1 el
    nombre del atributo del schema (ver RANK_FIELDS/RARITY_FIELDS)."""
    return {field: getattr(payload, field.value) for field in fields}


def _values_by_name(values: dict) -> dict:
    return {key.value: value for key, value in values.items()}


def _upsert(db: Session, model, pk, create_kwargs: dict, value_attr: str, value) -> None:
    """Carga la fila por su PK y actualiza `value_attr`, o la crea si no
    existe. Único lugar con el patrón "load-or-create" — antes repetido
    igual en cada uno de los 3 PUT de este router."""
    row = db.get(model, pk)
    if row is None:
        db.add(model(**create_kwargs, **{value_attr: value}))
    else:
        setattr(row, value_attr, value)


def _group_by_level(rows, key_attr: str, value_attr: str) -> dict:
    grouped: dict = {}
    for row in rows:
        grouped.setdefault(row.level, {})[getattr(row, key_attr).value] = getattr(row, value_attr)
    return grouped


@router.get("", response_model=GachaConfigDump)
def get_gacha_config(db: Session = Depends(get_db)):
    pack_levels = db.execute(
        select(GachaPackLevel).order_by(GachaPackLevel.level)
    ).scalars().all()

    rank_rows = db.execute(
        select(GachaRankProbability).order_by(GachaRankProbability.level)
    ).scalars().all()
    rank_by_level = _group_by_level(rank_rows, "rank", "probability")

    rarity_rows = db.execute(
        select(GachaRarityProbability).order_by(GachaRarityProbability.level)
    ).scalars().all()
    rarity_by_level = _group_by_level(rarity_rows, "rarity", "probability")

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
    # A propósito, no se valida guaranteed_min_rank contra las probabilidades
    # de rango de este mismo nivel (rank-probabilities/{level}) — son ejes
    # independientes por diseño, ver comentario en
    # gacha_service.generate_pack y docs/designs/gacha-engine.md.
    pack_level.guaranteed_min_rank = payload.guaranteed_min_rank
    db.commit()
    db.refresh(pack_level)
    return pack_level


@router.put("/rank-probabilities/{level}", response_model=RankProbabilitiesOut)
def update_rank_probabilities(
    level: int, payload: RankProbabilitiesUpdateRequest, db: Session = Depends(get_db)
):
    _get_pack_level_or_404(db, level)
    values = _payload_to_values(payload, RANK_FIELDS)
    _validate_probability_sum(values)

    for rank, probability in values.items():
        _upsert(
            db, GachaRankProbability, (level, rank),
            {"level": level, "rank": rank}, "probability", probability,
        )
    db.commit()

    return RankProbabilitiesOut(level=level, **_values_by_name(values))


@router.put("/rarity-probabilities/{level}", response_model=RarityProbabilitiesOut)
def update_rarity_probabilities(
    level: int, payload: RarityProbabilitiesUpdateRequest, db: Session = Depends(get_db)
):
    _get_pack_level_or_404(db, level)
    values = _payload_to_values(payload, RARITY_FIELDS)
    _validate_probability_sum(values)

    for rarity, probability in values.items():
        _upsert(
            db, GachaRarityProbability, (level, rarity),
            {"level": level, "rarity": rarity}, "probability", probability,
        )
    db.commit()

    return RarityProbabilitiesOut(level=level, **_values_by_name(values))


@router.put("/rarity-bonus", response_model=RarityBonusOut)
def update_rarity_bonus(payload: RarityBonusUpdateRequest, db: Session = Depends(get_db)):
    values = _payload_to_values(payload, RARITY_FIELDS)
    _validate_non_negative(values)

    for rarity, bonus in values.items():
        _upsert(db, GachaRarityBonus, rarity, {"rarity": rarity}, "bonus", bonus)
    db.commit()

    return RarityBonusOut(**_values_by_name(values))
