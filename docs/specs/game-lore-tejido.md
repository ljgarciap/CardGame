# Spec de juego: Lore del universo — El Tejido (Game Expert)

Estado: **Aprobado por Luis (2026-07-18)** — listo para diseño técnico del
Architect (agregar Muisca como sexta facción). El resto del documento
(marco narrativo, El Cronista, roadmap de expansiones) es lore/identidad de
marca — no requiere implementación, pero condiciona textos de sabor, copy
de onboarding y nombres futuros.

## Problema y objetivo

MYTHOS ya tiene facciones de distintas mitologías compartiendo el mismo
juego (Greek, Norse, Egyptian, Aztec, Oriental — `app/models/enums.py`),
pero no había una razón narrativa de por qué un héroe griego puede pelear
junto a un dios nórdico contra un dios egipcio. Sin ese marco, MYTHOS es
"otro TCG donde pelean dioses de distintas culturas", sin identidad propia.
Este documento fija el universo que le da sentido a esa convivencia y que
sostiene el crecimiento del roster a futuro (nuevas facciones, expansiones,
personajes originales) sin romper coherencia.

## El Tejido

No es un mundo físico — es el plano donde nacen las historias. Cada vez que
una cultura cree en un relato, ese relato fortalece un fragmento del
Tejido. Durante milenios, los panteones existieron ahí separados entre sí,
sin tocarse: el Panteón Griego, los Nueve Mundos Nórdicos, el Mundo Muisca,
el Panteón Egipcio, el Reino Azteca, las cortes del Oriente. Cada uno vivía
sostenido por la memoria de su propia cultura.

**Memoria** es la energía que sostiene el Tejido. No es fe religiosa — es
que alguien, en algún lugar, siga recordando el nombre de una historia.

### La Gran Convergencia

Con el paso de los siglos, muchos relatos antiguos se fueron debilitando —
menos gente los recordaba con la misma fuerza que antes. Cuando un mito se
debilita, su fragmento del Tejido queda en riesgo de desvanecerse. Los
muros que separaban los panteones empezaron a resquebrajarse — no porque
alguien lo buscara, sino porque fusionarse era la única forma de
sobrevivir. Los mundos se fusionaron. Los personajes de distintas culturas
empezaron a cruzarse por primera vez.

Importante para el tono: un panteón debilitado puede volver a fortalecerse
si su historia vuelve a ser recordada con fuerza (un evento in-game, una
expansión, un arco narrativo) — no es una muerte irreversible. Y el marco
se aplica parejo a **todas** las mitologías del roster por igual: ninguna
está "más viva" o "más en riesgo" que otra dentro de la ficción.

### Quién gana

No gana el dios más fuerte — gana la historia que sigue siendo recordada.
Zeus no pelea porque odie a Huitzilopochtli: pelea porque si la memoria de
Grecia se apaga, él deja de existir. Lo mismo aplica a Bachué, a Odín, a
Ra, a Anansi, a todos.

Los dioses no pueden alterar el Tejido directamente — los **héroes** sí.
Por eso Aquiles, por eso Sigurd, por eso Bochica: los héroes son quienes
cambian el destino, no solo quienes lo sufren.

### Personajes originales: Los Nacidos del Eco

Hay seres que nunca pertenecieron a ningún mito antiguo — nacidos de
historias nuevas (novelas, anime, videojuegos, leyendas urbanas, internet).
La imaginación humana nunca dejó de crear. Estos personajes se llaman **Los
Nacidos del Eco**: representan los mitos modernos, sin cultura ni pueblo
propio, pero cada generación los hace más fuertes. Son la siguiente
evolución de los mitos, y el espacio narrativo natural para personajes
originales del juego sin necesidad de inventar un panteón falso.

## El jugador: El Cronista

El jugador no es un dios, ni un héroe, ni un rey — es un **Cronista**: uno
de los pocos seres capaces de recordar todas las historias a la vez, sin
pertenecer a ninguna en particular. Cada mazo representa los relatos que
ese Cronista mantiene vivos. Jugar una carta no es invocar una criatura —
es **recordar una historia**. Mientras alguien la recuerde, esa leyenda
sigue existiendo.

Este marco da vocabulario propio reutilizable en copy de producto: onboarding
("empezá tu crónica"), logros, nombres de modos de juego, etc. — no
requiere cambios de código para existir, pero conviene tenerlo presente
cuando se escriba texto de UI a futuro.

## Nota de sensibilidad cultural (decisión ya tomada)

El marco de "un mito se debilita si nadie lo recuerda" funciona sin
fricción para tradiciones ya tratadas como cultura pop sin comunidad de fe
activa reclamándolas (Greek, Norse, Egyptian). Se decidió **no incluir
Yoruba** en el roster: es una tradición espiritual practicada activamente
hoy por millones de personas (sobre todo en la diáspora afrocaribeña), y
encuadrarla como "mitología en riesgo de desaparecer" puede leerse como que
le resta legitimidad a una fe viva.

Muisca sí se incluye — es la cultura de origen de Luis, decisión tomada a
conciencia del mismo riesgo. Mitigación: el lore no dice que el mundo
Muisca esté "muriendo" ni "en peligro por falta de fe real" — dice que se
está "debilitando y en riesgo" *dentro de la ficción del Tejido*, un marco
que se aplica igual a Grecia o Egipto. **Regla para el futuro**: cualquier
panteón nuevo que corresponda a una tradición espiritual practicada
activamente hoy debe pasar por esta misma evaluación antes de sumarse —
no es automático.

## Muisca — sexta facción (aprobado, con alcance técnico)

### Impacto en el motor de gacha

`gacha_service.generate_pack` elige facción con
`uniform_choice(list(Faction))` — **no hay tabla de probabilidad por
facción**, solo por Rango y Rareza (`GachaRankProbability`,
`GachaRarityProbability`, ambas independientes de `Faction`). Esto significa
que agregar Muisca **no requiere una tabla de gacha nueva**, solo:

1. Un valor nuevo en el enum `Faction` (`muisca`) — en Postgres es un
   `ALTER TYPE faction ADD VALUE 'muisca'` vía migración. Nota para el
   Architect: `ALTER TYPE ... ADD VALUE` en Postgres 15 no puede usarse en
   la misma transacción donde el valor nuevo también se referencia — puede
   requerir dos migraciones o una migración con `autocommit_block()` de
   Alembic, no una sola sentencia directa. Ver también el downgrade de
   `351803a2ed78_create_gacha_tables.py` para el precedente de cómo este
   proyecto ya maneja limpieza de tipos ENUM de Postgres.
2. 4 arquetipos nuevos en `card_archetypes` (uno por Rango), agregados al
   mismo seed que ya alimenta las otras 5 facciones (`app/db/seed.py`).

**Decisión de balance explícita**: pasar de 5 a 6 facciones diluye la
probabilidad de cada una de ~20% a ~16.7% (elección uniforme, sin peso por
facción). Se decide lanzar así — parejo, sin boost de debut para Muisca —
por consistencia con cómo ya funciona el sistema y para no introducir un
trato especial hardcodeado.

### Roster (Hero → Major God)

Sigue el mismo criterio narrativo del resto del roster (héroe = actor que
cambia el destino; dios mayor = figura primordial más alta):

| Rango | Personaje | Por qué este rango |
|---|---|---|
| Hero | **Bochica, el Civilizador** | Enseñó agricultura y tejido; creó el Salto del Tequendama para drenar la inundación provocada por Chibchacum y salvar a la humanidad — un héroe que actúa y cambia el destino, mismo arquetipo que Aquiles/Sigurd/Hércules en sus facciones. |
| Demigod | **Chibchacum, el Castigado** | Dios que causó la gran inundación por venganza contra los muiscas; castigado a sostener la tierra sobre sus hombros. Contraste moral directo con Bochica (orden vs. caos castigado). |
| Minor God | **Chía, Diosa de la Luna** | Noche y ciclos; en algunas versiones del mito, en tensión con el orden que impone Bochica — buena base para texto de sabor con conflicto interno de facción. |
| Major God | **Bachué, la Madre Original** | Emergió de la laguna de Iguaque con un niño, pobló la tierra, y volvió a la laguna convertida en serpiente — figura primordial, tier más alto de la facción, igual jerarquía que Zeus/Odín/Ra/Yu Huang en las demás. |

Queda **Huitaca** (diosa del placer y la rebeldía, castigada por Bochica)
documentada acá como candidata fuerte para una carta futura de esta misma
facción — no hace falta que el roster inicial la incluya.

### Stats base y bono de rareza

Sin cambios respecto a `docs/specs/game-gacha-engine.md` — Muisca usa
exactamente la misma tabla de stats base por rango y el mismo bono de
rareza que las otras 5 facciones (30/45/60/80 base; +0/+10/+20/+35% por
rareza). No se introduce ninguna excepción de balance por facción.

## Roadmap de expansiones (marco, no compromiso de fecha)

El universo del Tejido está diseñado para sostener expansiones futuras sin
romper coherencia:
- Sets de un solo panteón (ej. "MYTHOS: Gods of Olympus", solo Greek)
- Sets híbridos como el actual
- Panteones nuevos que ya existían en el Tejido pero no se implementaron
  todavía (ej. una expansión Maya, evaluada primero por la nota de
  sensibilidad cultural de más arriba)
- Sets enteramente de Nacidos del Eco (mitos modernos, personajes 100%
  originales) — sin necesidad de inventar una cultura falsa que se sienta
  forzada, ya tienen un lugar propio en el lore

No implica ningún compromiso de roadmap concreto — es la justificación
narrativa que le da libertad al juego para crecer sin que cada facción
nueva necesite su propia explicación desde cero.

## Handoff

- **Architect**: diseñar la migración del enum `Faction` (agregar
  `muisca`) — atención a la restricción de transacción de Postgres para
  `ALTER TYPE ... ADD VALUE` mencionada arriba.
- **Backend Dev**: agregar los 4 arquetipos Muisca a `app/db/seed.py`
  (mismo patrón que las 5 facciones existentes) una vez migrado el enum.
- **Frontend Dev**: sin cambios de código esperados — el catálogo de
  facciones ya se renderiza a partir de lo que devuelve el backend, no hay
  una lista de facciones hardcodeada en Flutter (verificar igual al
  implementar, por las dudas).
- **Fuera de alcance de este spec**: arte de las 4 cartas nuevas, textos de
  sabor completos por carta, y cualquier mecánica que use "Memoria" como
  recurso jugable (hoy es lore/flavor únicamente, no toca reglas de juego).
