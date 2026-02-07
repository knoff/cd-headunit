from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os
import json
import asyncio
import logging
from pydantic import BaseModel
from typing import Optional

# Local imports
import settings_manager
from hardware.mock import MockHardware

app = FastAPI(title="HeadUnit OS API")
hw = MockHardware()

# Пути
BASE_DIR = os.path.dirname(__file__)
FRONTEND_PATH = os.path.join(BASE_DIR, "../frontend/dist")
MANIFEST_PATH = os.path.join(BASE_DIR, "../manifest.json")

class SettingsUpdate(BaseModel):
    serial: Optional[str] = None
    wifi_client_ssid: Optional[str] = None
    wifi_client_pass: Optional[str] = None
    wifi_country: Optional[str] = None
    language: Optional[str] = None
    timezone: Optional[str] = None
    summary_timeout: Optional[int] = None

def get_app_version():
    """Reads the version from manifest.json."""
    try:
        if os.path.exists(MANIFEST_PATH):
            with open(MANIFEST_PATH, "r") as f:
                data = json.load(f)
                return data.get("version", "0.0.0")
    except Exception as e:
        logging.error(f"[BACKEND] Error reading manifest: {e}")
    return "0.0.0"

@app.get("/api/health")
async def health():
    return {
        "status": "ok",
        "version": get_app_version()
    }

# --- Settings API ---
@app.get("/api/settings")
async def get_settings():
    return settings_manager.get_settings()

@app.patch("/api/settings")
async def update_settings(settings: SettingsUpdate):
    success = settings_manager.update_settings(settings.dict(exclude_unset=True))
    return {"status": "ok" if success else "error"}

# --- System API ---
@app.post("/api/system/reboot")
async def reboot():
    logging.info("[SYSTEM] Reboot requested")
    if os.name != 'nt':
        os.system("sudo reboot")
    return {"status": "accepted"}

@app.post("/api/system/shutdown")
async def shutdown():
    logging.info("[SYSTEM] Shutdown requested")
    if os.name != 'nt':
        os.system("sudo shutdown -h now")
    return {"status": "accepted"}

# --- Telemetry WebSocket ---
@app.websocket("/ws/telemetry")
async def telemetry_websocket(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await hw.get_telemetry()

            # Определяем частоту: 5Гц для любых активных состояний (включая DONE и STOPPED для точного таймера),
            # и 1Гц только для полного IDLE
            is_active = any(
                g.get("state") != "IDLE"
                for g in [data.get("left", {}), data.get("right", {})]
            )

            # Отправляем раздельные пакеты
            for key in ["machine", "left", "right"]:
                if key in data:
                    await websocket.send_json({
                        "topic": key,
                        "payload": data[key]
                    })

            # Ждем либо следующего тика (0.2с / 1.0с), либо мгновенного события обновления
            delay = 0.2 if is_active else 1.0
            try:
                await asyncio.wait_for(hw.telemetry_updated.wait(), timeout=delay)
                hw.telemetry_updated.clear()
            except asyncio.TimeoutError:
                pass
    except WebSocketDisconnect:
        logging.info("Telemetry client disconnected")
    except Exception as e:
        logging.error(f"WebSocket error: {e}")

# --- Control API (Mock) ---
@app.post("/api/control/start/{side}")
async def start_extraction(side: str, profile: dict):
    hw.start_extraction(side, profile)
    return {"status": "started"}

@app.post("/api/control/stop/{side}")
async def stop_extraction(side: str):
    hw.stop_extraction(side)
    return {"status": "stopped"}

@app.post("/api/control/flush/{side}")
async def start_flush(side: str):
    hw.start_flush(side)
    return {"status": "flushing"}

@app.post("/api/control/cleaning/{side}")
async def start_cleaning(side: str):
    hw.start_cleaning(side)
    return {"status": "cleaning"}

@app.post("/api/control/reset/{side}")
async def reset_group(side: str):
    hw.reset_group(side)
    return {"status": "reset"}

# Раздача статики фронтенда
if os.path.exists(FRONTEND_PATH):
    app.mount("/", StaticFiles(directory=FRONTEND_PATH, html=True), name="frontend")
else:
    @app.get("/")
    async def root():
        return {"message": "Frontend not built yet. Please run build."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
