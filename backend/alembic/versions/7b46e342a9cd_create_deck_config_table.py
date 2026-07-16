"""create deck config table

Revision ID: 7b46e342a9cd
Revises: 2cb3a7b133d1
Create Date: 2026-07-16 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7b46e342a9cd'
down_revision: Union[str, Sequence[str], None] = '2cb3a7b133d1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_DECK_CONFIG_TABLE = sa.table(
    'deck_config',
    sa.column('id', sa.Integer),
    sa.column('max_decks_per_user', sa.Integer),
)


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('deck_config',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('max_decks_per_user', sa.Integer(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    # Fila default (id=1) sembrada acá directamente en vez de depender de
    # un script de seed manual -> el tope de mazos nunca queda "sin
    # configurar" en ningún ambiente que corra las migraciones.
    op.bulk_insert(_DECK_CONFIG_TABLE, [{'id': 1, 'max_decks_per_user': 20}])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('deck_config')
