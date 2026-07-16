import asyncio
import contextlib
from typing import Optional

import redis.asyncio as redis

from app.core.config import settings

_redis_client: Optional[redis.Redis] = None
_redis_client_loop: Optional[asyncio.AbstractEventLoop] = None


async def get_redis_client() -> redis.Redis:
    """Singleton lazy y atado al event loop que lo pide — NO alcanza con
    crearlo perezoso una sola vez (ver historia abajo), también hay que
    reconstruirlo si cambia el loop en el que se lo pide.

    En Python 3.9, `asyncio.Lock()` (que `ConnectionPool` crea internamente)
    se ata al event loop "actual" en el momento en que se construye. Primer
    bug encontrado: crear el cliente a nivel de módulo (import time) lo ata
    a un loop que existe ANTES del loop real que corre la app (Uvicorn crea
    el suyo después) — se resolvió con lazy init en el primer uso real.

    Segundo bug, mismo síntoma ("Task ... got Future attached to a
    different loop"), encontrado recién en tests de integración con
    WebSocket real (TestClient crea un event loop nuevo por conexión/test,
    distinto entre sí y distinto del loop de pytest-asyncio): un singleton
    perezoso pero "atado para siempre" al PRIMER loop que lo construyó
    igual rompe apenas alguien más lo pide desde un loop distinto — y esto
    no es solo un artefacto de tests: cualquier proceso de vida larga que
    llegue a recrear su event loop (ej. un management command que llama
    `asyncio.run()` más de una vez reusando este módulo) pisaría el mismo
    bug en producción. Por eso: si el loop que está pidiendo el cliente
    cambió respecto al que lo construyó, se reconstruye.

    Tercer hallazgo (revisión Senior Reviewer sobre el segundo fix): al
    reconstruir, el cliente viejo se descartaba sin cerrar su connection
    pool — fuga de conexiones en cada cambio de loop (cada test con
    TestClient, por ejemplo). Por eso esta función es ahora `async def`:
    cerrar de verdad el cliente viejo requiere `await`, así que ya no
    alcanza con una función sync — todos los callers pasan a hacer
    `await get_redis_client()`.
    """
    global _redis_client, _redis_client_loop
    current_loop = asyncio.get_running_loop()
    if _redis_client is None or _redis_client_loop is not current_loop:
        if _redis_client is not None:
            # Best-effort: el loop viejo puede ya estar cerrado (ej. el
            # portal de un test anterior ya se destruyó) — no dejamos que
            # una falla acá impida construir el cliente nuevo.
            with contextlib.suppress(Exception):
                await _redis_client.aclose()
        _redis_client = redis.from_url(settings.redis_url, decode_responses=True)
        _redis_client_loop = current_loop
    return _redis_client
