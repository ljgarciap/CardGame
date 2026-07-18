import uuid

from pydantic import BaseModel, EmailStr, field_validator

from app.schemas import validators


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    username: str
    avatar_id: str

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        return validators.validate_password(v)

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        return validators.validate_username(v)

    @field_validator("avatar_id")
    @classmethod
    def validate_avatar_id(cls, v: str) -> str:
        return validators.validate_avatar_id(v)


class RegisterResponse(BaseModel):
    id: uuid.UUID
    email: str
    username: str
    message: str = "Revisa tu correo para verificar tu cuenta."


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class RequestPasswordResetRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        return validators.validate_password(v)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        return validators.validate_password(v)


class MessageResponse(BaseModel):
    message: str
