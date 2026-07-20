"""combat balance config (starting life + rank base stats), retroactive
player_cards recalculation, drop redundant archetype base stat columns

Contexto: STARTING_LIFE estaba fijo en 20 en match_engine.py mientras las
cartas reales del gacha (base_attack en card_archetypes, 30-108 según
rango+rareza) mataban de un solo golpe siempre -- bug encontrado jugando
contra el bot en el VPS de prueba. base_attack/base_defense de
card_archetypes eran además redundantes: idénticos para toda carta del
mismo rango (Aquiles y Bochica, ambos Hero, valían lo mismo) -- esta
migración los reemplaza por una fila por Rank en rank_base_stats, y
además recalcula cada player_cards.attack/defense ya emitido para que las
cartas que un jugador ya tiene (no solo las nuevas) queden con el ataque
corregido.

Revision ID: 64bc9fe36c44
Revises: 3f9efe66a45f
Create Date: 2026-07-19 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '64bc9fe36c44'
down_revision: Union[str, Sequence[str], None] = '3f9efe66a45f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# El tipo ENUM "rank" ya existe en Postgres (creado en la migración
# 351803a2ed78 para card_archetypes). create_type=False evita que
# op.create_table intente un CREATE TYPE duplicado -> DuplicateObject
# (mismo criterio que de7aafeffe7d_create_gacha_config_tables.py).
_rank_enum = postgresql.ENUM(
    'hero', 'demigod', 'minor_god', 'major_god', name='rank', create_type=False
)

_COMBAT_BALANCE_CONFIG_TABLE = sa.table(
    'combat_balance_config',
    sa.column('id', sa.Integer),
    sa.column('starting_life', sa.Integer),
)

_RANK_BASE_STATS_TABLE = sa.table(
    'rank_base_stats',
    sa.column('rank', sa.String),
    sa.column('base_attack', sa.Integer),
    sa.column('base_defense', sa.Integer),
)

# Ritmo "Moderado" (docs/specs/game-gacha-engine.md): con 20 de vida, la
# carta más débil (Hero común) tarda ~10 golpes en matar sola, la más
# fuerte posible (Major God legendaria, +35%) baja a ~8 de un golpe -- a
# diferencia de los valores viejos (30-108), ninguna mata de un solo golpe.
_STARTING_LIFE = 20
_RANK_BASE_STATS = {
    'hero': 2,
    'demigod': 3,
    'minor_god': 4,
    'major_god': 6,
}


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'combat_balance_config',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('starting_life', sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.bulk_insert(_COMBAT_BALANCE_CONFIG_TABLE, [{'id': 1, 'starting_life': _STARTING_LIFE}])

    op.create_table(
        'rank_base_stats',
        sa.Column('rank', _rank_enum, nullable=False),
        sa.Column('base_attack', sa.Integer(), nullable=False),
        sa.Column('base_defense', sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint('rank'),
    )
    op.bulk_insert(_RANK_BASE_STATS_TABLE, [
        {'rank': rank, 'base_attack': base, 'base_defense': base}
        for rank, base in _RANK_BASE_STATS.items()
    ])

    # Recalcula cada player_cards ya emitido con los nuevos valores base ×
    # el bono de rareza de esa carta puntual (gacha_rarity_bonus, ya
    # sembrado por una migración anterior) -- ROUND() de Postgres sobre
    # numeric redondea half-away-from-zero, que para valores positivos
    # coincide con el half-up que usa _round_half_up en Python.
    op.execute(sa.text("""
        UPDATE player_cards pc
        SET attack = new_stats.new_attack,
            defense = new_stats.new_defense
        FROM (
            SELECT pc2.id AS id,
                   ROUND(rbs.base_attack * (1 + grb.bonus))::integer AS new_attack,
                   ROUND(rbs.base_defense * (1 + grb.bonus))::integer AS new_defense
            FROM player_cards pc2
            JOIN card_archetypes ca ON ca.id = pc2.archetype_id
            JOIN rank_base_stats rbs ON rbs.rank = ca.rank
            JOIN gacha_rarity_bonus grb ON grb.rarity = pc2.rarity
        ) AS new_stats
        WHERE pc.id = new_stats.id
    """))

    op.drop_column('card_archetypes', 'base_attack')
    op.drop_column('card_archetypes', 'base_defense')


def downgrade() -> None:
    """Downgrade schema.

    Nota: recupera las columnas base_attack/base_defense de card_archetypes
    (backfilleadas desde rank_base_stats), pero NO revierte
    player_cards.attack/defense a sus valores previos a este upgrade --
    esa información ya no existe una vez sobreescrita. Un downgrade real
    después de haber operado en este estado implica resembrar/recalcular
    las cartas a mano."""
    op.add_column('card_archetypes', sa.Column('base_attack', sa.Integer(), nullable=True))
    op.add_column('card_archetypes', sa.Column('base_defense', sa.Integer(), nullable=True))
    op.execute(sa.text("""
        UPDATE card_archetypes ca
        SET base_attack = rbs.base_attack,
            base_defense = rbs.base_defense
        FROM rank_base_stats rbs
        WHERE rbs.rank = ca.rank
    """))
    op.alter_column('card_archetypes', 'base_attack', nullable=False)
    op.alter_column('card_archetypes', 'base_defense', nullable=False)

    op.drop_table('rank_base_stats')
    op.drop_table('combat_balance_config')
