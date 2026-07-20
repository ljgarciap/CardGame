from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_superadmin
from app.db.session import get_db
from app.models.combat_balance import RankBaseStat
from app.schemas.combat_balance import CombatBalanceConfigOut, CombatBalanceConfigUpdateRequest
from app.services.combat_balance import get_or_create_combat_balance_config, get_or_create_rank_base_stats

router = APIRouter(
    prefix="/api/admin/combat-balance",
    tags=["admin"],
    dependencies=[Depends(get_current_superadmin)],
)


@router.get("", response_model=CombatBalanceConfigOut)
def get_combat_balance(db: Session = Depends(get_db)):
    config = get_or_create_combat_balance_config(db)
    rank_base_stats = get_or_create_rank_base_stats(db)
    # get_or_create_* no comitea (ver su docstring) -- acá, sin ningún lock
    # en juego, hace falta este commit explícito para que una fila default
    # recién creada persista más allá de este request.
    db.commit()
    return CombatBalanceConfigOut(
        starting_life=config.starting_life,
        rank_base_stats=list(rank_base_stats.values()),
    )


@router.put("", response_model=CombatBalanceConfigOut)
def update_combat_balance(payload: CombatBalanceConfigUpdateRequest, db: Session = Depends(get_db)):
    config = get_or_create_combat_balance_config(db)
    config.starting_life = payload.starting_life

    rank_base_stats = get_or_create_rank_base_stats(db)
    for entry in payload.rank_base_stats:
        row = rank_base_stats[entry.rank]
        row.base_attack = entry.base_attack
        row.base_defense = entry.base_defense

    db.commit()
    return CombatBalanceConfigOut(
        starting_life=config.starting_life,
        rank_base_stats=db.query(RankBaseStat).all(),
    )
