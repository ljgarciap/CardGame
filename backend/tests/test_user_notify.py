import asyncio
import uuid

import pytest

from app.services.user_notify import consume, listen_for_user, notify_user, subscribe_user


@pytest.mark.asyncio
async def test_subscriber_receives_notification_for_their_user_id():
    user_id = uuid.uuid4()
    received = []

    async def consumer():
        async for payload in listen_for_user(user_id):
            received.append(payload)
            return

    async def publisher():
        await asyncio.sleep(0.2)
        await notify_user(user_id, {"type": "match_found", "match_id": "abc"})

    await asyncio.wait_for(asyncio.gather(consumer(), publisher()), timeout=5)

    assert received == [{"type": "match_found", "match_id": "abc"}]


@pytest.mark.asyncio
async def test_subscribe_then_consume_is_the_pattern_match_ws_actually_uses():
    """match_ws.py NUNCA llama a listen_for_user() — siempre hace
    subscribe_user() primero (confirmado con await) antes de dejar que el
    jugador dispare cualquier acción propia, y recién después consume. Sin
    este test, una regresión que reordene eso en match_ws.py no la agarraría
    ningún test unitario de este módulo."""
    user_id = uuid.uuid4()

    pubsub = await subscribe_user(user_id)
    await notify_user(user_id, {"type": "match_found", "match_id": "abc"})

    received = None
    async for payload in consume(pubsub):
        received = payload
        break

    assert received == {"type": "match_found", "match_id": "abc"}


@pytest.mark.asyncio
async def test_does_not_receive_notifications_for_other_users():
    user_id = uuid.uuid4()
    other_user_id = uuid.uuid4()
    received = []

    async def consumer():
        async for payload in listen_for_user(user_id):
            received.append(payload)
            return

    async def publisher():
        await asyncio.sleep(0.1)
        await notify_user(other_user_id, {"type": "noise"})
        await asyncio.sleep(0.2)
        await notify_user(user_id, {"type": "match_found", "match_id": "xyz"})

    await asyncio.wait_for(asyncio.gather(consumer(), publisher()), timeout=5)

    assert received == [{"type": "match_found", "match_id": "xyz"}]
