#!/bin/bash
# Azure Functions deployment script for SignalWire Hello World agent
#
# Prerequisites:
#   - Azure CLI installed and authenticated (az login)
#   - Docker installed and running (for building correct architecture)
#
# Usage:
#   ./deploy.sh                              # Deploy with defaults
#   ./deploy.sh my-app                       # Custom app name
#   ./deploy.sh my-app eastus my-rg          # Custom app, region, and resource group

set -e

# Configuration
APP_NAME="${1:-signalwire-hello-world}"
LOCATION="${2:-eastus}"
RESOURCE_GROUP="${3:-${APP_NAME}-rg}"
STORAGE_ACCOUNT="${APP_NAME//-/}storage"  # Remove hyphens for storage account
RUNTIME="python"
RUNTIME_VERSION="3.11"
FUNCTIONS_VERSION="4"


# Truncate storage account name to 24 chars (Azure limit)
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:0:24}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== SignalWire Hello World - Azure Functions Deployment ==="
echo "App Name: $APP_NAME"
echo "Location: $LOCATION"
echo "Resource Group: $RESOURCE_GROUP"
echo "Storage Account: $STORAGE_ACCOUNT"
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is required but not installed."
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "ERROR: Docker is not running. Please start Docker."
    exit 1
fi

# Step 1: Login check
echo "Step 1: Checking Azure login..."
if ! az account show &>/dev/null; then
    echo "Not logged in. Running: az login"
    az login
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo "Subscription: $SUBSCRIPTION"
echo ""

# Step 2: Create resource group
echo "Step 2: Creating resource group..."
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output none
    echo "Created resource group: $RESOURCE_GROUP"
else
    echo "Resource group exists: $RESOURCE_GROUP"
fi

# Step 3: Create storage account
echo ""
echo "Step 3: Creating storage account..."
if ! az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --output none
    echo "Created storage account: $STORAGE_ACCOUNT"
    echo "Waiting for storage account to propagate..."
    sleep 10
else
    echo "Storage account exists: $STORAGE_ACCOUNT"
fi

# Step 4: Create Function App
echo ""
echo "Step 4: Creating Function App..."
if ! az functionapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    az functionapp create \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --storage-account "$STORAGE_ACCOUNT" \
        --consumption-plan-location "$LOCATION" \
        --runtime "$RUNTIME" \
        --runtime-version "$RUNTIME_VERSION" \
        --functions-version "$FUNCTIONS_VERSION" \
        --os-type Linux \
        --output none
    echo "Created Function App: $APP_NAME"

    # Wait for app to be ready
    echo "Waiting for Function App to be ready..."
    sleep 30
else
    echo "Function App exists: $APP_NAME"
fi

# Step 5: Build and deploy the function using Docker
echo ""
echo "Step 5: Building function with Docker (linux/amd64)..."

DEPLOY_DIR=$(mktemp -d)

# Copy function files
cp -r "$SCRIPT_DIR/function_app" "$DEPLOY_DIR/"
cp "$SCRIPT_DIR/host.json" "$DEPLOY_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$DEPLOY_DIR/"
cp "$SCRIPT_DIR/local.settings.json" "$DEPLOY_DIR/" 2>/dev/null || true

# Build dependencies using Docker for correct architecture
echo "Installing dependencies via Docker..."
docker run --rm \
    --platform linux/amd64 \
    --entrypoint "" \
    -v "$DEPLOY_DIR:/var/task" \
    -w /var/task \
    mcr.microsoft.com/azure-functions/python:4-python3.11 \
    bash -c "pip install -r requirements.txt -t .python_packages/lib/site-packages --quiet"

# Create zip for deployment
echo "Creating deployment package..."
ZIP_FILE="$DEPLOY_DIR/deploy.zip"
cd "$DEPLOY_DIR"
zip -r "$ZIP_FILE" . -x "*.pyc" -q
cd - > /dev/null

PACKAGE_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
echo "Package size: $PACKAGE_SIZE"

# Deploy using zip deployment
echo ""
echo "Step 6: Deploying to Azure..."
az functionapp deployment source config-zip \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --src "$ZIP_FILE" \
    --output none

echo "Deployment complete"

# Cleanup
rm -rf "$DEPLOY_DIR"

# Step 7: Set environment variables (only if provided)
echo ""
echo "Step 7: Configuring environment variables..."
if [ -n "$SWML_BASIC_AUTH_USER" ] && [ -n "$SWML_BASIC_AUTH_PASSWORD" ]; then
    az functionapp config appsettings set \
        --name "$APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --settings \
            SWML_BASIC_AUTH_USER="$SWML_BASIC_AUTH_USER" \
            SWML_BASIC_AUTH_PASSWORD="$SWML_BASIC_AUTH_PASSWORD" \
        --output none
    echo "Custom credentials configured"
else
    echo "No credentials provided - SDK will auto-generate secure credentials"
    echo "Check function logs for generated credentials, or set your own:"
    echo "  az functionapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP \\"
    echo "    --settings SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass"
fi

# Step 8: Get the endpoint URL
echo ""
echo "Step 8: Getting endpoint URL..."

ENDPOINT="https://${APP_NAME}.azurewebsites.net"

# Verify deployment
echo "Waiting for deployment to propagate..."
sleep 10

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Endpoint URL: $ENDPOINT/api/function_app"
echo ""
if [ -n "$SWML_BASIC_AUTH_USER" ] && [ -n "$SWML_BASIC_AUTH_PASSWORD" ]; then
    echo "Authentication:"
    echo "  Username: $SWML_BASIC_AUTH_USER"
    echo "  Password: $SWML_BASIC_AUTH_PASSWORD"
    echo ""
    echo "Test SWML output:"
    echo "  curl -u $SWML_BASIC_AUTH_USER:$SWML_BASIC_AUTH_PASSWORD $ENDPOINT/api/function_app"
    echo ""
    echo "Test SWAIG function:"
    echo "  curl -u $SWML_BASIC_AUTH_USER:$SWML_BASIC_AUTH_PASSWORD -X POST $ENDPOINT/api/function_app/swaig \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"function\": \"say_hello\", \"argument\": {\"parsed\": [{\"name\": \"Alice\"}]}}'"
    echo ""
    echo "Configure SignalWire:"
    echo "  Set your phone number's SWML URL to: https://$SWML_BASIC_AUTH_USER:$SWML_BASIC_AUTH_PASSWORD@${APP_NAME}.azurewebsites.net/api/function_app"
else
    echo "Authentication: SDK will auto-generate credentials"
    echo "  Check function logs or set credentials manually (see Step 7 output above)"
    echo ""
    echo "Test SWML output (replace user:pass with your credentials):"
    echo "  curl -u user:pass $ENDPOINT/api/function_app"
    echo ""
    echo "Test SWAIG function:"
    echo "  curl -u user:pass -X POST $ENDPOINT/api/function_app/swaig \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"function\": \"say_hello\", \"argument\": {\"parsed\": [{\"name\": \"Alice\"}]}}'"
    echo ""
    echo "Configure SignalWire:"
    echo "  Set your phone number's SWML URL to: https://user:pass@${APP_NAME}.azurewebsites.net/api/function_app"
fi
echo ""
