from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os

app = FastAPI(title="HeadUnit OS API")

# Путь к собранному фронтенду
FRONTEND_PATH = os.path.join(os.path.dirname(__file__), "../frontend/dist")

@app.get("/api/health")
async def health():
    return {"status": "ok", "version": "0.1.0"}

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
