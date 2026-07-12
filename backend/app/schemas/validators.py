import re

from app.core.constants import AVATAR_PRESETS

_USERNAME_RE = re.compile(r"^[a-zA-Z0-9_]{3,30}$")


def validate_password(v: str) -> str:
    if len(v) < 8:
        raise ValueError("la contraseña debe tener al menos 8 caracteres")
    if len(v.encode("utf-8")) > 72:
        raise ValueError("la contraseña no puede superar los 72 bytes")
    return v


def validate_username(v: str) -> str:
    if not _USERNAME_RE.match(v):
        raise ValueError(
            "username debe tener 3-30 caracteres alfanuméricos o guion bajo"
        )
    return v


def validate_avatar_id(v: str) -> str:
    if v not in AVATAR_PRESETS:
        raise ValueError(f"avatar_id inválido, debe ser uno de: {sorted(AVATAR_PRESETS)}")
    return v
