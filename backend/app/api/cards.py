from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.card_archetype import CardArchetype
from app.models.player_card import PlayerCard
from app.models.user import User
from app.schemas.collection import OwnedCardOut

router = APIRouter(prefix="/api/cards", tags=["cards"])


@router.get("/mine", response_model=list[OwnedCardOut])
def list_my_cards(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Colección completa del usuario autenticado — la usa el deck builder
    de partidas en tiempo real para elegir las 10 cartas del mazo antes de
    encolar (ver docs/designs/realtime-match.md)."""
    rows = db.execute(
        select(PlayerCard, CardArchetype)
        .join(CardArchetype, PlayerCard.archetype_id == CardArchetype.id)
        .where(PlayerCard.user_id == current_user.id)
        .order_by(PlayerCard.obtained_at)
    ).all()
    return [
        OwnedCardOut(
            player_card_id=player_card.id,
            archetype_id=archetype.id,
            name=archetype.name,
            faction=archetype.faction,
            rank=archetype.rank,
            rarity=player_card.rarity,
            attack=player_card.attack,
            defense=player_card.defense,
        )
        for player_card, archetype in rows
    ]
