"""Seed de la configuración paramétrica del gacha (precio, garantía de rango,
probabilidades de rango/rareza, bono de stat por rareza).

Mismos valores que estaban hardcodeados en `gacha_service.py` antes de la
revisión 2026-07-15b (ver docs/designs/gacha-engine.md) — el seed no cambia
el comportamiento del gacha, solo lo vuelve ajustable sin deploy.
Run con `python -m app.db.seed_gacha_config`.
"""
from decimal import Decimal

from sqlalchemy.orm import Session

from app.models.enums import Rank, Rarity
from app.models.gacha_config import (
    GachaPackLevel,
    GachaRankProbability,
    GachaRarityBonus,
    GachaRarityProbability,
)

PRICE_PER_LEVEL = 1000
CARDS_PER_PACK = 5

# level -> rango mínimo garantizado (None = sin garantía, niveles 1-2)
GUARANTEED_MIN_RANK = {
    1: None,
    2: None,
    3: Rank.demigod,
    4: Rank.minor_god,
    5: Rank.major_god,
}

RANK_PROBABILITIES = {
    1: {Rank.hero: "0.80", Rank.demigod: "0.15", Rank.minor_god: "0.04", Rank.major_god: "0.01"},
    2: {Rank.hero: "0.60", Rank.demigod: "0.30", Rank.minor_god: "0.08", Rank.major_god: "0.02"},
    3: {Rank.hero: "0.43", Rank.demigod: "0.27", Rank.minor_god: "0.19", Rank.major_god: "0.11"},
    4: {Rank.hero: "0.27", Rank.demigod: "0.23", Rank.minor_god: "0.29", Rank.major_god: "0.21"},
    5: {Rank.hero: "0.10", Rank.demigod: "0.20", Rank.minor_god: "0.40", Rank.major_god: "0.30"},
}

RARITY_PROBABILITIES = {
    1: {Rarity.common: "0.90", Rarity.rare: "0.08", Rarity.epic: "0.015", Rarity.legendary: "0.005"},
    2: {Rarity.common: "0.70", Rarity.rare: "0.20", Rarity.epic: "0.08", Rarity.legendary: "0.02"},
    3: {Rarity.common: "0.60", Rarity.rare: "0.23", Rarity.epic: "0.12", Rarity.legendary: "0.05"},
    4: {Rarity.common: "0.50", Rarity.rare: "0.27", Rarity.epic: "0.16", Rarity.legendary: "0.07"},
    5: {Rarity.common: "0.40", Rarity.rare: "0.30", Rarity.epic: "0.20", Rarity.legendary: "0.10"},
}

RARITY_BONUS = {
    Rarity.common: "0.00",
    Rarity.rare: "0.10",
    Rarity.epic: "0.20",
    Rarity.legendary: "0.35",
}


def seed_gacha_config(session: Session) -> None:
    """Idempotente: no inserta nada si ya hay config sembrada."""
    if session.query(GachaPackLevel).first() is not None:
        return

    for level, min_rank in GUARANTEED_MIN_RANK.items():
        session.add(
            GachaPackLevel(
                level=level,
                price=level * PRICE_PER_LEVEL,
                cards_per_pack=CARDS_PER_PACK,
                guaranteed_min_rank=min_rank,
            )
        )

    for level, probs in RANK_PROBABILITIES.items():
        for rank, probability in probs.items():
            session.add(
                GachaRankProbability(level=level, rank=rank, probability=Decimal(probability))
            )

    for level, probs in RARITY_PROBABILITIES.items():
        for rarity, probability in probs.items():
            session.add(
                GachaRarityProbability(
                    level=level, rarity=rarity, probability=Decimal(probability)
                )
            )

    for rarity, bonus in RARITY_BONUS.items():
        session.add(GachaRarityBonus(rarity=rarity, bonus=Decimal(bonus)))

    session.commit()


if __name__ == "__main__":
    from app.db.session import SessionLocal

    db = SessionLocal()
    try:
        seed_gacha_config(db)
    finally:
        db.close()
