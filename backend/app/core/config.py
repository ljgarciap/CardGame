from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=False)

    database_url: str = "postgresql://user:password@localhost:5432/card_game"
    jwt_secret_key: str = "dev-secret-change-in-production"

    smtp_host: str = "localhost"
    smtp_port: int = 1025
    smtp_use_tls: bool = False
    smtp_from: str = "noreply@cardgame.local"
    # None en dev (Mailhog no pide auth) -- un SMTP real (Gmail, SendGrid,
    # etc.) sí la exige, así que send_email los pasa solo si están seteados.
    smtp_user: Optional[str] = None
    smtp_password: Optional[str] = None

    redis_url: str = "redis://localhost:6379/0"


settings = Settings()
