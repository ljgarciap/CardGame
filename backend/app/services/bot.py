"""Oponente de práctica sin cola — arranca al toque, sin esperar rival real.
Juega llamando las mismas funciones puras de `match_engine` que validan
cualquier jugada humana: sus movimientos pasan por las mismas reglas, no
hay atajo especial para el bot.

Diseño de Game Expert (docs/specs/game-bot-practica.md): mazo al azar sobre
el catálogo real de arquetipos (se adapta solo a facciones nuevas, sin
lista para mantener sincronizada — la misma clase de bug que ya mordió con
Muisca), heurística de reglas fijas sin dificultad ajustable en esta
iteración.
"""
import uuid
from typing import List

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.card_archetype import CardArchetype
from app.models.enums import Rarity
from app.services.combat_balance import get_or_create_rank_base_stats
from app.services.match_engine import (
    DECK_SIZE,
    MAX_BOARD_SIZE,
    AttackEvent,
    CardInPlay,
    Match,
    attack,
    end_turn,
    play_card,
)

# UUID fijo, no una fila real de `users` -- Match/MatchPlayerState viven en
# Redis como modelos Pydantic, sin FK que romper.
BOT_USER_ID = uuid.UUID("00000000-0000-0000-0000-0000000000b0")
BOT_USERNAME = "Eco"


def build_bot_deck(db: Session) -> List[CardInPlay]:
    """DECK_SIZE arquetipos al azar del catálogo real, rareza common (stats
    base, sin bono) -- se arma fresco en cada partida, no hay mazo fijo del
    bot para mantener sincronizado con el roster de facciones."""
    archetypes = (
        db.execute(select(CardArchetype).order_by(func.random()).limit(DECK_SIZE))
        .scalars()
        .all()
    )
    rank_base_stats = get_or_create_rank_base_stats(db)
    return [
        CardInPlay(
            player_card_id=uuid.uuid4(),
            name=archetype.name,
            faction=archetype.faction,
            rank=archetype.rank,
            rarity=Rarity.common,
            attack=rank_base_stats[archetype.rank].base_attack,
            max_defense=rank_base_stats[archetype.rank].base_defense,
            current_defense=rank_base_stats[archetype.rank].base_defense,
        )
        for archetype in archetypes
    ]


def is_bot_turn(match: Match) -> bool:
    return match.turn_order[match.current_turn_index] == BOT_USER_ID


def run_bot_turn(match: Match) -> list[AttackEvent]:
    """Corre el turno completo del bot en una sola pasada: juega la carta
    de mayor ataque en mano si hay lugar, ataca priorizando trades
    favorables (matar una carta rival de un golpe, empezando por la más
    fuerte que pueda matar; si no hay ninguna, ataca directo), y termina
    turno. Una sola pasada alcanza porque el motor alterna estrictamente
    entre 2 jugadores -- después de `end_turn` siempre le toca al humano.

    Devuelve los eventos de cada ataque resuelto, en orden -- el bot puede
    atacar con varias cartas en el mismo turno, y el cliente necesita cada
    golpe individual para animarlos en secuencia, no solo el resultado
    final agregado."""
    if match.is_over or not is_bot_turn(match):
        return []

    bot = match.players[BOT_USER_ID]
    events: list[AttackEvent] = []

    if not bot.has_played_card_this_turn and len(bot.board) < MAX_BOARD_SIZE and bot.hand:
        best_card = max(bot.hand, key=lambda c: c.attack)
        play_card(match, BOT_USER_ID, best_card.player_card_id)

    opponent_id = next(uid for uid in match.turn_order if uid != BOT_USER_ID)
    attackers = [c for c in bot.board if not c.summoning_sick and not c.has_attacked_this_turn]
    for card in attackers:
        if match.is_over:
            break
        opponent = match.players[opponent_id]
        killable = [t for t in opponent.board if card.attack >= t.current_defense]
        if killable:
            target = max(killable, key=lambda t: t.attack)
            events.append(attack(match, BOT_USER_ID, card.player_card_id, target.player_card_id))
        else:
            events.append(attack(match, BOT_USER_ID, card.player_card_id, "face"))

    if not match.is_over:
        end_turn(match, BOT_USER_ID)

    return events
