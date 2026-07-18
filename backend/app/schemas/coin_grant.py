import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, field_validator


class CoinGrantRequest(BaseModel):
    """`user_identifier`: email o username, lo que sea más a mano para el
    superadmin al momento de otorgar el premio."""

    user_identifier: str
    amount: int
    reason: Optional[str] = None

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("amount debe ser positivo")
        return v


class CoinBroadcastRequest(BaseModel):
    amount: int
    reason: Optional[str] = None

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("amount debe ser positivo")
        return v


class CoinGrantOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    granted_by_username: str
    target_username: Optional[str] = None
    amount: int
    reason: Optional[str] = None
    recipient_count: Optional[int] = None
    created_at: datetime


class CoinGrantResponse(BaseModel):
    """Respuesta de un otorgamiento individual — incluye el saldo
    resultante para que el admin vea el efecto inmediato."""

    grant: CoinGrantOut
    target_coins: int


class CoinBroadcastResponse(BaseModel):
    grant: CoinGrantOut
    recipient_count: int
