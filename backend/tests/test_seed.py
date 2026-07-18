from app.db.seed import ARCHETYPES, seed_archetypes
from app.models.card_archetype import CardArchetype
from app.models.enums import Faction, Rank


def test_seed_archetypes_creates_all_from_empty(db_session):
    seed_archetypes(db_session)

    count = db_session.query(CardArchetype).count()
    assert count == len(ARCHETYPES)


def test_seed_archetypes_is_idempotent_on_full_rerun(db_session):
    seed_archetypes(db_session)
    seed_archetypes(db_session)

    count = db_session.query(CardArchetype).count()
    assert count == len(ARCHETYPES)


def test_seed_archetypes_fills_in_only_missing_ones(db_session):
    """Regresión: el catálogo crece con el tiempo (nuevas facciones del
    roadmap) — si el seed ya corrió una vez y después se agregan
    arquetipos nuevos a ARCHETYPES, una segunda corrida tiene que sembrar
    los nuevos sin tocar ni duplicar los que ya existían. Un chequeo
    idempotente global ("¿hay algo sembrado?") rompía justo esto — bug
    real encontrado al agregar Muisca como sexta facción."""
    existing = CardArchetype(
        name="Placeholder existente",
        faction=Faction.muisca,
        rank=Rank.hero,
        base_attack=999,
        base_defense=999,
        description="No debe tocarse ni duplicarse.",
    )
    db_session.add(existing)
    db_session.commit()

    seed_archetypes(db_session)

    count = db_session.query(CardArchetype).count()
    # Los otros 23 arquetipos de ARCHETYPES se siembran, más el que ya
    # existía (Faction.muisca, Rank.hero no se vuelve a insertar).
    assert count == len(ARCHETYPES)

    unchanged = (
        db_session.query(CardArchetype)
        .filter(CardArchetype.faction == Faction.muisca, CardArchetype.rank == Rank.hero)
        .one()
    )
    assert unchanged.name == "Placeholder existente"
    assert unchanged.base_attack == 999
