import pytest
import pytest_asyncio
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.db.base import Base
from app.db.redis import get_redis_client
from app.db.session import get_db
from app.main import app
from app.models import user as _user  # noqa: F401 registers User on Base.metadata
from app.models import card_archetype as _card_archetype  # noqa: F401
from app.models import player_card as _player_card  # noqa: F401
from app.models import gacha_config as _gacha_config  # noqa: F401
from app.models import deck as _deck  # noqa: F401

engine = create_engine(settings.database_url)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def _setup_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest_asyncio.fixture(autouse=True)
async def _setup_redis():
    """Sin esto, estado de una corrida (cola de matchmaking, partidas,
    canales) sobrevive entre tests/corridas contra el Redis persistente de
    desarrollo — un jugador "fantasma" de una corrida anterior puede quedar
    en `match_queue` y emparejarse con un jugador real de una corrida nueva,
    con un user_id que ya no corresponde a nadie conectado (bug real que
    causó un hang silencioso en test_match_ws.py)."""
    await (await get_redis_client()).flushdb()
    yield
    await (await get_redis_client()).flushdb()


@pytest.fixture
def db_session():
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client():
    def _override_get_db():
        session = TestingSessionLocal()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = _override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
