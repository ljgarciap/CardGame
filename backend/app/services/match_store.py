"""Persistencia de partidas en Redis — el store compartido entre
workers/procesos de backend (ver docs/designs/realtime-match.md, sección
"Estado de partida: Redis"). No es Postgres a propósito: el estado de una
partida en curso no necesita sobrevivir un restart.
"""
from contextlib import asynccontextmanager
from typing import AsyncIterator, Optional
from uuid import UUID

from redis.asyncio.lock import Lock

from app.db.redis import get_redis_client
from app.services.match_engine import Match

_MATCH_KEY_PREFIX = "match:"
_LOCK_KEY_PREFIX = "match_lock:"
# Una partida real no debería durar más de esto — evita que una partida
# huérfana (ej. un worker se cae sin limpiar) quede en Redis para siempre.
_MATCH_TTL_SECONDS = 60 * 60 * 2


def _match_key(match_id: UUID) -> str:
    return f"{_MATCH_KEY_PREFIX}{match_id}"


async def save_match(match: Match) -> None:
    client = await get_redis_client()
    await client.set(_match_key(match.id), match.model_dump_json(), ex=_MATCH_TTL_SECONDS)


async def load_match(match_id: UUID) -> Optional[Match]:
    client = await get_redis_client()
    raw = await client.get(_match_key(match_id))
    if raw is None:
        return None
    return Match.model_validate_json(raw)


async def delete_match(match_id: UUID) -> None:
    client = await get_redis_client()
    await client.delete(_match_key(match_id))


@asynccontextmanager
async def match_lock(match_id: UUID) -> AsyncIterator[None]:
    """Lock distribuido (Redis SET NX PX por debajo) — serializa el
    read-modify-write de load_match/save_match entre workers/procesos que
    compiten por la misma partida. Sin esto, dos acciones concurrentes
    sobre la misma partida desde workers distintos podrían pisarse
    (el segundo save_match sobreescribe al primero sin verlo)."""
    client = await get_redis_client()
    lock = Lock(client, f"{_LOCK_KEY_PREFIX}{match_id}", timeout=10)
    acquired = await lock.acquire(blocking=True, blocking_timeout=5)
    if not acquired:
        raise TimeoutError(f"no se pudo tomar el lock de la partida {match_id}")
    try:
        yield
    finally:
        await lock.release()
