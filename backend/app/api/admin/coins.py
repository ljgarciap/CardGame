from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_superadmin
from app.db.session import get_db
from app.models.coin_grant import CoinGrant
from app.models.user import User
from app.schemas.coin_grant import (
    CoinBroadcastRequest,
    CoinBroadcastResponse,
    CoinGrantOut,
    CoinGrantRequest,
    CoinGrantResponse,
)

router = APIRouter(
    prefix="/api/admin/coins",
    tags=["admin"],
    dependencies=[Depends(get_current_superadmin)],
)


def _grant_out(grant: CoinGrant, granted_by_username: str, target_username: str | None) -> CoinGrantOut:
    return CoinGrantOut(
        id=grant.id,
        granted_by_username=granted_by_username,
        target_username=target_username,
        amount=grant.amount,
        reason=grant.reason,
        recipient_count=grant.recipient_count,
        created_at=grant.created_at,
    )


@router.post("/grant", response_model=CoinGrantResponse, status_code=status.HTTP_201_CREATED)
def grant_coins(
    payload: CoinGrantRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_superadmin),
):
    target = db.execute(
        select(User).where(
            or_(User.email == payload.user_identifier, User.username == payload.user_identifier)
        )
    ).scalar_one_or_none()
    if target is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"no existe ningún usuario con email o username '{payload.user_identifier}'",
        )

    target.coins += payload.amount
    grant = CoinGrant(
        granted_by_id=admin.id,
        target_user_id=target.id,
        amount=payload.amount,
        reason=payload.reason,
    )
    db.add(grant)
    db.commit()
    db.refresh(grant)
    db.refresh(target)

    return CoinGrantResponse(
        grant=_grant_out(grant, admin.username, target.username),
        target_coins=target.coins,
    )


@router.post("/broadcast", response_model=CoinBroadcastResponse, status_code=status.HTTP_201_CREATED)
def broadcast_coins(
    payload: CoinBroadcastRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(get_current_superadmin),
):
    # UPDATE en bloque en vez de traer todas las filas a Python y
    # actualizarlas una por una — evita cargar potencialmente miles de
    # usuarios en memoria por un evento que solo necesita sumar una
    # constante a una columna.
    result = db.execute(
        User.__table__.update().values(coins=User.coins + payload.amount)
    )
    recipient_count = result.rowcount

    grant = CoinGrant(
        granted_by_id=admin.id,
        target_user_id=None,
        amount=payload.amount,
        reason=payload.reason,
        recipient_count=recipient_count,
    )
    db.add(grant)
    db.commit()
    db.refresh(grant)

    return CoinBroadcastResponse(
        grant=_grant_out(grant, admin.username, None),
        recipient_count=recipient_count,
    )


@router.get("/history", response_model=list[CoinGrantOut])
def get_history(db: Session = Depends(get_db)):
    granted_by = User.__table__.alias("granted_by")
    target = User.__table__.alias("target")

    rows = db.execute(
        select(
            CoinGrant,
            granted_by.c.username.label("granted_by_username"),
            target.c.username.label("target_username"),
        )
        .join(granted_by, CoinGrant.granted_by_id == granted_by.c.id)
        .outerjoin(target, CoinGrant.target_user_id == target.c.id)
        .order_by(CoinGrant.created_at.desc())
        .limit(200)
    ).all()

    return [
        _grant_out(grant, granted_by_username, target_username)
        for grant, granted_by_username, target_username in rows
    ]
