import asyncio
import uuid

import pytest

from app.services.user_notify import listen_for_user, notify_user


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
