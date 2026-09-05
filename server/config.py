import os
from typing import Dict, Any


def get_startup_config(platform: str = "android") -> Dict[str, Any]:
    """
    Builds the startup configuration dictionary based on environment variables
    with platform-specific overrides if necessary.
    """
    latest_version_code = int(os.getenv("LATEST_VERSION_CODE", "8"))
    latest_version_name = os.getenv("LATEST_VERSION_NAME", "0.1.7")
    min_version_code = int(os.getenv("MIN_VERSION_CODE", "0"))
    
    # Store URLs can be configured per platform
    default_store_url = os.getenv(
        "STORE_URL",
        "https://play.google.com/apps/internaltest/4701554282456194202"
    )
    if platform.lower() == "ios":
        store_url = os.getenv("STORE_URL_IOS", default_store_url)
    else:
        store_url = os.getenv("STORE_URL_ANDROID", default_store_url)

    maintenance_active = os.getenv("MAINTENANCE_ACTIVE", "false").lower() in ("true", "1", "yes")
    maintenance_message = os.getenv("MAINTENANCE_MESSAGE", "Battle Mahjong servers are temporarily undergoing maintenance. Please check back shortly.")
    force_update = os.getenv("FORCE_UPDATE", "false").lower() in ("true", "1", "yes")
    release_notes = os.getenv("RELEASE_NOTES", "Latest stability improvements and bug fixes.")

    show_arcade_callouts = os.getenv("FEATURE_ARCADE_CALLOUTS", "true").lower() in ("true", "1", "yes")
    cloud_save_enabled = os.getenv("FEATURE_CLOUD_SAVE", "false").lower() in ("true", "1", "yes")

    return {
        "status": "ok",
        "server_time": os.getenv("SERVER_TIME_OVERRIDE", ""),
        "maintenance": {
            "active": maintenance_active,
            "message": maintenance_message if maintenance_active else "",
        },
        "version": {
            "latest_version_code": latest_version_code,
            "latest_version_name": latest_version_name,
            "min_version_code": min_version_code,
            "store_url": store_url,
            "force_update": force_update,
            "release_notes": release_notes,
        },
        "features": {
            "show_arcade_callouts": show_arcade_callouts,
            "cloud_save_enabled": cloud_save_enabled,
        },
    }
