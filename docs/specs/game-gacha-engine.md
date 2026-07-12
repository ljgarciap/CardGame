# Spec de juego: Motor de Gacha (Game Expert)

Estado: Aprobado por Luis (2026-07-12) — listo para diseño técnico del Architect

## Problema y objetivo
Hoy `PackOpeningPage` genera cartas 100% en el cliente, con probabilidades
hardcodeadas que ni siquiera respetan las tablas de `PackLevel` (rareza
ignora la tabla, rango es uniforme random, la carta siempre se llama "God
Prototype"). Esto es inconsistente con el diseño y, más importante, no es
seguro: el cliente podría fabricar cualquier resultado. El objetivo es mover
la generación de cartas al backend (server-authoritative) y reemplazar las
cartas placeholder por un catálogo real de arquetipos.

## Catálogo de arquetipos
Rango y rareza quedan como ejes independientes (ya es así en
`TCGCardEntity`): rareza no es "otra carta", es la calidad del print de la
misma carta — sube el stat, no cambia la identidad. 5 facciones × 4 rangos =
20 arquetipos base.

| Facción | Hero | Demigod | Minor God | Major God |
|---|---|---|---|---|
| Greek | Achilles, the Unyielding | Heracles, Son of Zeus | Athena, Goddess of Wisdom | Zeus, King of Olympus |
| Norse | Sigurd the Dragonslayer | Baldr, the Beloved | Freyja, Lady of the Vanir | Odin, the Allfather |
| Egyptian | Sinuhe the Wanderer | Imhotep, the Sage | Anubis, Warden of the Dead | Ra, the Sun Sovereign |
| Aztec | Tlacaelel the Strategist | Camaxtli, Lord of the Hunt | Tlaloc, Bringer of Rain | Quetzalcoatl, the Feathered Serpent |
| Oriental | Li Jing, the Pagoda Bearer | Nezha, the Third Prince | Guan Yu, God of War | Yu Huang, the Jade Emperor |

### Stats base por rango (antes de bono de rareza)
| Rango | ATK/DEF base |
|---|---|
| Hero | 30 / 30 |
| Demigod | 45 / 45 |
| Minor God | 60 / 60 |
| Major God | 80 / 80 |

### Bono de rareza
Fórmula: `stat = round(base * (1 + bono))`

| Rareza | Bono | Hero (30 base) | Demigod (45) | Minor God (60) | Major God (80) |
|---|---|---|---|---|---|
| Common | +0% | 30 | 45 | 60 | 80 |
| Rare | +10% | 33 | 50 | 66 | 88 |
| Epic | +20% | 36 | 54 | 72 | 96 |
| Legendary | +35% | 41 | 61 | 81 | 108 |

## Tablas de probabilidad completas (niveles 1-5)
Los niveles 1, 2 y 5 vienen del código existente (`PackLevel.level1()`,
`PackLevel.level5()`, y el nivel 2 hardcodeado en `marketplace_page.dart`).
Los niveles 3 y 4 son nuevos, interpolados entre 2 y 5. Cada tabla suma 1.00
exacto.

**Rango:**
| Nivel | Hero | Demigod | Minor God | Major God | Garantía mínima |
|---|---|---|---|---|---|
| 1 | .80 | .15 | .04 | .01 | — |
| 2 | .60 | .30 | .08 | .02 | — |
| 3 | .43 | .27 | .19 | .11 | Demigod |
| 4 | .27 | .23 | .29 | .21 | Minor God |
| 5 | .10 | .20 | .40 | .30 | Major God |

**Rareza:**
| Nivel | Common | Rare | Epic | Legendary |
|---|---|---|---|---|
| 1 | .90 | .08 | .015 | .005 |
| 2 | .70 | .20 | .08 | .02 |
| 3 | .60 | .23 | .12 | .05 |
| 4 | .50 | .27 | .16 | .07 |
| 5 | .40 | .30 | .20 | .10 |

La "garantía mínima" es una escalera de pity **por apertura** (al menos una
de las 5 cartas del pack cumple el rango mínimo indicado), no acumulada
entre compras. Cada pack sigue entregando 5 cartas (`CardPackEntity.cardCount`).

## Impacto en economía
- Precio: se mantiene el supuesto ya implícito en el código
  (`nivel × 1000` monedas) — no se introduce moneda nueva ni cambio de precio
- La escalera de garantía (niveles 3-5) es la única mecánica de pity — no hay
  pity acumulado entre packs en esta iteración
- No se introduce ninguna mecánica de monetización oculta: las tablas de
  probabilidad son públicas/consultables, consistente con la regla de nunca
  ocultar probabilidades de gacha

## Edge cases
- **Saldo insuficiente**: el servidor rechaza la apertura antes de generar
  cartas o descontar moneda — no debe haber estado parcial
- **Doble submit / replay**: dos requests de apertura del mismo jugador no
  pueden compartir el mismo resultado ni descontar el saldo dos veces
  (idempotencia y atomicidad son responsabilidad del Architect/Backend Dev)
- **Racha de mala suerte**: dentro de la probabilidad normal (sin pity), es
  posible no sacar nada por encima de Common en niveles 1-2 — es esperado,
  no es un bug
- **Nivel inválido**: solo niveles 1-5 son válidos; cualquier otro valor se
  rechaza

## Criterios de aceptación (para QA)
- Abrir cada nivel de pack ~10,000 veces (test estadístico) y verificar que
  la distribución observada de rango y de rareza esté dentro de un margen de
  tolerancia razonable de la tabla teórica
- Verificar que niveles 3, 4 y 5 entreguen siempre al menos una carta que
  cumpla la garantía mínima de rango de esa tabla
- Verificar que el bono de stat por rareza se calcule exactamente con la
  fórmula `round(base * (1 + bono))`
- Verificar que abrir un pack sin saldo suficiente sea rechazado, sin
  descuento de moneda ni generación de cartas
- Verificar que el cliente no pueda influir el resultado — la respuesta del
  servidor es la única fuente de verdad

## Handoff
Este cambio requiere mover la generación al backend (nueva tabla de
catálogo, nuevo endpoint, RNG server-side) — se escala al Architect para el
diseño técnico antes de pasar a PM.
