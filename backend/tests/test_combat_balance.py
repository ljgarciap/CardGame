from decimal import Decimal

from app.db.seed_gacha_config import seed_gacha_config
from app.models.enums import Rank, Rarity
from app.services.combat_balance import (
    DEFAULT_RANK_BASE_STATS,
    DEFAULT_STARTING_LIFE,
    get_or_create_combat_balance_config,
    get_or_create_rank_base_stats,
)
from app.services.gacha_service import load_rarity_bonus


def test_get_or_create_combat_balance_config_returns_default(db_session):
    config = get_or_create_combat_balance_config(db_session)
    assert config.starting_life == DEFAULT_STARTING_LIFE


def test_get_or_create_rank_base_stats_returns_defaults_for_every_rank(db_session):
    rank_base_stats = get_or_create_rank_base_stats(db_session)
    assert set(rank_base_stats.keys()) == set(Rank)
    for rank, row in rank_base_stats.items():
        assert row.base_attack == DEFAULT_RANK_BASE_STATS[rank]
        assert row.base_defense == DEFAULT_RANK_BASE_STATS[rank]


def test_no_single_card_can_one_shot_a_fresh_player(db_session):
    """Regresión del bug real encontrado jugando contra el bot en el VPS:
    con STARTING_LIFE=20 y ataque base 30-108, cualquier carta mataba de un
    solo golpe -- ver docs/memory.md 2026-07-19. El ataque máximo posible
    (Major God + bono de rareza más alto) tiene que quedar por debajo de la
    vida inicial."""
    seed_gacha_config(db_session)
    config = get_or_create_combat_balance_config(db_session)
    rank_base_stats = get_or_create_rank_base_stats(db_session)
    rarity_bonus = load_rarity_bonus(db_session)

    max_multiplier = Decimal(1) + max(rarity_bonus.values())
    max_base = max(row.base_attack for row in rank_base_stats.values())
    max_possible_attack = int((Decimal(max_base) * max_multiplier).to_integral_value(rounding="ROUND_CEILING"))

    assert max_possible_attack < config.starting_life
