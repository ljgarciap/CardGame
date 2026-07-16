import uuid
from typing import Dict, List, Tuple

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.card_archetype import CardArchetype
from app.models.deck import Deck, DeckCard
from app.models.player_card import PlayerCard
from app.models.user import User
from app.schemas.collection import OwnedCardOut
from app.schemas.deck import DeckCreateRequest, DeckOut, DeckUpdateRequest
from app.services.card_ownership import load_owned_cards, owned_card_out
from app.services.deck_config import get_or_create_deck_config
from app.services.match_engine import DECK_SIZE

router = APIRouter(prefix="/api/decks", tags=["decks"])

OwnedRow = Tuple[PlayerCard, CardArchetype]


def _validate_deck_cards(
    db: Session, user_id: uuid.UUID, player_card_ids: List[uuid.UUID]
) -> Dict[uuid.UUID, OwnedRow]:
    """Valida cantidad/duplicados/ownership y devuelve las filas ya
    cargadas (player_card_id -> (PlayerCard, CardArchetype)) para que el
    caller arme la respuesta sin volver a consultar la misma info."""
    if len(player_card_ids) != DECK_SIZE or len(set(player_card_ids)) != DECK_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"El mazo debe tener exactamente {DECK_SIZE} cartas distintas",
        )
    rows = load_owned_cards(db, user_id, player_card_ids=player_card_ids)
    owned_by_id = {player_card.id: (player_card, archetype) for player_card, archetype in rows}
    if len(owned_by_id) != DECK_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Alguna carta del mazo no existe o no te pertenece",
        )
    return owned_by_id


def _cards_out_in_order(
    owned_by_id: Dict[uuid.UUID, OwnedRow], player_card_ids: List[uuid.UUID]
) -> List[OwnedCardOut]:
    return [owned_card_out(*owned_by_id[player_card_id]) for player_card_id in player_card_ids]


def _get_owned_deck(db: Session, deck_id: uuid.UUID, user_id: uuid.UUID) -> Deck:
    deck = db.execute(
        select(Deck).where(Deck.id == deck_id, Deck.user_id == user_id)
    ).scalar_one_or_none()
    if deck is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Mazo no encontrado")
    return deck


def _insert_deck_cards(db: Session, deck_id: uuid.UUID, player_card_ids: List[uuid.UUID]) -> None:
    for position, player_card_id in enumerate(player_card_ids):
        db.add(DeckCard(deck_id=deck_id, player_card_id=player_card_id, position=position))


def _replace_deck_cards(db: Session, deck_id: uuid.UUID, player_card_ids: List[uuid.UUID]) -> None:
    db.execute(delete(DeckCard).where(DeckCard.deck_id == deck_id))
    _insert_deck_cards(db, deck_id, player_card_ids)


def _deck_out(deck: Deck, cards: List[OwnedCardOut]) -> DeckOut:
    return DeckOut(
        id=deck.id,
        name=deck.name,
        cards=cards,
        created_at=deck.created_at,
        updated_at=deck.updated_at,
    )


@router.get("", response_model=List[DeckOut])
def list_decks(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    decks = db.execute(
        select(Deck).where(Deck.user_id == current_user.id).order_by(Deck.created_at)
    ).scalars().all()
    if not decks:
        return []

    deck_ids = [deck.id for deck in decks]
    rows = db.execute(
        select(DeckCard, PlayerCard, CardArchetype)
        .join(PlayerCard, DeckCard.player_card_id == PlayerCard.id)
        .join(CardArchetype, PlayerCard.archetype_id == CardArchetype.id)
        .where(DeckCard.deck_id.in_(deck_ids))
        .order_by(DeckCard.deck_id, DeckCard.position)
    ).all()

    cards_by_deck: Dict[uuid.UUID, List[OwnedCardOut]] = {}
    for deck_card, player_card, archetype in rows:
        cards_by_deck.setdefault(deck_card.deck_id, []).append(
            owned_card_out(player_card, archetype)
        )

    return [_deck_out(deck, cards_by_deck.get(deck.id, [])) for deck in decks]


@router.post("", response_model=DeckOut, status_code=status.HTTP_201_CREATED)
def create_deck(
    payload: DeckCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Lockea la fila del usuario para serializar creaciones concurrentes del
    # mismo usuario (dos tabs/requests a la vez) — sin esto, dos requests
    # pueden leer el mismo `existing_count` antes de que cualquiera haga el
    # INSERT y terminar dejando al usuario con más mazos que el tope
    # (TOCTOU, hallazgo de la revisión senior 793abf4).
    db.execute(select(User).where(User.id == current_user.id).with_for_update()).scalar_one()

    max_decks = get_or_create_deck_config(db).max_decks_per_user
    existing_count = db.execute(
        select(func.count()).select_from(Deck).where(Deck.user_id == current_user.id)
    ).scalar_one()
    if existing_count >= max_decks:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya tenés el máximo de {max_decks} mazos guardados",
        )

    owned_by_id = _validate_deck_cards(db, current_user.id, payload.player_card_ids)

    deck = Deck(user_id=current_user.id, name=payload.name)
    db.add(deck)
    db.flush()
    _insert_deck_cards(db, deck.id, payload.player_card_ids)
    db.commit()
    db.refresh(deck)

    return _deck_out(deck, _cards_out_in_order(owned_by_id, payload.player_card_ids))


@router.put("/{deck_id}", response_model=DeckOut)
def update_deck(
    deck_id: uuid.UUID,
    payload: DeckUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    deck = _get_owned_deck(db, deck_id, current_user.id)
    owned_by_id = _validate_deck_cards(db, current_user.id, payload.player_card_ids)

    deck.name = payload.name
    _replace_deck_cards(db, deck.id, payload.player_card_ids)
    db.commit()
    db.refresh(deck)

    return _deck_out(deck, _cards_out_in_order(owned_by_id, payload.player_card_ids))


@router.delete("/{deck_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_deck(
    deck_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    deck = _get_owned_deck(db, deck_id, current_user.id)
    db.delete(deck)
    db.commit()
