#!/bin/bash
# Azure Functions deployment script for SignalWire Hello World agent
#
# Prerequisites:
#   - Azure CLI installed and authenticated (az login)
#   - Python 3.11+
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

echo "=== SignalWire Hello World - Azure Functions Deployment ==="
echo "App Name: $APP_NAME"
echo "Location: $LOCATION"
echo "Resource Group: $RESOURCE_GROUP"
echo "Storage Account: $STORAGE_ACCOUNT"
echo ""

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

# Step 5: Deploy the function
echo ""
echo "Step 5: Deploying function code..."

# Create a temporary directory for deployment
DEPLOY_DIR=$(mktemp -d)
cp -r function_app "$DEPLOY_DIR/"
cp host.json "$DEPLOY_DIR/"
cp requirements.txt "$DEPLOY_DIR/"
cp local.settings.json "$DEPLOY_DIR/" 2>/dev/null || true

# Create zip for deployment
ZIP_FILE="$DEPLOY_DIR/deploy.zip"
cd "$DEPLOY_DIR"
zip -r "$ZIP_FILE" . -q
cd - > /dev/null

# Deploy using zip deployment
az functionapp deployment source config-zip \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --src "$ZIP_FILE" \
    --output none

echo "Deployment complete"

# Cleanup
rm -rf "$DEPLOY_DIR"

# Step 6: Get the endpoint URL
echo ""
echo "Step 6: Getting endpoint URL..."

ENDPOINT="https://${APP_NAME}.azurewebsites.net"

# Verify deployment
echo "Waiting for deployment to propagate..."
sleep 10

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Endpoint URL: $ENDPOINT"
echo ""
echo "Test SWML output:"
echo "  curl $ENDPOINT/api/function_app"
echo ""
echo "Test SWAIG function:"
echo "  curl -X POST $ENDPOINT/api/function_app/swaig \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"function\": \"say_hello\", \"argument\": {\"parsed\": [{\"name\": \"Alice\"}]}}'"
echo ""
echo "Configure SignalWire:"
echo "  Set your phone number's SWML URL to: $ENDPOINT/api/function_app"
echo ""

# Step 7: Optional environment variables
echo "To set environment variables (optional):"
echo "  az functionapp config appsettings set \\"
echo "    --name $APP_NAME \\"
echo "    --resource-group $RESOURCE_GROUP \\"
echo "    --settings SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass"
echo ""
