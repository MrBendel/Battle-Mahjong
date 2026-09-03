# Google Cloud Platform (GCP) Backend Setup Guide

This guide describes how to deploy and operate the **Battle Mahjong Startup & Live-Ops API** in your GCP project using **Google Cloud Run**.

---

## 1. Overview & Architecture

The backend is a lightweight, serverless FastAPI service located in `server/`. On client launch, the game queries `GET /v1/startup`:

- Returns the latest and minimum supported client version codes.
- Distributes dynamic store URLs (Play Store / App Store).
- Controls emergency maintenance mode without requiring a client update.
- Passes feature flags down to the game client.
- Auto-scales to zero when idle (within GCP free tier).

---

## 2. Prerequisites

1. A Google Cloud Platform (GCP) project with billing enabled.
2. The Google Cloud SDK (`gcloud` CLI) installed:
   ```bash
   gcloud auth login
   gcloud config set project <YOUR_GCP_PROJECT_ID>
   ```
3. Enable necessary Google Cloud APIs:
   ```bash
   gcloud services enable run.googleapis.com cloudbuild.googleapis.com
   ```

---

## 3. Deployment to Google Cloud Run

### Option A: Using the Deployment Script (PowerShell / Windows)

```powershell
.\server\deploy_cloud_run.ps1 -ProjectId "<YOUR_GCP_PROJECT_ID>" -ServiceName "battle-mahjong-backend" -Region "us-central1"
```

### Option B: Using the Deployment Script (Bash / Linux / macOS)

```bash
chmod +x ./server/deploy_cloud_run.sh
PROJECT_ID="<YOUR_GCP_PROJECT_ID>" ./server/deploy_cloud_run.sh
```

### Option C: Direct `gcloud` Command

From the repository root:

```bash
gcloud run deploy battle-mahjong-backend \
  --project="<YOUR_GCP_PROJECT_ID>" \
  --region="us-central1" \
  --source="./server" \
  --allow-unauthenticated \
  --port=8080
```

Cloud Build will automatically package the container via `server/Dockerfile` and deploy it to Cloud Run.

---

## 4. Endpoints & Testing

Once deployed, Cloud Run provides an HTTPS URL (e.g. `https://battle-mahjong-backend-xyz.a.run.app`).

### Health Check
```bash
curl https://<YOUR_SERVICE_URL>/health
```
**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2026-09-02T19:00:00.000000+00:00"
}
```

### Startup Endpoint
```bash
curl "https://<YOUR_SERVICE_URL>/v1/startup?platform=android&version_code=8&version_name=0.1.7"
```
**Response**:
```json
{
  "status": "ok",
  "server_time": "2026-09-02T19:00:00.000000+00:00",
  "maintenance": {
    "active": false,
    "message": ""
  },
  "version": {
    "latest_version_code": 8,
    "latest_version_name": "0.1.7",
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
    "version_code": 8,
    "version_name": "0.1.7"
  }
}
```

---

## 5. Live-Ops Environment Variables

You can configure versioning and maintenance mode directly in the Google Cloud Console or via `gcloud` without modifying code:

| Environment Variable | Default | Description |
|---|---|---|
| `LATEST_VERSION_CODE` | `8` | The newest version code published to store |
| `LATEST_VERSION_NAME` | `0.1.7` | Display string for the latest version |
| `MIN_VERSION_CODE` | `0` | Versions below this will be forced to update |
| `FORCE_UPDATE` | `false` | When `true`, forces update prompt for all older versions |
| `MAINTENANCE_ACTIVE` | `false` | When `true`, signals in-game maintenance |
| `MAINTENANCE_MESSAGE` | `""` | User-facing message during maintenance |
| `STORE_URL_ANDROID` | `...` | Play Store URL |
| `STORE_URL_IOS` | `...` | App Store URL |

### Updating Variables via CLI:
```bash
gcloud run services update battle-mahjong-backend \
  --set-env-vars="LATEST_VERSION_CODE=9,LATEST_VERSION_NAME=0.1.8,FORCE_UPDATE=false"
```

---

## 6. Wiring the Game Client to Cloud Run

In `scripts/presentation/update_checker.gd`, set `check_version_url` to your Cloud Run service URL:

```gdscript
const DEFAULT_CHECK_VERSION_URL: String = "https://<YOUR_SERVICE_URL>/v1/startup"
```

When offline or in airplane mode, the game client gracefully falls back to local gameplay so players are never blocked.
