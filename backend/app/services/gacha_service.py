"""RNG ponderado + selección de arquetipo + cálculo de stats para abrir sobres.

Tablas y algoritmo: docs/specs/game-gacha-engine.md, docs/designs/gacha-engine.md.
El resultado es server-authoritative — el cliente solo anima lo que este
servicio devuelve. Las probabilidades/precio/bono de rareza viven en DB
(app/models/gacha_config.py), ajustables por un superadmin sin deploy — no
son constantes de módulo (regla global de no hardcodear valores de negocio).
"""
import random
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal
from typing import Dict, List

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.card_archetype import CardArchetype
from app.models.combat_balance import RankBaseStat
from app.models.enums import Faction, Rank, Rarity
from app.models.gacha_config import (
    GachaPackLevel,
    GachaRankProbability,
    GachaRarityBonus,
    GachaRarityProbability,
)
from app.services.combat_balance import get_or_create_rank_base_stats

# Cardinalidad fija del catálogo de niveles (definida por el Game Expert) —
# no es un valor de negocio ajustable, a diferencia de precio/probabilidades.
MIN_LEVEL = 1
MAX_LEVEL = 5

_rng = random.SystemRandom()

RANK_ORDER = [Rank.hero, Rank.demigod, Rank.minor_god, Rank.major_god]
_RANK_INDEX = {rank: i for i, rank in enumerate(RANK_ORDER)}


class IncompleteGachaConfigError(RuntimeError):
    """El catálogo de arquetipos o la config de bono de rareza no cubre una
    combinación necesaria para generar una carta — problema de datos/seed,
    no de input del usuario. No debería pasar en operación normal (los
    seeds cubren el 100% de las combinaciones), pero agregar un valor nuevo
    a Faction/Rank/Rarity sin actualizar el seed correspondiente dispararía
    esto en vez de un KeyError crudo a mitad de una transacción."""


@dataclass
class GeneratedCard:
    archetype: CardArchetype
    rarity: Rarity
    attack: int
    defense: int


def _load_pack_level(db: Session, level: int) -> GachaPackLevel:
    pack_level = db.get(GachaPackLevel, level)
    if pack_level is None:
        raise ValueError(f"no hay configuración de gacha para level={level}")
    return pack_level


def get_pack_price(db: Session, level: int) -> int:
    return _load_pack_level(db, level).price


def _load_rank_probabilities(db: Session, level: int) -> Dict[Rank, Decimal]:
    rows = db.execute(
        select(GachaRankProbability).where(GachaRankProbability.level == level)
    ).scalars().all()
    return {row.rank: row.probability for row in rows}


def _load_rarity_probabilities(db: Session, level: int) -> Dict[Rarity, Decimal]:
    rows = db.execute(
        select(GachaRarityProbability).where(GachaRarityProbability.level == level)
    ).scalars().all()
    return {row.rarity: row.probability for row in rows}


def load_rarity_bonus(db: Session) -> Dict[Rarity, Decimal]:
    rows = db.execute(select(GachaRarityBonus)).scalars().all()
    return {row.rarity: row.bonus for row in rows}


def weighted_choice(probabilities: Dict) -> object:
    # random.choices() mezcla los pesos con un float internamente
    # (cum_weights[-1] + 0.0) -> TypeError si son Decimal, como ahora que
    # las probabilidades vienen de DB (Numeric) en vez de float hardcodeado.
    options = list(probabilities.keys())
    weights = [float(w) for w in probabilities.values()]
    return _rng.choices(options, weights=weights, k=1)[0]


def uniform_choice(options: List) -> object:
    return _rng.choice(options)


def _round_half_up(value: Decimal) -> int:
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def _get_rarity_bonus(rarity_bonus: Dict[Rarity, Decimal], rarity: Rarity) -> Decimal:
    bonus = rarity_bonus.get(rarity)
    if bonus is None:
        raise IncompleteGachaConfigError(
            f"no hay bono configurado para rarity={rarity.value} — revisar seed_gacha_config"
        )
    return bonus


def _calculate_stats(
    archetype: CardArchetype,
    rarity: Rarity,
    rarity_bonus: Dict[Rarity, Decimal],
    rank_base_stats: Dict[Rank, RankBaseStat],
) -> tuple[int, int]:
    # round() de Python usa banker's rounding (half-to-even): round(30*1.35) da 40,
    # pero la tabla del spec (docs/specs/game-gacha-engine.md) exige 41 para
    # Hero+Legendary -> se necesita redondeo half-up explícito, no el round() nativo.
    multiplier = Decimal(1) + _get_rarity_bonus(rarity_bonus, rarity)
    base = rank_base_stats[archetype.rank]
    attack = _round_half_up(Decimal(base.base_attack) * multiplier)
    defense = _round_half_up(Decimal(base.base_defense) * multiplier)
    return attack, defense


def _load_archetypes_by_key(db: Session) -> Dict[tuple, CardArchetype]:
    archetypes = db.execute(select(CardArchetype)).scalars().all()
    return {(a.faction, a.rank): a for a in archetypes}


def _get_archetype(
    archetypes_by_key: Dict[tuple, CardArchetype], faction: Faction, rank: Rank
) -> CardArchetype:
    archetype = archetypes_by_key.get((faction, rank))
    if archetype is None:
        raise IncompleteGachaConfigError(
            f"no hay arquetipo para faction={faction.value} rank={rank.value} — "
            "revisar seed_archetypes"
        )
    return archetype


def generate_pack(db: Session, level: int) -> List[GeneratedCard]:
    if level < MIN_LEVEL or level > MAX_LEVEL:
        raise ValueError(f"level must be between {MIN_LEVEL} and {MAX_LEVEL}, got {level}")

    pack_level = _load_pack_level(db, level)
    rank_probs = _load_rank_probabilities(db, level)
    rarity_probs = _load_rarity_probabilities(db, level)
    rarity_bonus = load_rarity_bonus(db)
    rank_base_stats = get_or_create_rank_base_stats(db)
    archetypes_by_key = _load_archetypes_by_key(db)

    cards: List[GeneratedCard] = []
    for _ in range(pack_level.cards_per_pack):
        rank = weighted_choice(rank_probs)
        rarity = weighted_choice(rarity_probs)
        faction = uniform_choice(list(Faction))
        archetype = _get_archetype(archetypes_by_key, faction, rank)
        attack, defense = _calculate_stats(archetype, rarity, rarity_bonus, rank_base_stats)
        cards.append(GeneratedCard(archetype=archetype, rarity=rarity, attack=attack, defense=defense))

    # guaranteed_min_rank es intencionalmente independiente de rank_probs: es
    # un mecanismo de pity, no una garantía estadística derivada de la tabla.
    # Un admin puede configurar, a propósito, un nivel barato con probabilidad
    # baja de rango alto pero con garantía de rango alto igual ("nunca te
    # vas con las manos vacías aunque la suerte natural sea mala") — eso es
    # una decisión de balance de juego válida, no una inconsistencia a
    # validar en código. Ver docs/designs/gacha-engine.md, sección
    # "guaranteed_min_rank y rank_probabilities: independientes a propósito".
    min_rank = pack_level.guaranteed_min_rank
    if min_rank is not None:
        meets_guarantee = any(_RANK_INDEX[c.archetype.rank] >= _RANK_INDEX[min_rank] for c in cards)
        if not meets_guarantee:
            last = cards[-1]
            forced_archetype = _get_archetype(archetypes_by_key, last.archetype.faction, min_rank)
            attack, defense = _calculate_stats(forced_archetype, last.rarity, rarity_bonus, rank_base_stats)
            cards[-1] = GeneratedCard(
                archetype=forced_archetype, rarity=last.rarity, attack=attack, defense=defense
            )

    return cards
