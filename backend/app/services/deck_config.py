from sqlalchemy.orm import Session

from app.db.seed_deck_config import DEFAULT_MAX_DECKS_PER_USER
from app.models.deck_config import DeckConfig

_ROW_ID = 1


def get_or_create_deck_config(db: Session) -> DeckConfig:
    """La migración siembra la fila id=1, pero un ambiente de test que arma
    el schema con `Base.metadata.create_all` (sin correr migraciones) no la
    tiene salvo que llame a `seed_deck_config` explícitamente — se crea acá
    con el mismo default para no devolver 500 en ese caso. Único lugar con
    este get-or-create, compartido entre el endpoint admin y la validación
    del tope al crear un mazo.

    Usa `flush`, no `commit`: un `commit()` acá cerraría la transacción del
    caller y liberaría cualquier lock que ya tenga tomado (ej. el
    `with_for_update()` sobre `User` en `create_deck`), reabriendo la misma
    race condition que ese lock existe para evitar. `flush()` alcanza para
    que la fila sea visible dentro de la transacción en curso; el commit
    final queda en manos de cada caller."""
    config = db.get(DeckConfig, _ROW_ID)
    if config is None:
        config = DeckConfig(id=_ROW_ID, max_decks_per_user=DEFAULT_MAX_DECKS_PER_USER)
        db.add(config)
        db.flush()
    return config
