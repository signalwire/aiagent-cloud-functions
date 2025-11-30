#!/bin/bash
# Google Cloud Functions deployment script for SignalWire Hello World agent
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - A Google Cloud project with Cloud Functions API enabled
#
# Usage:
#   ./deploy.sh                           # Deploy with defaults
#   ./deploy.sh my-function               # Custom function name
#   ./deploy.sh my-function us-central1   # Custom function and region

set -e

# Configuration
FUNCTION_NAME="${1:-signalwire-hello-world}"
REGION="${2:-us-central1}"
RUNTIME="python311"
ENTRY_POINT="main"
MEMORY="512MB"
TIMEOUT="60s"
MIN_INSTANCES=0
MAX_INSTANCES=10

# Directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== SignalWire Hello World - Google Cloud Functions Deployment ==="
echo "Function: $FUNCTION_NAME"
echo "Region: $REGION"
echo ""

# Get current project
PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT" ]; then
    echo "Error: No project set. Run: gcloud config set project <project-id>"
    exit 1
fi
echo "Project: $PROJECT"
echo ""

# Step 1: Enable required APIs
echo "Step 1: Enabling required APIs..."
gcloud services enable cloudfunctions.googleapis.com --quiet
gcloud services enable cloudbuild.googleapis.com --quiet
gcloud services enable artifactregistry.googleapis.com --quiet

# Step 2: Create deployment package with embedded SDK
echo ""
echo "Step 2: Creating deployment package..."

# Create a temporary deployment directory
DEPLOY_DIR=$(mktemp -d)
trap "rm -rf $DEPLOY_DIR" EXIT

# Copy the main files
cp "$SCRIPT_DIR/main.py" "$DEPLOY_DIR/"

# Copy requirements.txt
cp "$SCRIPT_DIR/requirements.txt" "$DEPLOY_DIR/"

echo "Deployment package contents:"
ls -la "$DEPLOY_DIR/"

# Step 3: Deploy function
echo ""
echo "Step 3: Deploying Cloud Function..."

# Check if function exists (Gen 2 vs Gen 1)
EXISTING_GEN2=$(gcloud functions describe "$FUNCTION_NAME" --region="$REGION" --gen2 2>/dev/null && echo "yes" || echo "no")

if [ "$EXISTING_GEN2" == "yes" ]; then
    echo "Updating existing Gen 2 function..."
    gcloud functions deploy "$FUNCTION_NAME" \
        --gen2 \
        --region="$REGION" \
        --runtime="$RUNTIME" \
        --source="$DEPLOY_DIR" \
        --entry-point="$ENTRY_POINT" \
        --trigger-http \
        --allow-unauthenticated \
        --memory="$MEMORY" \
        --timeout="$TIMEOUT" \
        --min-instances="$MIN_INSTANCES" \
        --max-instances="$MAX_INSTANCES" \
        --quiet
else
    echo "Creating new Gen 2 function..."
    gcloud functions deploy "$FUNCTION_NAME" \
        --gen2 \
        --region="$REGION" \
        --runtime="$RUNTIME" \
        --source="$DEPLOY_DIR" \
        --entry-point="$ENTRY_POINT" \
        --trigger-http \
        --allow-unauthenticated \
        --memory="$MEMORY" \
        --timeout="$TIMEOUT" \
        --min-instances="$MIN_INSTANCES" \
        --max-instances="$MAX_INSTANCES" \
        --quiet
fi

# Step 4: Get the endpoint URL
echo ""
echo "Step 4: Getting endpoint URL..."

ENDPOINT=$(gcloud functions describe "$FUNCTION_NAME" \
    --region="$REGION" \
    --gen2 \
    --format="value(serviceConfig.uri)")

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Endpoint URL: $ENDPOINT"
echo ""
echo "Test SWML output:"
echo "  curl $ENDPOINT"
echo ""
echo "Test SWAIG function:"
echo "  curl -X POST $ENDPOINT/swaig \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"function\": \"say_hello\", \"argument\": {\"parsed\": [{\"name\": \"Alice\"}]}}'"
echo ""
echo "Configure SignalWire:"
echo "  Set your phone number's SWML URL to: $ENDPOINT"
echo ""

# Step 5: Optional - Set environment variables
echo "To set environment variables (optional):"
echo "  gcloud functions deploy $FUNCTION_NAME \\"
echo "    --region=$REGION \\"
echo "    --gen2 \\"
echo "    --update-env-vars SWML_BASIC_AUTH_USER=myuser,SWML_BASIC_AUTH_PASSWORD=mypass"
echo ""
