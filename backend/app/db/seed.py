"""Seed the 20 base card archetypes (5 factions x 4 ranks).

Data source: docs/specs/game-gacha-engine.md (catálogo de arquetipos).
Run with `python -m app.db.seed` (or import `seed_archetypes` in a script/test).
"""
from sqlalchemy.orm import Session

from app.models.card_archetype import CardArchetype
from app.models.enums import Faction, Rank

ARCHETYPES = [
    (Faction.greek, Rank.hero, "Achilles, the Unyielding",
     "El campeón de Ftía, casi invulnerable en batalla."),
    (Faction.greek, Rank.demigod, "Heracles, Son of Zeus",
     "Hijo de Zeus, célebre por sus doce trabajos imposibles."),
    (Faction.greek, Rank.minor_god, "Athena, Goddess of Wisdom",
     "Diosa de la estrategia y la sabiduría, nacida de la mente de Zeus."),
    (Faction.greek, Rank.major_god, "Zeus, King of Olympus",
     "Señor del rayo y rey de los dioses del Olimpo."),

    (Faction.norse, Rank.hero, "Sigurd the Dragonslayer",
     "El héroe que derrotó al dragón Fafnir y se bañó en su sangre."),
    (Faction.norse, Rank.demigod, "Baldr, the Beloved",
     "El más amado de los Aesir, cuya muerte anuncia el Ragnarök."),
    (Faction.norse, Rank.minor_god, "Freyja, Lady of the Vanir",
     "Diosa del amor y la guerra, comanda las Valquirias."),
    (Faction.norse, Rank.major_god, "Odin, the Allfather",
     "Padre de todos, sacrificó un ojo por la sabiduría rúnica."),

    (Faction.egyptian, Rank.hero, "Sinuhe the Wanderer",
     "Cortesano exiliado que sobrevivió por su astucia en tierras extrañas."),
    (Faction.egyptian, Rank.demigod, "Imhotep, the Sage",
     "Arquitecto y sanador elevado a la divinidad por su sabiduría."),
    (Faction.egyptian, Rank.minor_god, "Anubis, Warden of the Dead",
     "Guardián de la necrópolis y guía de las almas al más allá."),
    (Faction.egyptian, Rank.major_god, "Ra, the Sun Sovereign",
     "El sol mismo, que cruza los cielos en su barca sagrada."),

    (Faction.aztec, Rank.hero, "Tlacaelel the Strategist",
     "Consejero y estratega que forjó el poder de Tenochtitlan."),
    (Faction.aztec, Rank.demigod, "Camaxtli, Lord of the Hunt",
     "Señor de la cacería y la guerra, patrono de los cazadores."),
    (Faction.aztec, Rank.minor_god, "Tlaloc, Bringer of Rain",
     "Dios de la lluvia y la fertilidad, temido y venerado por igual."),
    (Faction.aztec, Rank.major_god, "Quetzalcoatl, the Feathered Serpent",
     "La serpiente emplumada, creador y dios del viento y el saber."),

    (Faction.oriental, Rank.hero, "Li Jing, the Pagoda Bearer",
     "General celestial que porta una pagoda capaz de contener demonios."),
    (Faction.oriental, Rank.demigod, "Nezha, the Third Prince",
     "Joven guerrero renacido con poderes divinos y temperamento feroz."),
    (Faction.oriental, Rank.minor_god, "Guan Yu, God of War",
     "General deificado por su lealtad inquebrantable y su valor en combate."),
    (Faction.oriental, Rank.major_god, "Yu Huang, the Jade Emperor",
     "El Emperador de Jade, soberano del cielo y de todos los dioses."),

    (Faction.muisca, Rank.hero, "Bochica, the Civilizer",
     "Enseñó la agricultura y el tejido, y creó el Salto del Tequendama "
     "para salvar a su pueblo de la gran inundación."),
    (Faction.muisca, Rank.demigod, "Chibchacum, the Punished",
     "Provocó la gran inundación por venganza; condenado a sostener la "
     "tierra sobre sus hombros como castigo eterno."),
    (Faction.muisca, Rank.minor_god, "Chía, Goddess of the Moon",
     "Señora de la noche y los ciclos, a menudo en tensión con el orden "
     "que impone Bochica."),
    (Faction.muisca, Rank.major_god, "Bachué, the Original Mother",
     "Emergió de la laguna de Iguaque para poblar la tierra, y volvió a "
     "sus aguas convertida en serpiente."),
]


def seed_archetypes(session: Session) -> None:
    """Idempotente por arquetipo individual (faction, rank), no por "¿hay
    algo sembrado?" — el catálogo crece con el tiempo (nuevas facciones del
    roadmap de expansiones, ver docs/specs/game-lore-tejido.md), así que un
    chequeo global saltearía para siempre cualquier arquetipo agregado
    después de la primera corrida. Bug real: así fue como el seed no sembró
    los 4 arquetipos de Muisca en una base que ya tenía las otras 5
    facciones."""
    existing = {
        (a.faction, a.rank)
        for a in session.query(CardArchetype.faction, CardArchetype.rank)
    }

    for faction, rank, name, description in ARCHETYPES:
        if (faction, rank) in existing:
            continue
        session.add(
            CardArchetype(
                name=name,
                faction=faction,
                rank=rank,
                description=description,
            )
        )
    session.commit()


if __name__ == "__main__":
    from app.db.session import SessionLocal

    db = SessionLocal()
    try:
        seed_archetypes(db)
    finally:
        db.close()
