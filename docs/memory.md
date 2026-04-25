# Memory Log - Card Game

## 2026-04-24
- **Project Started**: Initialization of the card game project.
- **Frontend Choice**: Flutter (Multiplatform).
- **Backend Selection**: Python (FastAPI) selected for real-time concurrency.
- **Database Selection**: PostgreSQL selected for persistence.
- **Infrastructure**: VPS selected for deployment.
- **Initial Files**: Created `memory.md` and `architecture.md`.
- **Project Reorganization**: Moved to a monorepo structure (`frontend/`, `backend/`, `docs/`).
- **TCG & Gacha System**: Defined logic for Factions, Rarity (Common-Legendary), and Ranks (Hero-Major God).
- **Pack Probabilities**: Implemented a level-based pack system (Level 1-5) with probability tables for ranks and rarities.
- **Domain Entities**: Updated `CardEntity` and created `CardPackEntity` in `frontend/`.
- **Marketplace UI**: Created `MarketplacePage` with a grid of packs, prices, and level-based styling.
- **Pack Opening System**: Implemented `PackOpeningPage` with floating animations, dramatic opening sequence, and card reveal logic.
