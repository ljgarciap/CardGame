import redis.asyncio as redis

from app.core.config import settings

# Cliente async compartido por todo el proceso — redis-py mantiene su propio
# connection pool internamente, no hace falta un patrón request-scoped como
# get_db() en session.py (Redis no tiene transacciones largas que aislar).
redis_client: redis.Redis = redis.from_url(settings.redis_url, decode_responses=True)
