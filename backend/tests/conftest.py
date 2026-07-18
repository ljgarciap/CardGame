from urllib.parse import urlsplit, urlunsplit

import psycopg2
import pytest
import pytest_asyncio
from fastapi.testclient import TestClient
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from sqlalchemy import create_engine
from sqlalchemy.engine import make_url
from sqlalchemy.orm import sessionmaker

from app.core.config import settings


def _test_database_url(dev_url: str) -> str:
    """Los tests nunca deben correr contra la base de desarrollo: la
    fixture `_setup_db` hace `create_all`/`drop_all` en cada test, así que
    correr `pytest` directo contra `settings.database_url` (bug real, así
    estaba antes) le vaciaba coins/mazos/todo a cualquiera probando la app
    en simultáneo. Se usa `<db>_test` en el mismo server en su lugar,
    creada sola la primera vez que hace falta."""
    url = make_url(dev_url)
    test_db_name = f"{url.database}_test"

    maintenance_conn = psycopg2.connect(
        dbname="postgres",
        user=url.username,
        password=url.password,
        host=url.host,
        port=url.port,
    )
    maintenance_conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    try:
        with maintenance_conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (test_db_name,))
            if cur.fetchone() is None:
                cur.execute(f'CREATE DATABASE "{test_db_name}"')
    finally:
        maintenance_conn.close()

    # str(url) enmascara la contraseña con "***" (repr seguro por default
    # en SQLAlchemy 1.4+) -- hay que pedir el string real explícitamente.
    return url.set(database=test_db_name).render_as_string(hide_password=False)


def _test_redis_url(dev_url: str) -> str:
    """Mismo criterio que la base de test: `_setup_redis` hace `flushdb()`
    en cada test, así que compartir el Redis de desarrollo borraba estado
    real (cola de matchmaking, partidas en curso) de cualquiera probando la
    app en simultáneo. Alcanza con otro índice de DB dentro del mismo
    server/puerto (Redis separa datos por índice), no hace falta un Redis
    aparte."""
    parts = urlsplit(dev_url)
    return urlunsplit(parts._replace(path="/1"))


# Mutar ANTES de importar cualquier otro módulo de la app: app/db/session.py
# construye su propio engine/SessionLocal a nivel de módulo con
# settings.database_url en el momento del import. Si mutamos después de que
# algo ya lo importó (ej. después de `from app.main import app`), ese engine
# queda atado a la base de desarrollo para siempre y ningún override de
# dependencias lo cubre. Bug real encontrado acá: app/api/match_ws.py usa
# `SessionLocal` directo (no `Depends(get_db)`, no se puede con WebSockets
# de la misma forma), así que los tests de WebSocket rompían con un 4401
# ("token inválido") porque el usuario de test no existía del lado de la
# base real -- el resto de los tests (HTTP, vía TestClient) no lo notaba
# porque `Depends(get_db)` sí tiene override.
settings.database_url = _test_database_url(settings.database_url)
settings.redis_url = _test_redis_url(settings.redis_url)

from app.db.base import Base  # noqa: E402
from app.db.redis import get_redis_client  # noqa: E402
from app.db.session import get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.models import user as _user  # noqa: E402,F401 registers User on Base.metadata
from app.models import card_archetype as _card_archetype  # noqa: E402,F401
from app.models import player_card as _player_card  # noqa: E402,F401
from app.models import gacha_config as _gacha_config  # noqa: E402,F401
from app.models import deck as _deck  # noqa: E402,F401
from app.models import deck_config as _deck_config  # noqa: E402,F401

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
    canales) sobrevive entre tests/corridas — un jugador "fantasma" de una
    corrida anterior puede quedar en `match_queue` y emparejarse con un
    jugador real de una corrida nueva, con un user_id que ya no corresponde
    a nadie conectado (bug real que causó un hang silencioso en
    test_match_ws.py)."""
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
