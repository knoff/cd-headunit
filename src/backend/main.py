from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os
import json

app = FastAPI(title="HeadUnit OS API")

# Пути
BASE_DIR = os.path.dirname(__file__)
FRONTEND_PATH = os.path.join(BASE_DIR, "../frontend/dist")
MANIFEST_PATH = os.path.join(BASE_DIR, "../manifest.json")

def get_app_version():
    """Reads the version from manifest.json."""
    try:
        if os.path.exists(MANIFEST_PATH):
            with open(MANIFEST_PATH, "r") as f:
                data = json.load(f)
                return data.get("version", "unknown")
    except Exception as e:
        print(f"[BACKEND] Error reading manifest: {e}")
    return "0.0.0"

@app.get("/api/health")
async def health():
    return {
        "status": "ok",
        "version": get_app_version()
    }

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
