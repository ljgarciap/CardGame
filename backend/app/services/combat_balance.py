from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.combat_balance import CombatBalanceConfig, RankBaseStat
from app.models.enums import Rank

_ROW_ID = 1

# Ritmo "Moderado" (ver docs/specs/game-gacha-engine.md): con 20 de vida,
# la carta más débil (Hero común) tarda ~10 golpes en matar sola, la más
# fuerte posible (Major God legendaria, bono +35%) baja a ~8 de un golpe --
# ninguna carta mata de un solo ataque, a diferencia de los valores viejos
# (30-108) que sí lo hacían siempre.
DEFAULT_STARTING_LIFE = 20
DEFAULT_RANK_BASE_STATS: dict[Rank, int] = {
    Rank.hero: 2,
    Rank.demigod: 3,
    Rank.minor_god: 4,
    Rank.major_god: 6,
}


def get_or_create_combat_balance_config(db: Session) -> CombatBalanceConfig:
    """La migración siembra la fila id=1, pero un ambiente de test que arma
    el schema con `Base.metadata.create_all` (sin correr migraciones) no la
    tiene salvo que llame al seed explícitamente — se crea acá con el mismo
    default para no devolver 500 en ese caso (mismo criterio que
    get_or_create_deck_config). Usa `flush`, no `commit`: el commit final
    queda en manos del caller."""
    config = db.get(CombatBalanceConfig, _ROW_ID)
    if config is None:
        config = CombatBalanceConfig(id=_ROW_ID, starting_life=DEFAULT_STARTING_LIFE)
        db.add(config)
        db.flush()
    return config


def get_or_create_rank_base_stats(db: Session) -> dict[Rank, RankBaseStat]:
    rows = {row.rank: row for row in db.execute(select(RankBaseStat)).scalars().all()}
    missing = set(Rank) - rows.keys()
    for rank in missing:
        base = DEFAULT_RANK_BASE_STATS[rank]
        row = RankBaseStat(rank=rank, base_attack=base, base_defense=base)
        db.add(row)
        rows[rank] = row
    if missing:
        db.flush()
    return rows
