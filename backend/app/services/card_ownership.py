from typing import Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.card_archetype import CardArchetype
from app.models.player_card import PlayerCard

# Query PlayerCard+CardArchetype compartida — antes duplicada en
# app/api/cards.py y app/api/match_ws.py (y a punto de aparecer una tercera
# vez en los endpoints de mazos guardados).


def load_owned_cards(
    db: Session,
    user_id: UUID,
    *,
    player_card_ids: Optional[list[UUID]] = None,
    limit: Optional[int] = None,
) -> list[tuple[PlayerCard, CardArchetype]]:
    """Cartas de `user_id`, opcionalmente filtradas a un set de
    `player_card_id` puntual (ej. validar que un mazo es todo del usuario) —
    sin filtro, trae la colección completa ordenada por fecha de obtención.
    El caller que filtra por ids decide qué hacer si faltan (comparar
    `len(resultado)` contra `len(player_card_ids)` pedidos: los que no son
    del usuario o no existen simplemente no aparecen)."""
    query = (
        select(PlayerCard, CardArchetype)
        .join(CardArchetype, PlayerCard.archetype_id == CardArchetype.id)
        .where(PlayerCard.user_id == user_id)
    )
    if player_card_ids is not None:
        query = query.where(PlayerCard.id.in_(player_card_ids))
    else:
        query = query.order_by(PlayerCard.obtained_at)
    if limit is not None:
        query = query.limit(limit)
    return db.execute(query).all()
