import uuid
from typing import List

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
from app.services.card_ownership import load_owned_cards
from app.services.match_engine import DECK_SIZE

router = APIRouter(prefix="/api/decks", tags=["decks"])

# Tope defensivo (evita acumulación sin límite), no un valor de negocio
# ajustable — no hay ningún requerimiento de producto detrás de este número
# específico, así que vive como constante fija acá, mismo criterio que
# DECK_SIZE en match_engine.py.
_MAX_DECKS_PER_USER = 20


def _validate_deck_cards(db: Session, user_id: uuid.UUID, player_card_ids: List[uuid.UUID]) -> None:
    if len(player_card_ids) != DECK_SIZE or len(set(player_card_ids)) != DECK_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"El mazo debe tener exactamente {DECK_SIZE} cartas distintas",
        )
    rows = load_owned_cards(db, user_id, player_card_ids=player_card_ids)
    if len(rows) != DECK_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Alguna carta del mazo no existe o no te pertenece",
        )


def _get_owned_deck(db: Session, deck_id: uuid.UUID, user_id: uuid.UUID) -> Deck:
    deck = db.execute(
        select(Deck).where(Deck.id == deck_id, Deck.user_id == user_id)
    ).scalar_one_or_none()
    if deck is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Mazo no encontrado")
    return deck


def _deck_cards_out(db: Session, deck_id: uuid.UUID) -> List[OwnedCardOut]:
    rows = db.execute(
        select(DeckCard, PlayerCard, CardArchetype)
        .join(PlayerCard, DeckCard.player_card_id == PlayerCard.id)
        .join(CardArchetype, PlayerCard.archetype_id == CardArchetype.id)
        .where(DeckCard.deck_id == deck_id)
        .order_by(DeckCard.position)
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
        for _deck_card, player_card, archetype in rows
    ]


def _replace_deck_cards(db: Session, deck_id: uuid.UUID, player_card_ids: List[uuid.UUID]) -> None:
    db.execute(delete(DeckCard).where(DeckCard.deck_id == deck_id))
    for position, player_card_id in enumerate(player_card_ids):
        db.add(DeckCard(deck_id=deck_id, player_card_id=player_card_id, position=position))


def _deck_out(db: Session, deck: Deck) -> DeckOut:
    return DeckOut(
        id=deck.id,
        name=deck.name,
        cards=_deck_cards_out(db, deck.id),
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
    return [_deck_out(db, deck) for deck in decks]


@router.post("", response_model=DeckOut, status_code=status.HTTP_201_CREATED)
def create_deck(
    payload: DeckCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    existing_count = db.execute(
        select(func.count()).select_from(Deck).where(Deck.user_id == current_user.id)
    ).scalar_one()
    if existing_count >= _MAX_DECKS_PER_USER:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya tenés el máximo de {_MAX_DECKS_PER_USER} mazos guardados",
        )

    _validate_deck_cards(db, current_user.id, payload.player_card_ids)

    deck = Deck(user_id=current_user.id, name=payload.name)
    db.add(deck)
    db.flush()
    _replace_deck_cards(db, deck.id, payload.player_card_ids)
    db.commit()
    db.refresh(deck)

    return _deck_out(db, deck)


@router.put("/{deck_id}", response_model=DeckOut)
def update_deck(
    deck_id: uuid.UUID,
    payload: DeckUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    deck = _get_owned_deck(db, deck_id, current_user.id)
    _validate_deck_cards(db, current_user.id, payload.player_card_ids)

    deck.name = payload.name
    _replace_deck_cards(db, deck.id, payload.player_card_ids)
    db.commit()
    db.refresh(deck)

    return _deck_out(db, deck)


@router.delete("/{deck_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_deck(
    deck_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    deck = _get_owned_deck(db, deck_id, current_user.id)
    db.delete(deck)
    db.commit()
