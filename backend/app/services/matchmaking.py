"""Cola de matchmaking en Redis — cualquier worker/proceso puede encolar o
intentar emparejar, no vive en memoria de un solo proceso (ver
docs/designs/realtime-match.md, sección "Matchmaking: cola en Redis").
"""
from typing import Optional
from uuid import UUID

from pydantic import BaseModel

from app.db.redis import get_redis_client
from app.services.match_engine import CardInPlay

_QUEUE_KEY = "match_queue"

# Emparejar tiene que ser atómico entre procesos: un LLEN + RPOP en pasos
# separados tiene race condition si dos workers lo corren casi a la vez
# (ambos podrían ver len>=2 y cada uno popear la misma entrada). Redis
# ejecuta un script Lua de forma atómica sin importar cuántos workers lo
# disparen al mismo tiempo — es la única forma segura de hacer esto sin un
# proceso "matchmaker" central corriendo en loop.
_TRY_PAIR_SCRIPT = """
local len = redis.call('LLEN', KEYS[1])
if len >= 2 then
    local p1 = redis.call('RPOP', KEYS[1])
    local p2 = redis.call('RPOP', KEYS[1])
    return {p1, p2}
end
return false
"""

# Buscar-y-sacar en un solo EVAL, no LRANGE+LREM en dos viajes separados:
# Redis ejecuta un script a la vez (modelo single-threaded), así que esto no
# puede intercalarse con _TRY_PAIR_SCRIPT — sin esto, un `try_pair` de otro
# worker puede ganarle la carrera a un `leave_queue` disparado por una
# desconexión, emparejando a un jugador que ya no tiene conexión y dejando
# al rival esperando una jugada que nunca llega.
_LEAVE_QUEUE_SCRIPT = """
local entries = redis.call('LRANGE', KEYS[1], 0, -1)
for i, raw in ipairs(entries) do
    local entry = cjson.decode(raw)
    if entry.user_id == ARGV[1] then
        redis.call('LREM', KEYS[1], 1, raw)
        return 1
    end
end
return 0
"""


class QueueEntry(BaseModel):
    user_id: UUID
    username: str
    deck: list[CardInPlay]


async def enqueue(entry: QueueEntry) -> None:
    client = await get_redis_client()
    await client.lpush(_QUEUE_KEY, entry.model_dump_json())


async def leave_queue(user_id: UUID) -> bool:
    """Busca y saca a este usuario de la cola, si todavía está esperando.
    Devuelve True si lo encontró y sacó. Atómico (ver _LEAVE_QUEUE_SCRIPT)."""
    client = await get_redis_client()
    removed = await client.eval(_LEAVE_QUEUE_SCRIPT, 1, _QUEUE_KEY, str(user_id))
    return bool(removed)


async def try_pair() -> Optional[tuple[QueueEntry, QueueEntry]]:
    """Si hay 2 o más jugadores en cola, saca a los primeros 2 de forma
    atómica y los devuelve emparejados (orden FIFO puro, sin ELO ni
    prioridad). Si no hay suficientes, devuelve None sin tocar la cola."""
    client = await get_redis_client()
    result = await client.eval(_TRY_PAIR_SCRIPT, 1, _QUEUE_KEY)
    if not result:
        return None
    raw_a, raw_b = result
    return QueueEntry.model_validate_json(raw_a), QueueEntry.model_validate_json(raw_b)
