from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_superadmin
from app.db.session import get_db
from app.schemas.deck_config import DeckConfigOut, DeckConfigUpdateRequest
from app.services.deck_config import get_or_create_deck_config

router = APIRouter(
    prefix="/api/admin/deck-config",
    tags=["admin"],
    dependencies=[Depends(get_current_superadmin)],
)


@router.get("", response_model=DeckConfigOut)
def get_deck_config(db: Session = Depends(get_db)):
    return get_or_create_deck_config(db)


@router.put("", response_model=DeckConfigOut)
def update_deck_config(payload: DeckConfigUpdateRequest, db: Session = Depends(get_db)):
    config = get_or_create_deck_config(db)
    config.max_decks_per_user = payload.max_decks_per_user
    db.commit()
    db.refresh(config)
    return config
