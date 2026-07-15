from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.player_card import PlayerCard
from app.models.user import User
from app.schemas.pack import CardOut, PackOpenRequest, PackOpenResponse
from app.services.gacha_service import MAX_LEVEL, MIN_LEVEL, generate_pack, get_pack_price

router = APIRouter(prefix="/api/packs", tags=["packs"])


@router.post("/open", response_model=PackOpenResponse)
def open_pack(
    payload: PackOpenRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if payload.level < MIN_LEVEL or payload.level > MAX_LEVEL:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"level debe estar entre {MIN_LEVEL} y {MAX_LEVEL}",
        )

    price = get_pack_price(db, payload.level)

    # Bloquea la fila del usuario para toda la transacción: evita doble gasto
    # si el mismo usuario dispara dos aperturas concurrentes.
    locked_user = db.execute(
        select(User).where(User.id == current_user.id).with_for_update()
    ).scalar_one()

    if locked_user.coins < price:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Saldo insuficiente"
        )

    cards = generate_pack(db, payload.level)

    locked_user.coins -= price
    for card in cards:
        db.add(
            PlayerCard(
                user_id=locked_user.id,
                archetype_id=card.archetype.id,
                rarity=card.rarity,
                attack=card.attack,
                defense=card.defense,
            )
        )

    db.commit()
    db.refresh(locked_user)

    return PackOpenResponse(
        cards=[
            CardOut(
                archetype_id=card.archetype.id,
                name=card.archetype.name,
                faction=card.archetype.faction,
                rank=card.archetype.rank,
                rarity=card.rarity,
                attack=card.attack,
                defense=card.defense,
            )
            for card in cards
        ],
        remaining_coins=locked_user.coins,
    )
