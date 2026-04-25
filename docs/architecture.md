# Architecture Document - Card Game

## Overview
This document outlines the technical architecture for the multiplatform card game.

## Technology Stack
- **Frontend**: Flutter (Targeting Android, iOS, and Web).
- **Backend**: Python (FastAPI).
- **Database**: PostgreSQL.
- **Communication**: Real-time via WebSockets.

## Key Components
1. **Game Engine**: Handles logic, turns, and state validation.
2. **Gacha Engine**: Manages pack opening, probability calculations, and card generation.
3. **Real-time Server**: Manages concurrent player connections and message broadcasting.
4. **Matchmaking**: Logic to pair players or create private rooms.
