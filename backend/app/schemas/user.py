import uuid
from typing import Optional

from pydantic import BaseModel, ConfigDict, field_validator

from app.schemas import validators


class UserProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    username: str
    avatar_id: str
    coins: int
    email_verified: bool


class UserProfileUpdateRequest(BaseModel):
    username: Optional[str] = None
    avatar_id: Optional[str] = None

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: Optional[str]) -> Optional[str]:
        return validators.validate_username(v) if v is not None else v

    @field_validator("avatar_id")
    @classmethod
    def validate_avatar_id(cls, v: Optional[str]) -> Optional[str]:
        return validators.validate_avatar_id(v) if v is not None else v
