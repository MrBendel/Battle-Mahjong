#!/usr/bin/env bash
set -e

# Default settings
SERVICE_NAME="${SERVICE_NAME:-battle-mahjong-backend}"
REGION="${REGION:-us-central1}"
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || echo '')}"

if [ -z "$PROJECT_ID" ]; then
  echo "Error: No GCP project configured. Run 'gcloud config set project <PROJECT_ID>' or export PROJECT_ID=<PROJECT_ID>"
  exit 1
fi

echo "=== Deploying Battle Mahjong Backend to Cloud Run ==="
echo "Project:  $PROJECT_ID"
echo "Service:  $SERVICE_NAME"
echo "Region:   $REGION"

# Navigate to project root so the build context includes the server directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Deploy from source using Cloud Build & Cloud Run
gcloud run deploy "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --source="$SCRIPT_DIR" \
  --allow-unauthenticated \
  --port=8080

echo ""
echo "=== Deployment Succeeded ==="
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --project="$PROJECT_ID" --region="$REGION" --format="value(status.url)")
echo "Startup Endpoint URL: ${SERVICE_URL}/v1/startup"
