import uuid
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User

_bearer_scheme = HTTPBearer(auto_error=False)


def resolve_user_by_token(db: Session, token: str) -> Optional[User]:
    """Decodifica un JWT ya extraído (de header Authorization o de query
    param, según el caller) y busca el User — compartido entre el auth REST
    (`get_current_user`, abajo) y el auth del WebSocket de partidas
    (`app.api.match_ws._authenticate`), que antes duplicaban este mismo
    cuerpo con su propia copia de decode+parse+lookup."""
    user_id = decode_access_token(token)
    if user_id is None:
        return None
    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        return None
    return db.execute(select(User).where(User.id == user_uuid)).scalar_one_or_none()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="No autenticado"
        )

    user = resolve_user_by_token(db, credentials.credentials)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido o expirado"
        )

    return user


def get_current_superadmin(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Requiere permisos de superadmin"
        )
    return current_user
