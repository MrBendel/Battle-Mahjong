# Google Cloud Platform (GCP) Backend & Game Startup Service

This document provides a comprehensive technical guide to the **Battle Mahjong Startup & Live-Ops Backend Service** hosted on **Google Cloud Run**, how it integrates with the Godot game client, and how future developers and AI agents can operate, configure, test, and extend it.

---

## 1. Executive Summary & Purpose

The Battle Mahjong backend is a lightweight, stateless, serverless microservice built with **Python 3.11** and **FastAPI**, located in the `server/` directory.

### Why Does This Service Exist?
1. **Dynamic Version Checking**: Authoritatively informs client installations when a newer version has been published to Google Play or Apple App Store.
2. **In-App Update Banners**: Triggers the in-game notification banner (`UpdateBannerView`) allowing players to update without navigating manually.
3. **Emergency Maintenance Killswitch**: Enables instant game downtime notifications (e.g. backend migrations, critical bugs) without shipping an emergency client build to app stores.
4. **Remote Feature Toggles**: Powers live-ops flags (e.g. enabling/disabling arcade callouts or cloud save) across all active clients.
5. **Zero-Cost Serverless Footprint**: Runs on Google Cloud Run with scale-to-zero capability, remaining entirely within Google Cloud's free tier under normal operation.

---

## 2. Production Service Details

| Attribute | Production Value |
|---|---|
| **Google Cloud Project ID** | `battle-mahjong` |
| **Cloud Run Service Name** | `battle-mahjong-backend` |
| **Region** | `us-central1` |
| **Port** | `8080` (HTTP/HTTPS) |
| **Live Service URL** | `https://battle-mahjong-backend-yz6hgthnca-uc.a.run.app` |
| **Startup Endpoint** | `https://battle-mahjong-backend-yz6hgthnca-uc.a.run.app/v1/startup` |
| **Health Check** | `https://battle-mahjong-backend-yz6hgthnca-uc.a.run.app/health` |
| **Container Base** | `python:3.11-slim` |

---

## 3. Architecture & Client-Server Lifecycle

### High-Level Flow

```
[Godot Game Launch]
        │
        ▼
[game_shell._ready()] ──> Instantiates UpdateChecker & UpdateBannerView
        │
        ▼
[update_checker.check_for_updates()]
        │
        ├── Async HTTP GET /v1/startup?platform=android&version_code=17&version_name=0.1.16
        │
        ▼
[Cloud Run: FastAPI server/main.py]
        │
        ├── Reads Environment Variables (config.py)
        └── Returns JSON (Maintenance, Version, Features)
        │
        ▼
[update_checker._on_http_request_completed()]
        │
        ├── Evaluates: Is remote_code > current_code?
        │       │
        │       ├── YES ──> Emits signal: update_available(remote_name, store_url, is_mandatory)
        │       └── NO  ──> Emits signal: check_completed(up_to_date=true)
        │
        ▼
[game_shell._on_update_available()]
        │
        ▼
[update_banner_view.show_update()] ──> Displays: "🚀 Update available: 0.1.17 [Update] [✕]"
```

### Offline & Resilience Guarantee
The client is strictly **offline-first**:
* If there is no network connection, airplane mode is active, or the request times out, `UpdateChecker` gracefully falls back to local files (`res://version.json` / `res://export_presets.cfg`).
* Network failures **never crash or block the game**. The player can always play uninterrupted.

---

## 4. API Specification

### Endpoint 1: Health Probe
* **Path**: `GET /health`
* **Purpose**: Container liveness probe used by Cloud Run and uptime checks.
* **Query Parameters**: None.
* **Response**: `200 OK`
```json
{
  "status": "healthy",
  "timestamp": "2026-09-02T19:00:00.000000+00:00"
}
```

---

### Endpoint 2: Game Startup & Bootstrap
* **Path**: `GET /v1/startup`
* **Purpose**: Primary bootstrap endpoint queried on game launch.
* **HTTP Method**: `GET`
* **Query Parameters** (reflected back for telemetry and conditional routing):
  * `platform` *(optional string)*: e.g. `"android"`, `"ios"`, `"windows"`, `"web"`.
  * `version_code` *(optional integer)*: The installed client build number (e.g. `17`).
  * `version_name` *(optional string)*: The semantic version string (e.g. `"0.1.16"`).

#### Full JSON Response Schema
```json
{
  "status": "ok",
  "server_time": "2026-09-02T19:00:00.000000+00:00",
  "maintenance": {
    "active": false,
    "message": ""
  },
  "version": {
    "latest_version_code": 18,
    "latest_version_name": "0.1.17",
    "min_version_code": 0,
    "store_url": "https://play.google.com/apps/internaltest/4701554282456194202",
    "force_update": false,
    "release_notes": "Latest stability improvements and bug fixes."
  },
  "features": {
    "show_arcade_callouts": true,
    "cloud_save_enabled": false
  },
  "client_request": {
    "platform": "android",
    "version_code": 17,
    "version_name": "0.1.16"
  }
}
```

#### Field Reference
* `maintenance.active`: If `true`, the game receives the `maintenance_active` signal and displays the maintenance notice.
* `maintenance.message`: Custom text shown to users when maintenance is active.
* `version.latest_version_code`: The highest version code currently published. If `latest_version_code > current_version_code`, the game triggers the update banner.
* `version.latest_version_name`: Semantic display name (e.g. `"0.1.17"`).
* `version.min_version_code`: The absolute oldest version permitted to play. If `current_version_code < min_version_code`, `is_mandatory` is set to `true` (hiding the dismiss button).
* `version.force_update`: If `true`, marks all older versions as mandatory updates.
* `version.store_url`: Platform-tailored store link opened if in-app updates are unavailable.
* `features`: Dictionary of boolean flags for runtime client toggling.

---

## 5. Live-Ops Operating Procedures

All configuration is controlled via **Google Cloud Run Environment Variables**. Updating an environment variable does not require rebuilding code or redeploying containers; Cloud Run applies the update in seconds.

### Environment Variable Dictionary

| Variable | Type | Default | Description |
|---|---|---|---|
| `LATEST_VERSION_CODE` | `int` | `8` | The newest version code published to store |
| `LATEST_VERSION_NAME` | `str` | `"0.1.7"` | Semantic display version name |
| `MIN_VERSION_CODE` | `int` | `0` | Versions below this cannot dismiss the update banner |
| `FORCE_UPDATE` | `bool` | `false` | When `true`, forces update banner on all older builds |
| `MAINTENANCE_ACTIVE` | `bool` | `false` | When `true`, puts game into maintenance mode |
| `MAINTENANCE_MESSAGE` | `str` | `""` | User-facing message during maintenance |
| `RELEASE_NOTES` | `str` | `"..."` | Change notes sent to clients |
| `STORE_URL_ANDROID` | `str` | Play Internal link | Play Store track link |
| `STORE_URL_IOS` | `str` | `""` | App Store link |

---

### Common Live-Ops Tasks

#### Task 1: You just published a new build to Google Play (e.g., Code 18, Name 0.1.17)
To prompt players on code 17 and earlier to update:
```bash
gcloud run services update battle-mahjong-backend \
  --project=battle-mahjong \
  --region=us-central1 \
  --update-env-vars LATEST_VERSION_CODE=18,LATEST_VERSION_NAME=0.1.17
```

#### Task 2: Force a Mandatory Update (Breaking server/rules change)
To make the update banner un-dismissable for builds older than version 18:
```bash
gcloud run services update battle-mahjong-backend \
  --project=battle-mahjong \
  --region=us-central1 \
  --update-env-vars MIN_VERSION_CODE=18
```

#### Task 3: Enable Emergency Maintenance Mode
```bash
gcloud run services update battle-mahjong-backend \
  --project=battle-mahjong \
  --region=us-central1 \
  --update-env-vars MAINTENANCE_ACTIVE=true,MAINTENANCE_MESSAGE="Server maintenance in progress. Please check back shortly!"
```

#### Task 4: Disable Maintenance Mode
```bash
gcloud run services update battle-mahjong-backend \
  --project=battle-mahjong \
  --region=us-central1 \
  --update-env-vars MAINTENANCE_ACTIVE=false,MAINTENANCE_MESSAGE=""
```

---

## 6. Security, Safety, & Cost Protection

### Is a Public URL Safe?
* **Yes.** `/v1/startup` is read-only and contains no user data, private keys, or mutating capabilities. Mobile game launch endpoints must be public so devices can check for updates prior to user authentication.
* **DoS / Cost Cap**: By default, Cloud Run can scale up to 100 instances. To guarantee costs never spike from web scrapers or bots, cap instances:
  ```bash
  gcloud run services update battle-mahjong-backend \
    --project=battle-mahjong \
    --region=us-central1 \
    --max-instances 2
  ```
  With `--max-instances 2`, the service can handle ~160 requests per second while staying well within the Google Cloud Free Tier (first 2 million requests/month free).

---

## 7. Local Development & Deployment

### Directory Layout
```text
server/
├── Dockerfile              # Container definition for Cloud Run
├── config.py               # Environment variable parser & config schema
├── deploy_cloud_run.ps1    # PowerShell automated deployer
├── deploy_cloud_run.sh     # Bash automated deployer
├── main.py                 # FastAPI application and routes
├── requirements.txt        # Dependencies (fastapi, uvicorn, pydantic)
└── tests/
    └── test_startup.py     # Python unit tests for config & endpoints
```

### Running Locally
1. Install requirements:
   ```bash
   pip install -r server/requirements.txt
   ```
2. Start the local server:
   ```bash
   uvicorn server.main:app --reload --port 8080
   ```
3. Test with curl:
   ```bash
   curl "http://127.0.0.1:8080/v1/startup?platform=windows&version_code=1"
   ```

### Running Server Unit Tests
From the repository root:
```bash
python -m unittest discover -s server/tests
```

### Deploying Code Changes to Cloud Run
Using the PowerShell script (Windows):
```powershell
.\server\deploy_cloud_run.ps1 -ProjectId "battle-mahjong" -ServiceName "battle-mahjong-backend" -Region "us-central1"
```
Or using direct `gcloud`:
```bash
gcloud run deploy battle-mahjong-backend \
  --project=battle-mahjong \
  --region=us-central1 \
  --source="./server" \
  --allow-unauthenticated \
  --port=8080
```

> **Note on IAM Permissions**: Cloud Run source deployments require the default compute service account (`769822025410-compute@developer.gserviceaccount.com`) to have:
> - `roles/storage.admin`
> - `roles/artifactregistry.writer`
> - `roles/cloudbuild.builds.builder`

---

## 8. Client Implementation Details

The client-side bootstrap is divided into three classes:

1. [`scripts/presentation/update_checker.gd`](file:///c:/Users/andre/Documents/Antigravity/Battle-Mahjong/Battle-Mahjong/scripts/presentation/update_checker.gd):
   * Manages the async `HTTPRequest`.
   * Reads current version code from `export_presets.cfg` or `version.json`.
   * Emits signals:
     * `startup_received(startup_data: Dictionary)`
     * `update_available(latest_version_name: String, store_url: String, is_mandatory: bool)`
     * `maintenance_active(message: String)`
     * `check_completed(up_to_date: bool)`
   * Bridges native Google Play In-App Updates (`GodotGooglePlayInAppUpdate` / `GodotPlayCore` plugins) if present.

2. [`scripts/presentation/update_banner_view.gd`](file:///c:/Users/andre/Documents/Antigravity/Battle-Mahjong/Battle-Mahjong/scripts/presentation/update_banner_view.gd):
   * Responsive UI panel pinned to the top of the safe area.
   * Renders `"🚀 Update available: <version_name>"` with **Update** and optional **✕ Dismiss** buttons.

3. [`scripts/presentation/game_shell.gd`](file:///c:/Users/andre/Documents/Antigravity/Battle-Mahjong/Battle-Mahjong/scripts/presentation/game_shell.gd):
   * Hooks `update_available` during `_ready()` and toggles banner visibility.
   * Adjusts UI layout and safe area offsets when the banner appears or is dismissed.
