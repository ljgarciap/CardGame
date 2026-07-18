import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.email import send_email
from app.core.security import create_access_token, hash_password, verify_password
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    MessageResponse,
    RegisterRequest,
    RegisterResponse,
    RequestPasswordResetRequest,
    ResendVerificationRequest,
    ResetPasswordRequest,
    TokenResponse,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])

VERIFICATION_TOKEN_EXPIRE_HOURS = 24
RESET_TOKEN_EXPIRE_HOURS = 1
_DUPLICATE_ACCOUNT_MESSAGE = "El email o username ya está en uso"
_GENERIC_RESEND_MESSAGE = (
    "Si el email existe y no está verificado, te enviamos un nuevo link de verificación"
)
_INVALID_CREDENTIALS_MESSAGE = "Email o contraseña incorrectos"
_GENERIC_RESET_REQUEST_MESSAGE = (
    "Si el email existe, te enviamos un link para restablecer tu contraseña"
)
_INVALID_RESET_TOKEN_MESSAGE = "Token inválido o expirado"


def _generate_token() -> str:
    return secrets.token_urlsafe(32)


async def _send_verification_email(email: str, token: str) -> None:
    # Custom URL scheme, no HTTPS Universal/App Link — mismo motivo que
    # _send_password_reset_email: cardgame.local no es un dominio real que
    # podamos hostear, así que no hay forma de publicar
    # apple-app-site-association/assetlinks.json para verificar un link
    # HTTPS. Ver docs/designs/auth-system.md, "Deep link de
    # reset-password" — mismo patrón aplicado acá.
    verify_url = f"cardgame://verify-email?token={token}"
    await send_email(
        to=email,
        subject="Verifica tu cuenta de CardGame",
        body=(
            f"Hacé click para verificar tu cuenta: {verify_url}\n\n"
            f"Este link expira en {VERIFICATION_TOKEN_EXPIRE_HOURS} horas."
        ),
    )


@router.post(
    "/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED
)
async def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.execute(
        select(User).where(
            (User.email == payload.email) | (User.username == payload.username)
        )
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=_DUPLICATE_ACCOUNT_MESSAGE
        )

    token = _generate_token()
    user = User(
        email=payload.email,
        password_hash=hash_password(payload.password),
        username=payload.username,
        avatar_id=payload.avatar_id,
        email_verified=False,
        verification_token=token,
        verification_token_expires_at=datetime.now(timezone.utc)
        + timedelta(hours=VERIFICATION_TOKEN_EXPIRE_HOURS),
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=_DUPLICATE_ACCOUNT_MESSAGE
        )
    db.refresh(user)

    await _send_verification_email(user.email, token)

    return RegisterResponse(id=user.id, email=user.email, username=user.username)


@router.get("/verify-email", response_model=MessageResponse)
async def verify_email(token: str, db: Session = Depends(get_db)):
    user = db.execute(
        select(User).where(User.verification_token == token)
    ).scalar_one_or_none()

    if (
        user is None
        or user.verification_token_expires_at is None
        or user.verification_token_expires_at < datetime.now(timezone.utc)
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Token inválido o expirado"
        )

    user.email_verified = True
    user.verification_token = None
    user.verification_token_expires_at = None
    db.commit()

    return MessageResponse(message="Email verificado correctamente")


@router.post("/resend-verification", response_model=MessageResponse)
async def resend_verification(
    payload: ResendVerificationRequest, db: Session = Depends(get_db)
):
    user = db.execute(
        select(User).where(User.email == payload.email)
    ).scalar_one_or_none()

    if user is not None and not user.email_verified:
        token = _generate_token()
        user.verification_token = token
        user.verification_token_expires_at = datetime.now(timezone.utc) + timedelta(
            hours=VERIFICATION_TOKEN_EXPIRE_HOURS
        )
        db.commit()
        await _send_verification_email(user.email, token)

    # Mismo mensaje exista o no el email, o ya esté verificado — evita enumeración
    return MessageResponse(message=_GENERIC_RESEND_MESSAGE)


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.execute(
        select(User).where(User.email == payload.email)
    ).scalar_one_or_none()

    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=_INVALID_CREDENTIALS_MESSAGE,
        )

    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Verifica tu email antes de iniciar sesión",
        )

    return TokenResponse(access_token=create_access_token(subject=str(user.id)))


async def _send_password_reset_email(email: str, token: str) -> None:
    # Custom URL scheme, no HTTPS Universal/App Link: cardgame.local no es un
    # dominio real que podamos hostear, así que no hay forma de publicar
    # apple-app-site-association/assetlinks.json para verificarlo. El
    # frontend registra este scheme (ver frontend/lib/main.dart,
    # core/deep_link.dart) para abrir ResetPasswordPage con el token.
    reset_url = f"cardgame://reset-password?token={token}"
    await send_email(
        to=email,
        subject="Restablecer tu contraseña de CardGame",
        body=(
            f"Hacé click para restablecer tu contraseña: {reset_url}\n\n"
            f"Este link expira en {RESET_TOKEN_EXPIRE_HOURS} hora(s). "
            "Si no lo solicitaste, ignorá este correo."
        ),
    )


@router.post("/request-password-reset", response_model=MessageResponse)
async def request_password_reset(
    payload: RequestPasswordResetRequest, db: Session = Depends(get_db)
):
    user = db.execute(
        select(User).where(User.email == payload.email)
    ).scalar_one_or_none()

    if user is not None:
        token = _generate_token()
        user.reset_token = token
        user.reset_token_expires_at = datetime.now(timezone.utc) + timedelta(
            hours=RESET_TOKEN_EXPIRE_HOURS
        )
        db.commit()
        await _send_password_reset_email(user.email, token)

    # Mismo mensaje exista o no el email — evita enumeración
    return MessageResponse(message=_GENERIC_RESET_REQUEST_MESSAGE)


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.execute(
        select(User).where(User.reset_token == payload.token)
    ).scalar_one_or_none()

    if (
        user is None
        or user.reset_token_expires_at is None
        or user.reset_token_expires_at < datetime.now(timezone.utc)
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=_INVALID_RESET_TOKEN_MESSAGE,
        )

    user.password_hash = hash_password(payload.new_password)
    user.reset_token = None
    user.reset_token_expires_at = None
    db.commit()

    return MessageResponse(message="Contraseña actualizada correctamente")
