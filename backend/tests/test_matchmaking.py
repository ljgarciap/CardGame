import asyncio
import uuid

import pytest
import pytest_asyncio

from app.db.redis import get_redis_client
from app.services.matchmaking import QueueEntry, _QUEUE_KEY, enqueue, leave_queue, try_pair


def _make_entry(username: str = "player") -> QueueEntry:
    return QueueEntry(user_id=uuid.uuid4(), username=username, deck=[])


@pytest_asyncio.fixture(autouse=True)
async def _clean_queue():
    await get_redis_client().delete(_QUEUE_KEY)
    yield
    await get_redis_client().delete(_QUEUE_KEY)


@pytest.mark.asyncio
async def test_try_pair_returns_none_when_fewer_than_two_queued():
    await enqueue(_make_entry("solo"))
    assert await try_pair() is None


@pytest.mark.asyncio
async def test_try_pair_pairs_two_queued_players():
    a = _make_entry("alice")
    b = _make_entry("bob")
    await enqueue(a)
    await enqueue(b)

    pair = await try_pair()

    assert pair is not None
    paired_ids = {pair[0].user_id, pair[1].user_id}
    assert paired_ids == {a.user_id, b.user_id}


@pytest.mark.asyncio
async def test_try_pair_removes_paired_players_from_queue():
    await enqueue(_make_entry("alice"))
    await enqueue(_make_entry("bob"))

    await try_pair()

    assert await get_redis_client().llen(_QUEUE_KEY) == 0


@pytest.mark.asyncio
async def test_leave_queue_removes_only_that_player():
    a = _make_entry("alice")
    b = _make_entry("bob")
    await enqueue(a)
    await enqueue(b)

    removed = await leave_queue(a.user_id)

    assert removed is True
    assert await get_redis_client().llen(_QUEUE_KEY) == 1
    remaining = await try_pair()
    assert remaining is None  # solo queda bob, no alcanza para emparejar


@pytest.mark.asyncio
async def test_leave_queue_returns_false_when_not_queued():
    assert await leave_queue(uuid.uuid4()) is False


@pytest.mark.asyncio
async def test_concurrent_try_pair_never_double_pairs_or_loses_players():
    """El caso real que importa: muchos workers llamando try_pair() casi al
    mismo tiempo sobre la misma cola no deberían nunca emparejar al mismo
    jugador dos veces ni perder a nadie. Esto ejercita la atomicidad real
    del script Lua contra Redis, no una simulación en memoria."""
    entries = [_make_entry(f"player-{i}") for i in range(20)]  # 10 pares esperados
    for entry in entries:
        await enqueue(entry)

    results = await asyncio.gather(*[try_pair() for _ in range(30)])  # más intentos que pares posibles
    successful_pairs = [r for r in results if r is not None]

    assert len(successful_pairs) == 10  # exactamente 10 pares, ni más ni menos

    paired_user_ids = []
    for pair in successful_pairs:
        paired_user_ids.extend([pair[0].user_id, pair[1].user_id])

    assert len(paired_user_ids) == len(set(paired_user_ids)), "un jugador quedó emparejado más de una vez"
    assert set(paired_user_ids) == {e.user_id for e in entries}, "algún jugador se perdió o sobró"
