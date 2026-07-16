from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

from app.api.admin.deck_config import router as deck_config_admin_router
from app.api.admin.gacha_config import router as gacha_config_admin_router
from app.api.auth import router as auth_router
from app.api.cards import router as cards_router
from app.api.decks import router as decks_router
from app.api.match_ws import router as match_ws_router
from app.api.packs import router as packs_router
from app.api.users import router as users_router

app = FastAPI(title="Card Game API")

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(packs_router)
app.include_router(cards_router)
app.include_router(decks_router)
app.include_router(gacha_config_admin_router)
app.include_router(deck_config_admin_router)
app.include_router(match_ws_router)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Welcome to the Card Game API"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    while True:
        data = await websocket.receive_text()
        await websocket.send_text(f"Message text was: {data}")
