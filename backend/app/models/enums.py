import enum


class Faction(str, enum.Enum):
    greek = "greek"
    norse = "norse"
    egyptian = "egyptian"
    aztec = "aztec"
    oriental = "oriental"
    muisca = "muisca"


class Rank(str, enum.Enum):
    hero = "hero"
    demigod = "demigod"
    minor_god = "minor_god"
    major_god = "major_god"


class Rarity(str, enum.Enum):
    common = "common"
    rare = "rare"
    epic = "epic"
    legendary = "legendary"
