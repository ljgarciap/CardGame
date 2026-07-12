import socket

import pytest

from app.core.config import settings
from app.core.email import send_email


def _smtp_reachable() -> bool:
    try:
        with socket.create_connection((settings.smtp_host, settings.smtp_port), timeout=1):
            return True
    except OSError:
        return False


@pytest.mark.asyncio
@pytest.mark.skipif(
    not _smtp_reachable(),
    reason="Servidor SMTP no disponible (docker compose up mailhog)",
)
async def test_send_email_reaches_smtp_server():
    await send_email(
        to="test@example.com",
        subject="Test Subject",
        body="Test body",
    )
