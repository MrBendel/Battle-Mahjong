from datetime import datetime, timezone
from typing import Optional

try:
    from fastapi import FastAPI, Query
    from fastapi.middleware.cors import CORSMiddleware
    from fastapi.responses import JSONResponse
    HAS_FASTAPI = True
except ImportError:
    HAS_FASTAPI = False

from server.config import get_startup_config

if HAS_FASTAPI:
    app = FastAPI(
        title="Battle Mahjong Backend",
        description="Startup and Live-Ops API for Battle Mahjong",
        version="1.0.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/")
    def root():
        return {
            "name": "Battle Mahjong API",
            "version": "1.0.0",
            "status": "online",
        }

    @app.get("/health")
    def health():
        return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}

    @app.get("/v1/startup")
    def startup(
        platform: str = Query(default="android", description="Client operating system or platform (android, ios, windows, etc.)"),
        version_code: int = Query(default=0, description="Installed client version code"),
        version_name: Optional[str] = Query(default="", description="Installed client version name"),
    ):
        config = get_startup_config(platform=platform)
        if not config["server_time"]:
            config["server_time"] = datetime.now(timezone.utc).isoformat()
        
        # Include client reflection for debugging/analytics
        config["client_request"] = {
            "platform": platform,
            "version_code": version_code,
            "version_name": version_name,
        }
        return JSONResponse(content=config)
else:
    app = None
