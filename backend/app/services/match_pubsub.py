"""Pub/Sub por partida en Redis — el mecanismo por el que un worker que
procesa una acción le avisa al worker que tiene la conexión WebSocket del
rival (ver docs/designs/realtime-match.md, sección "Cómo se enteran los
workers unos de otros: Pub/Sub por partida").
"""
from typing import AsyncIterator
from uuid import UUID

from app.db.redis import get_redis_client
from app.services.match_engine import Match


def _channel(match_id: UUID) -> str:
    return f"match:{match_id}:events"


async def publish_match_update(match: Match) -> None:
    client = await get_redis_client()
    await client.publish(_channel(match.id), match.model_dump_json())


async def subscribe(match_id: UUID):
    """Suscripción confirmada (awaited) separada del consumo — el caller debe
    suscribirse ANTES de leer el snapshot inicial de la partida (match_store)
    y ANTES de dejar que el jugador dispare cualquier acción propia, para no
    perder un `publish` que ocurra en esa ventana (ver mismo razonamiento en
    user_notify.subscribe_user)."""
    client = await get_redis_client()
    pubsub = client.pubsub()
    await pubsub.subscribe(_channel(match_id))
    return pubsub


async def consume(pubsub) -> AsyncIterator[Match]:
    """El worker que consume esto recibe TODO estado canónico publicado en
    la partida — el suyo propio incluido, no hay caso especial "es mi propia
    acción"; ver diseño."""
    try:
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue  # el primer mensaje tras subscribe() es de confirmación, no data
            yield Match.model_validate_json(message["data"])
    finally:
        await pubsub.aclose()


async def listen(match_id: UUID) -> AsyncIterator[Match]:
    """Se suscribe al canal de esta partida y yield-ea cada `Match`
    publicado, hasta que el caller deja de iterar o cancela la task (ej. al
    desconectarse el jugador)."""
    pubsub = await subscribe(match_id)
    async for match in consume(pubsub):
        yield match
