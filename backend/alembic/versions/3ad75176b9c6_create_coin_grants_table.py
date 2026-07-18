"""create coin grants table

Revision ID: 3ad75176b9c6
Revises: 7b46e342a9cd
Create Date: 2026-07-18 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '3ad75176b9c6'
down_revision: Union[str, Sequence[str], None] = '7b46e342a9cd'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'coin_grants',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('granted_by_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('target_user_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('amount', sa.Integer(), nullable=False),
        sa.Column('reason', sa.String(), nullable=True),
        sa.Column('recipient_count', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['granted_by_id'], ['users.id']),
        sa.ForeignKeyConstraint(['target_user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_coin_grants_granted_by_id', 'coin_grants', ['granted_by_id'])
    op.create_index('ix_coin_grants_target_user_id', 'coin_grants', ['target_user_id'])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_coin_grants_target_user_id', table_name='coin_grants')
    op.drop_index('ix_coin_grants_granted_by_id', table_name='coin_grants')
    op.drop_table('coin_grants')
