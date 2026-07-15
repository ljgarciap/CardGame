from typing import Optional

import redis.asyncio as redis

from app.core.config import settings

_redis_client: Optional[redis.Redis] = None


def get_redis_client() -> redis.Redis:
    """Singleton lazy — NO crear el cliente a nivel de módulo (import time).
    En Python 3.9, `asyncio.Lock()` (que `ConnectionPool` crea internamente)
    se ata al event loop "actual" en el momento en que se construye; si el
    cliente se crea al importar el módulo, eso pasa ANTES de que exista el
    loop real que corre la app (Uvicorn lo crea después), y el lock queda
    atado a un loop equivocado — funciona con una sola operación a la vez,
    pero rompe con concurrencia real ("Task ... got Future attached to a
    different loop"). Construyendo el cliente en el primer uso real, ya
    adentro del loop que corre la app, el lock se ata al loop correcto.
    Verificado con un test de 30 llamadas concurrentes reales (ver
    tests/test_matchmaking.py) — sin este fix, rompía de forma reproducible.
    """
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(settings.redis_url, decode_responses=True)
    return _redis_client
