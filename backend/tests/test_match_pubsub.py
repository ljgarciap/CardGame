import asyncio
import uuid

import pytest

from app.models.enums import Faction, Rank, Rarity
from app.services.match_engine import CardInPlay, Match, MatchPlayerState
from app.services.match_pubsub import consume, listen, publish_match_update, subscribe


def _make_match() -> Match:
    a_id, b_id = uuid.uuid4(), uuid.uuid4()
    card = CardInPlay(
        player_card_id=uuid.uuid4(),
        name="Zeus, King of Olympus",
        faction=Faction.greek,
        rank=Rank.major_god,
        rarity=Rarity.legendary,
        attack=108,
        max_defense=108,
        current_defense=108,
    )
    return Match(
        id=uuid.uuid4(),
        players={
            a_id: MatchPlayerState(user_id=a_id, username="alice", board=[card]),
            b_id: MatchPlayerState(user_id=b_id, username="bob"),
        },
        turn_order=[a_id, b_id],
    )


@pytest.mark.asyncio
async def test_subscriber_receives_published_match_update():
    """Simula 2 workers: uno se suscribe (como si tuviera la conexión
    WebSocket del rival) y otro publica (como si acabara de procesar una
    acción) — sobre Redis real, no un mock en memoria."""
    match = _make_match()
    received: list[Match] = []

    async def consumer():
        async for received_match in listen(match.id):
            received.append(received_match)
            return  # solo nos interesa el primer mensaje real

    async def publisher():
        await asyncio.sleep(0.2)  # da tiempo a que el consumer se suscriba antes de publicar
        await publish_match_update(match)

    await asyncio.wait_for(asyncio.gather(consumer(), publisher()), timeout=5)

    assert len(received) == 1
    assert received[0].id == match.id
    assert received[0].players[match.turn_order[0]].board[0].name == "Zeus, King of Olympus"


@pytest.mark.asyncio
async def test_subscribers_do_not_receive_updates_from_other_matches():
    match_a = _make_match()
    match_b = _make_match()
    received: list[Match] = []

    async def consumer():
        async for received_match in listen(match_a.id):
            received.append(received_match)
            return

    async def publisher():
        await asyncio.sleep(0.1)
        await publish_match_update(match_b)  # partida distinta, no debería llegar
        await asyncio.sleep(0.2)
        await publish_match_update(match_a)  # esta sí

    await asyncio.wait_for(asyncio.gather(consumer(), publisher()), timeout=5)

    assert len(received) == 1
    assert received[0].id == match_a.id


@pytest.mark.asyncio
async def test_subscribe_then_consume_is_the_pattern_match_ws_actually_uses():
    """match_ws.py NUNCA llama a listen() — siempre hace subscribe() primero
    (confirmado con await), hace otro trabajo (leer el snapshot inicial,
    mandar match_found) y recién después arranca a consumir. listen() solo
    lo ejercitan los demás tests de este archivo, así que una regresión que
    reordene subscribe/trabajo-intermedio en match_ws.py no la agarraría
    ningún test unitario si este no existiera."""
    match = _make_match()

    pubsub = await subscribe(match.id)
    # "otro trabajo" real entre el subscribe confirmado y el consume, tal
    # como hace match_ws.py — si el subscribe no estuviera confirmado antes
    # de este punto, este publish se perdería para siempre.
    await publish_match_update(match)

    received = None
    async for received_match in consume(pubsub):
        received = received_match
        break

    assert received is not None
    assert received.id == match.id


@pytest.mark.asyncio
async def test_multiple_subscribers_all_receive_the_same_update():
    """El caso real: 2 workers, cada uno con la conexión de un jugador
    distinto de la MISMA partida, ambos suscriptos al mismo canal — los dos
    tienen que recibir el mismo estado publicado."""
    match = _make_match()
    received_by_worker_a: list[Match] = []
    received_by_worker_b: list[Match] = []

    async def worker_a():
        async for received_match in listen(match.id):
            received_by_worker_a.append(received_match)
            return

    async def worker_b():
        async for received_match in listen(match.id):
            received_by_worker_b.append(received_match)
            return

    async def publisher():
        await asyncio.sleep(0.2)
        await publish_match_update(match)

    await asyncio.wait_for(asyncio.gather(worker_a(), worker_b(), publisher()), timeout=5)

    assert len(received_by_worker_a) == 1
    assert len(received_by_worker_b) == 1
    assert received_by_worker_a[0].id == received_by_worker_b[0].id == match.id
