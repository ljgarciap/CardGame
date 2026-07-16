"""Pub/Sub por usuario — complementa a match_pubsub.py (que es por
partida). El worker que EMPAREJA a dos jugadores (llama try_pair() y crea
la partida) puede no ser el mismo worker que tiene la conexión WebSocket de
cada uno de esos jugadores — y en ese momento el jugador todavía no conoce
el `match_id`, así que no se puede avisar por el canal de la partida (ese
canal ni existe desde su perspectiva todavía). Este canal, en cambio, se
suscribe apenas se abre la conexión WebSocket de un usuario (antes de saber
si va a jugar una partida o cuál), y es donde llega el aviso de
"te emparejaron, match_id=X" sin importar en qué worker esté conectado.
"""
import json
from typing import Any, AsyncIterator
from uuid import UUID

from app.db.redis import get_redis_client


def _channel(user_id: UUID) -> str:
    return f"user:{user_id}:events"


async def notify_user(user_id: UUID, payload: dict[str, Any]) -> None:
    client = get_redis_client()
    await client.publish(_channel(user_id), json.dumps(payload))


async def subscribe_user(user_id: UUID):
    """Se suscribe y devuelve el pubsub ya confirmado (awaited) — separado de
    `consume` a propósito: el caller debe poder garantizar que la
    suscripción quedó activa ANTES de disparar cualquier acción propia que
    pueda generar una notificación para sí mismo (ej. el jugador que
    completa el emparejamiento con su propio `queue`). Si se combinara
    subscribe+consume en una sola función lanzada como task de fondo, hay
    una ventana real donde el `publish` ocurre antes de que el `subscribe`
    haya ido y vuelto de Redis, y el mensaje se pierde para siempre (Redis
    Pub/Sub no encola nada para quien todavía no está suscripto)."""
    client = get_redis_client()
    pubsub = client.pubsub()
    await pubsub.subscribe(_channel(user_id))
    return pubsub


async def consume(pubsub) -> AsyncIterator[dict[str, Any]]:
    try:
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue
            yield json.loads(message["data"])
    finally:
        await pubsub.aclose()


async def listen_for_user(user_id: UUID) -> AsyncIterator[dict[str, Any]]:
    pubsub = await subscribe_user(user_id)
    async for payload in consume(pubsub):
        yield payload
