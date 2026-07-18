"""add muisca to faction enum

Revision ID: 3f9efe66a45f
Revises: 3ad75176b9c6
Create Date: 2026-07-18 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = '3f9efe66a45f'
down_revision: Union[str, Sequence[str], None] = '3ad75176b9c6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Postgres 15 permite ALTER TYPE ... ADD VALUE dentro de una
    # transacción (la restricción de no poder hacerlo en absoluto es de
    # versiones <12) — lo que sigue prohibido es *usar* el valor nuevo en
    # la misma transacción que lo agrega. Esta migración no lo usa (el
    # seed de los 4 arquetipos Muisca corre después, en
    # app/db/seed.py::seed_archetypes, en una sesión/transacción
    # completamente separada) — no hace falta partir esto en dos
    # migraciones ni forzar AUTOCOMMIT.
    op.execute("ALTER TYPE faction ADD VALUE 'muisca'")


def downgrade() -> None:
    """Downgrade schema."""
    # Postgres no soporta DROP VALUE de un enum nativo bajo ninguna
    # circunstancia — la única forma real de sacar un valor es recrear el
    # tipo completo (crear tipo nuevo sin 'muisca', migrar todas las
    # columnas que lo usan, borrar el tipo viejo), y eso requeriría además
    # garantizar en runtime que ninguna fila de card_archetypes/player_cards
    # use 'muisca' todavía. No vale la pena para este caso — mismo criterio
    # que ya aplica el proyecto con estos enums (ver downgrade de
    # 351803a2ed78_create_gacha_tables.py para el precedente de manejo
    # explícito, no silencioso, de estas limitaciones).
    raise NotImplementedError(
        "Postgres no soporta remover un valor de un enum nativo "
        "(faction.muisca) sin recrear el tipo completo. Si hace falta "
        "revertir esto, hacerlo a mano evaluando primero si hay filas "
        "existentes con faction='muisca'."
    )
