from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.collection import OwnedCardOut
from app.services.card_ownership import load_owned_cards, owned_card_out

router = APIRouter(prefix="/api/cards", tags=["cards"])

# Sin límite ni paginación real todavía (el deck builder necesita ver la
# colección entera para elegir 10 cartas, no una página a la vez) — esta
# cota es solo defensiva, para que una colección patológicamente grande
# (nada la limita hoy: abrir sobres no tiene tope más que el saldo) no
# devuelva un response ilimitado. Si algún usuario real llega a este límite,
# hace falta paginación de verdad (query params + scroll infinito en el
# cliente), no subir el número.
_MAX_CARDS_RETURNED = 500


@router.get("/mine", response_model=list[OwnedCardOut])
def list_my_cards(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Colección completa del usuario autenticado — la usa el deck builder
    de partidas en tiempo real para elegir las 10 cartas del mazo antes de
    encolar (ver docs/designs/realtime-match.md)."""
    rows = load_owned_cards(db, current_user.id, limit=_MAX_CARDS_RETURNED)
    return [owned_card_out(player_card, archetype) for player_card, archetype in rows]
