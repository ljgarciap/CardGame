from collections import Counter

import pytest

from app.db.seed import seed_archetypes
from app.db.seed_gacha_config import (
    GUARANTEED_MIN_RANK,
    RANK_PROBABILITIES,
    RARITY_PROBABILITIES,
    seed_gacha_config,
)
from app.models.card_archetype import CardArchetype
from app.models.enums import Faction, Rank, Rarity
from app.models.gacha_config import GachaPackLevel
from app.services.combat_balance import get_or_create_rank_base_stats
from app.services.gacha_service import (
    RANK_ORDER,
    IncompleteGachaConfigError,
    _calculate_stats,
    _get_archetype,
    _get_rarity_bonus,
    generate_pack,
    load_rarity_bonus,
)

# Los valores esperados en RANK_PROBABILITIES/RARITY_PROBABILITIES son str
# (mismo formato que el seed usa para construir Decimal) -> se comparan como float.
N_OPENS = 2000  # 2000 aperturas x 5 cartas = 10,000 cartas por nivel
RANK_TOLERANCE = 0.05
RARITY_TOLERANCE = 0.02
_RANK_INDEX = {rank: i for i, rank in enumerate(RANK_ORDER)}


@pytest.fixture
def seeded(db_session):
    seed_archetypes(db_session)
    seed_gacha_config(db_session)
    return db_session


@pytest.mark.parametrize("level", [1, 2, 3, 4, 5])
def test_rank_distribution_matches_theoretical_table(seeded, level):
    counts = Counter()
    total = 0
    for _ in range(N_OPENS):
        for card in generate_pack(seeded, level):
            counts[card.archetype.rank] += 1
            total += 1

    for rank, expected_str in RANK_PROBABILITIES[level].items():
        expected = float(expected_str)
        observed = counts[rank] / total
        assert abs(observed - expected) < RANK_TOLERANCE, (
            f"level={level} rank={rank.value}: esperado~{expected}, observado={observed:.4f}"
        )


@pytest.mark.parametrize("level", [1, 2, 3, 4, 5])
def test_rarity_distribution_matches_theoretical_table(seeded, level):
    counts = Counter()
    total = 0
    for _ in range(N_OPENS):
        for card in generate_pack(seeded, level):
            counts[card.rarity] += 1
            total += 1

    for rarity, expected_str in RARITY_PROBABILITIES[level].items():
        expected = float(expected_str)
        observed = counts[rarity] / total
        assert abs(observed - expected) < RARITY_TOLERANCE, (
            f"level={level} rarity={rarity.value}: esperado~{expected}, observado={observed:.4f}"
        )


@pytest.mark.parametrize("level", [3, 4, 5])
def test_guaranteed_levels_always_meet_minimum_rank(seeded, level):
    min_rank = GUARANTEED_MIN_RANK[level]
    min_index = _RANK_INDEX[min_rank]

    for _ in range(N_OPENS):
        cards = generate_pack(seeded, level)
        assert any(_RANK_INDEX[c.archetype.rank] >= min_index for c in cards), (
            f"pack de nivel {level} sin ninguna carta >= {min_rank.value}"
        )


@pytest.mark.parametrize("level", [1, 2])
def test_non_guaranteed_levels_have_no_minimum_rank(level):
    assert GUARANTEED_MIN_RANK[level] is None


def test_pack_always_has_five_cards(seeded):
    # 5 es el valor sembrado por default (seed_gacha_config.CARDS_PER_PACK),
    # no una constante fija del servicio -- ver test de abajo para el caso
    # de un nivel configurado con otra cantidad.
    for level in range(1, 6):
        assert len(generate_pack(seeded, level)) == 5


def test_generate_pack_respects_configured_cards_per_pack(seeded):
    pack_level = seeded.get(GachaPackLevel, 1)
    pack_level.cards_per_pack = 8
    seeded.commit()

    assert len(generate_pack(seeded, 1)) == 8


@pytest.mark.parametrize("level", [0, 6, -1, 100])
def test_invalid_level_raises_value_error(seeded, level):
    with pytest.raises(ValueError):
        generate_pack(seeded, level)


@pytest.mark.parametrize(
    "rank, rarity, expected",
    [
        (Rank.hero, Rarity.common, 2),  # round(2 * 1.00)
        (Rank.hero, Rarity.rare, 2),  # round(2 * 1.10) = round(2.2)
        (Rank.hero, Rarity.epic, 2),  # round(2 * 1.20) = round(2.4)
        (Rank.hero, Rarity.legendary, 3),  # 2 * 1.35 = 2.7 -> half-up -> 3
        (Rank.demigod, Rarity.rare, 3),  # 3 * 1.10 = 3.3 -> half-up -> 3
        (Rank.minor_god, Rarity.epic, 5),  # 4 * 1.20 = 4.8 -> half-up -> 5
        (Rank.major_god, Rarity.legendary, 8),  # 6 * 1.35 = 8.1 -> half-up -> 8
    ],
)
def test_rarity_stat_bonus_formula(seeded, rank, rarity, expected):
    archetype = (
        seeded.query(CardArchetype)
        .filter_by(faction=Faction.greek, rank=rank)
        .one()
    )
    rarity_bonus = load_rarity_bonus(seeded)
    rank_base_stats = get_or_create_rank_base_stats(seeded)
    attack, defense = _calculate_stats(archetype, rarity, rarity_bonus, rank_base_stats)
    assert attack == expected
    assert defense == expected


def test_get_archetype_raises_clear_error_when_combination_missing():
    with pytest.raises(IncompleteGachaConfigError, match="greek"):
        _get_archetype({}, Faction.greek, Rank.hero)


def test_get_rarity_bonus_raises_clear_error_when_missing():
    with pytest.raises(IncompleteGachaConfigError, match="rare"):
        _get_rarity_bonus({}, Rarity.rare)
