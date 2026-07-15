import asyncio
import uuid

import pytest

from app.services.match_engine import CardInPlay, Match, MatchPlayerState
from app.services.match_store import delete_match, load_match, match_lock, save_match
from app.models.enums import Faction, Rank, Rarity


def _make_match() -> Match:
    a_id, b_id = uuid.uuid4(), uuid.uuid4()
    card = CardInPlay(
        player_card_id=uuid.uuid4(),
        name="Achilles",
        faction=Faction.greek,
        rank=Rank.hero,
        rarity=Rarity.common,
        attack=30,
        max_defense=30,
        current_defense=30,
    )
    return Match(
        id=uuid.uuid4(),
        players={
            a_id: MatchPlayerState(user_id=a_id, username="alice", hand=[card]),
            b_id: MatchPlayerState(user_id=b_id, username="bob"),
        },
        turn_order=[a_id, b_id],
    )


@pytest.mark.asyncio
async def test_save_and_load_match_round_trips():
    match = _make_match()
    try:
        await save_match(match)
        loaded = await load_match(match.id)

        assert loaded is not None
        assert loaded.id == match.id
        assert loaded.turn_order == match.turn_order
        assert set(loaded.players.keys()) == set(match.players.keys())
        first_player_id = match.turn_order[0]
        assert loaded.players[first_player_id].hand[0].name == "Achilles"
    finally:
        await delete_match(match.id)


@pytest.mark.asyncio
async def test_load_match_returns_none_when_missing():
    assert await load_match(uuid.uuid4()) is None


@pytest.mark.asyncio
async def test_delete_match_removes_it():
    match = _make_match()
    await save_match(match)

    await delete_match(match.id)

    assert await load_match(match.id) is None


@pytest.mark.asyncio
async def test_match_lock_serializes_concurrent_access():
    match_id = uuid.uuid4()
    order: list[str] = []

    async def holder():
        async with match_lock(match_id):
            order.append("holder-acquired")
            await asyncio.sleep(0.3)
            order.append("holder-released")

    async def waiter():
        await asyncio.sleep(0.05)  # asegura que `holder` toma el lock primero
        async with match_lock(match_id):
            order.append("waiter-acquired")

    await asyncio.gather(holder(), waiter())

    # el waiter solo puede haber tomado el lock DESPUÉS de que el holder lo soltó.
    assert order == ["holder-acquired", "holder-released", "waiter-acquired"]
