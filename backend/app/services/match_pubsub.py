"""Pub/Sub por partida en Redis — el mecanismo por el que un worker que
procesa una acción le avisa al worker que tiene la conexión WebSocket del
rival (ver docs/designs/realtime-match.md, sección "Cómo se enteran los
workers unos de otros: Pub/Sub por partida").
"""
from typing import AsyncIterator, NamedTuple
from uuid import UUID

from pydantic import TypeAdapter

from app.db.redis import get_redis_client
from app.services.match_engine import AttackEvent, Match

_events_adapter = TypeAdapter(list[AttackEvent])


class MatchUpdate(NamedTuple):
    """Snapshot canónico de la partida + los ataques resueltos que la
    produjeron (vacío para acciones que no atacan, ej. play_card/end_turn
    sin turno del bot) — el cliente necesita cada golpe individual, en
    orden, para animar "quién le pegó a quién" en vez de inferirlo
    comparando el estado anterior con el nuevo (frágil con varios ataques
    del bot en el mismo turno)."""

    match: Match
    events: list[AttackEvent]


def _channel(match_id: UUID) -> str:
    return f"match:{match_id}:events"


async def publish_match_update(match: Match, events: list[AttackEvent] | None = None) -> None:
    client = await get_redis_client()
    payload = {
        "match": match.model_dump(mode="json"),
        "events": [e.model_dump(mode="json") for e in (events or [])],
    }
    await client.publish(_channel(match.id), TypeAdapter(dict).dump_json(payload))


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


async def consume(pubsub) -> AsyncIterator[MatchUpdate]:
    """El worker que consume esto recibe TODO estado canónico publicado en
    la partida — el suyo propio incluido, no hay caso especial "es mi propia
    acción"; ver diseño."""
    try:
        async for message in pubsub.listen():
            if message["type"] != "message":
                continue  # el primer mensaje tras subscribe() es de confirmación, no data
            raw = TypeAdapter(dict).validate_json(message["data"])
            yield MatchUpdate(
                match=Match.model_validate(raw["match"]),
                events=_events_adapter.validate_python(raw["events"]),
            )
    finally:
        await pubsub.aclose()


async def listen(match_id: UUID) -> AsyncIterator[MatchUpdate]:
    """Se suscribe al canal de esta partida y yield-ea cada `MatchUpdate`
    publicado, hasta que el caller deja de iterar o cancela la task (ej. al
    desconectarse el jugador)."""
    pubsub = await subscribe(match_id)
    async for update in consume(pubsub):
        yield update
