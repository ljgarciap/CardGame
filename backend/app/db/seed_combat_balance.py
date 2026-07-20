"""Seed de la configuración paramétrica de balance de combate (vida
inicial, ataque base por rango). Run con `python -m app.db.seed_combat_balance`.
"""
from sqlalchemy.orm import Session

from app.models.combat_balance import CombatBalanceConfig, RankBaseStat
from app.services.combat_balance import DEFAULT_RANK_BASE_STATS, DEFAULT_STARTING_LIFE


def seed_combat_balance(session: Session) -> None:
    """Idempotente: no toca nada si ya hay algo sembrado (para no pisar
    valores que un superadmin ya haya ajustado)."""
    if session.get(CombatBalanceConfig, 1) is None:
        session.add(CombatBalanceConfig(id=1, starting_life=DEFAULT_STARTING_LIFE))

    existing_ranks = {row.rank for row in session.query(RankBaseStat).all()}
    for rank, base in DEFAULT_RANK_BASE_STATS.items():
        if rank in existing_ranks:
            continue
        session.add(RankBaseStat(rank=rank, base_attack=base, base_defense=base))

    session.commit()


if __name__ == "__main__":
    from app.db.session import SessionLocal

    db = SessionLocal()
    try:
        seed_combat_balance(db)
    finally:
        db.close()
