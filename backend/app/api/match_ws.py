"""Endpoint WebSocket de partidas en tiempo real — integra matchmaking,
match_engine, match_store, match_pubsub y user_notify. Ver
docs/designs/realtime-match.md para el protocolo completo y el porqué de
cada pieza.

`_local_connections`/`_local_match_ids` son estado de ESTE proceso/worker
únicamente (qué conexiones WebSocket tiene ESTE worker ahora mismo) — el
estado que sí es compartido entre workers vive en Redis
(match_store/matchmaking), nunca acá.
"""
import asyncio
import contextlib
import uuid
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from starlette.concurrency import run_in_threadpool

from app.api import deps
from app.db.session import SessionLocal
from app.models.user import User
from app.services import bot, match_pubsub, match_store, matchmaking, user_notify
from app.services.card_ownership import load_owned_cards
from app.services.combat_balance import get_or_create_combat_balance_config
from app.services.match_engine import (
    DECK_SIZE,
    AttackEvent,
    CardInPlay,
    MatchRuleViolation,
    attack,
    build_state_view,
    end_turn,
    forfeit,
    handle_disconnect,
    play_card,
    start_match,
)

router = APIRouter()

_local_connections: dict[UUID, WebSocket] = {}
_local_match_ids: dict[UUID, UUID] = {}


def _load_user_sync(token: str) -> Optional[User]:
    with SessionLocal() as db:
        return deps.resolve_user_by_token(db, token)


async def _authenticate(websocket: WebSocket) -> Optional[User]:
    """Abre su propia sesión de DB de vida corta (vía threadpool, ver
    _load_user_sync) en vez de recibir una inyectada por la conexión
    entera — no hay razón para tener una sesión reservada del pool durante
    toda la partida por una consulta que solo corre una vez, al conectar."""
    token = websocket.query_params.get("token")
    if not token:
        return None
    return await run_in_threadpool(_load_user_sync, token)


def _resolve_deck_sync(user_id: UUID, raw_deck: list) -> list[CardInPlay]:
    try:
        player_card_ids = [uuid.UUID(str(cid)) for cid in raw_deck]
    except (ValueError, TypeError, AttributeError):
        raise MatchRuleViolation("deck inválido")

    if len(player_card_ids) != DECK_SIZE or len(set(player_card_ids)) != DECK_SIZE:
        raise MatchRuleViolation(f"el mazo debe tener exactamente {DECK_SIZE} cartas distintas")

    with SessionLocal() as db:
        rows = load_owned_cards(db, user_id, player_card_ids=player_card_ids)
    by_id = {player_card.id: (player_card, archetype) for player_card, archetype in rows}
    if len(by_id) != DECK_SIZE:
        raise MatchRuleViolation("alguna carta del mazo no existe o no te pertenece")

    cards = []
    for player_card_id in player_card_ids:
        player_card, archetype = by_id[player_card_id]
        cards.append(
            CardInPlay(
                player_card_id=player_card.id,
                name=archetype.name,
                faction=archetype.faction,
                rank=archetype.rank,
                rarity=player_card.rarity,
                attack=player_card.attack,
                max_defense=player_card.defense,
                current_defense=player_card.defense,
            )
        )
    return cards


async def _resolve_deck(user: User, raw_deck: list) -> list[CardInPlay]:
    """Correr `db.execute` sync directo en el event loop del worker bloquea
    la entrega de state_update/match_over a TODAS las demás conexiones que
    ese mismo worker tiene abiertas mientras dura la consulta — por eso el
    trabajo sync entero (abrir sesión, consultar, cerrar) va a un thread
    aparte vía `run_in_threadpool`, no directo en la coroutine."""
    return await run_in_threadpool(_resolve_deck_sync, user.id, raw_deck)


def _load_starting_life_sync() -> int:
    with SessionLocal() as db:
        config = get_or_create_combat_balance_config(db)
        db.commit()
        return config.starting_life


async def _load_starting_life() -> int:
    return await run_in_threadpool(_load_starting_life_sync)


async def _try_start_match() -> None:
    """Se llama después de cada `queue` exitoso — si hay 2+ jugadores en
    cola, arma la partida y avisa a ambos por user_notify (sin importar en
    qué worker esté conectado cada uno)."""
    pair = await matchmaking.try_pair()
    if pair is None:
        return

    entry_a, entry_b = pair
    starting_life = await _load_starting_life()
    match = start_match(
        match_id=uuid.uuid4(),
        player_a=(entry_a.user_id, entry_a.username, entry_a.deck),
        player_b=(entry_b.user_id, entry_b.username, entry_b.deck),
        starting_life=starting_life,
    )
    await match_store.save_match(match)

    for entry, opponent in ((entry_a, entry_b), (entry_b, entry_a)):
        await user_notify.notify_user(
            entry.user_id,
            {
                "type": "match_found",
                "match_id": str(match.id),
                "opponent_username": opponent.username,
            },
        )


async def _handle_queue(user: User, raw_deck: list, websocket: WebSocket) -> None:
    if user.id in _local_match_ids:
        raise MatchRuleViolation("ya estás en una partida")

    cards = await _resolve_deck(user, raw_deck)
    await matchmaking.enqueue(
        matchmaking.QueueEntry(user_id=user.id, username=user.username, deck=cards)
    )
    await websocket.send_json({"type": "queued"})
    await _try_start_match()


def _build_bot_deck_sync() -> list[CardInPlay]:
    with SessionLocal() as db:
        # get_or_create_rank_base_stats (dentro de build_bot_deck) hace
        # flush, no commit -- normalmente ya está sembrado por la migración
        # y esto es un no-op, pero si algún ambiente llega sin sembrar, el
        # commit evita que la fila creada se pierda al cerrar la sesión.
        deck = bot.build_bot_deck(db)
        db.commit()
        return deck


async def _handle_start_bot_match(user: User, raw_deck: list, websocket: WebSocket) -> None:
    """Arranca una partida al toque contra el bot de práctica ("Eco"), sin
    pasar por la cola de matchmaking real. Reusa exactamente el mismo
    protocolo (`match_found` vía user_notify) que un emparejamiento
    real, así que el resto del cliente (MatchPage, _forward_events) no
    necesita saber que el rival es un bot."""
    if user.id in _local_match_ids:
        raise MatchRuleViolation("ya estás en una partida")

    # Defensivo: si el jugador estaba en la cola de matchmaking real y
    # decide practicar contra el bot en su lugar, no lo dejamos ahí
    # esperando un emparejamiento que ya no le importa.
    await matchmaking.leave_queue(user.id)

    human_cards = await _resolve_deck(user, raw_deck)
    bot_cards = await run_in_threadpool(_build_bot_deck_sync)
    starting_life = await _load_starting_life()

    match = start_match(
        match_id=uuid.uuid4(),
        player_a=(user.id, user.username, human_cards),
        player_b=(bot.BOT_USER_ID, bot.BOT_USERNAME, bot_cards),
        starting_life=starting_life,
    )
    bot.run_bot_turn(match)  # por si el orden de turno al azar le tocó arrancar a él
    await match_store.save_match(match)

    await user_notify.notify_user(
        user.id,
        {
            "type": "match_found",
            "match_id": str(match.id),
            "opponent_username": bot.BOT_USERNAME,
        },
    )


def _attack_event_json(event: AttackEvent) -> dict:
    return {
        "type": "attack_event",
        "attacking_player_id": str(event.attacking_player_id),
        "attacker_id": str(event.attacker_id),
        "attacker_name": event.attacker_name,
        "target": "face" if event.target == "face" else {"card_id": str(event.target)},
        "target_name": event.target_name,
        "damage": event.damage,
        "target_defeated": event.target_defeated,
    }


async def _handle_match_action(user_id: UUID, action: str, raw: dict) -> None:
    match_id = _local_match_ids.get(user_id)
    if match_id is None:
        raise MatchRuleViolation("no estás en ninguna partida")

    events: list[AttackEvent] = []

    async with match_store.match_lock(match_id):
        match = await match_store.load_match(match_id)
        if match is None:
            raise MatchRuleViolation("la partida ya no existe")

        if action == "play_card":
            play_card(match, user_id, uuid.UUID(str(raw["player_card_id"])))
        elif action == "attack":
            target = raw["target"]
            target_value = "face" if target == "face" else uuid.UUID(str(target["card_id"]))
            events.append(attack(match, user_id, uuid.UUID(str(raw["attacker_id"])), target_value))
        elif action == "end_turn":
            end_turn(match, user_id)
            # Si el rival es el bot de práctica, le toca jugar su turno
            # entero acá mismo, sincrónico -- reusa las mismas funciones de
            # match_engine que un humano, así que el save/publish de más
            # abajo ya cubre difundir el resultado, no hace falta repetirlo.
            if not match.is_over and bot.is_bot_turn(match):
                events.extend(bot.run_bot_turn(match))
        elif action == "forfeit":
            forfeit(match, user_id)

        await match_store.save_match(match)

    await match_pubsub.publish_match_update(match, events)


async def _forward_match_events(user_id: UUID, match_pubsub_conn, websocket: WebSocket) -> None:
    async for update in match_pubsub.consume(match_pubsub_conn):
        match = update.match
        for event in update.events:
            await websocket.send_json(_attack_event_json(event))

        if match.is_over:
            await websocket.send_json(
                {
                    "type": "match_over",
                    "winner_user_id": str(match.winner_user_id) if match.winner_user_id else None,
                    "reason": match.reason,
                }
            )
            _local_match_ids.pop(user_id, None)
            return
        await websocket.send_json({"type": "state_update", "state": build_state_view(match, user_id)})


async def _forward_events(user_id: UUID, websocket: WebSocket, user_pubsub) -> None:
    """Tarea de fondo por conexión: primero escucha el canal de usuario
    (emparejamiento) sobre una suscripción ya confirmada (ver
    match_websocket), y al recibir un match_found pasa a escuchar el canal
    de esa partida — reenvía todo al WebSocket local."""
    async for notification in user_notify.consume(user_pubsub):
        if notification.get("type") != "match_found":
            continue

        match_id = UUID(notification["match_id"])
        _local_match_ids[user_id] = match_id

        # Suscribirse al canal de la partida ANTES de leer el snapshot
        # inicial (y antes de mandar match_found, que es lo que habilita al
        # cliente a empezar a jugar) — evita perder un publish de un rival
        # que actúe muy rápido, incluida la partida ya terminada por forfeit
        # inmediato.
        match_pubsub_conn = await match_pubsub.subscribe(match_id)

        await websocket.send_json(
            {
                "type": "match_found",
                "match_id": str(match_id),
                "opponent_username": notification["opponent_username"],
            }
        )

        match = await match_store.load_match(match_id)
        if match is not None:
            await websocket.send_json(
                {"type": "state_update", "state": build_state_view(match, user_id)}
            )

        await _forward_match_events(user_id, match_pubsub_conn, websocket)


async def _resolve_disconnect(user_id: UUID) -> None:
    await matchmaking.leave_queue(user_id)
    match_id = _local_match_ids.pop(user_id, None)
    if match_id is None:
        return
    async with match_store.match_lock(match_id):
        match = await match_store.load_match(match_id)
        if match is None or match.is_over:
            return
        handle_disconnect(match, user_id)
        await match_store.save_match(match)
    await match_pubsub.publish_match_update(match)


@router.websocket("/ws/match")
async def match_websocket(websocket: WebSocket):
    user = await _authenticate(websocket)
    if user is None:
        # Rechazar el handshake sin aceptar: el cliente ve el connect fallar
        # en vez de una conexión abierta que se cierra sola al instante.
        await websocket.close(code=4401)
        return

    await websocket.accept()
    _local_connections[user.id] = websocket

    # Suscripción al canal de usuario confirmada ANTES de aceptar cualquier
    # mensaje del cliente — si no, un `queue` que el propio jugador manda
    # apenas conecta puede completar el emparejamiento y publicar su propio
    # match_found antes de que esta suscripción termine de ir y volver de
    # Redis, perdiendo la notificación para siempre (ver user_notify.py).
    user_pubsub = await user_notify.subscribe_user(user.id)
    forward_task = asyncio.create_task(_forward_events(user.id, websocket, user_pubsub))

    try:
        while True:
            try:
                raw = await websocket.receive_json()
                action = raw.get("action")
            except (KeyError, ValueError, TypeError, AttributeError):
                # JSON inválido (ValueError) o JSON válido que no es un
                # objeto, ej. un número/string/lista/null (AttributeError en
                # .get) — se responde y se sigue, en vez de tirar la
                # conexión entera por un mensaje mal formado del cliente.
                await websocket.send_json({"type": "error", "detail": "mensaje inválido"})
                continue

            try:
                if action == "queue":
                    await _handle_queue(user, raw.get("deck", []), websocket)
                elif action == "start_bot_match":
                    await _handle_start_bot_match(user, raw.get("deck", []), websocket)
                elif action == "leave_queue":
                    await matchmaking.leave_queue(user.id)
                elif action in ("play_card", "attack", "end_turn", "forfeit"):
                    await _handle_match_action(user.id, action, raw)
                else:
                    await websocket.send_json(
                        {"type": "error", "detail": f"acción desconocida: {action}"}
                    )
            except MatchRuleViolation as e:
                await websocket.send_json({"type": "error", "detail": str(e)})
            except (KeyError, ValueError, TypeError):
                await websocket.send_json({"type": "error", "detail": "mensaje inválido"})
    except WebSocketDisconnect:
        pass
    finally:
        _local_connections.pop(user.id, None)
        forward_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            # Esperar a que la propia limpieza de forward_task (incluido su
            # pubsub.aclose()) termine ANTES de que _resolve_disconnect haga
            # su propio I/O real contra Redis sobre el mismo cliente
            # compartido — sin este await, ambas corren concurrentemente y
            # pueden pisarse la conexión (la misma clase de bug que ya se
            # encontró y corrigió en el test de desconexión, pero acá viva
            # en el propio endpoint).
            await forward_task
        await _resolve_disconnect(user.id)
