#!/bin/bash
# AWS Lambda deployment script for SignalWire Hello World agent
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Docker installed and running (for building Lambda-compatible packages)
#
# Usage:
#   ./deploy.sh                    # Deploy with defaults
#   ./deploy.sh my-function        # Deploy with custom function name
#   ./deploy.sh my-function us-west-2  # Custom function and region

set -e

# Configuration
FUNCTION_NAME="${1:-signalwire-hello-world}"
REGION="${2:-us-east-1}"
RUNTIME="python3.11"
HANDLER="handler.lambda_handler"
MEMORY_SIZE=512
TIMEOUT=30
ROLE_NAME="${FUNCTION_NAME}-role"

# Credentials (set via environment or auto-generate)
SWML_BASIC_AUTH_USER="${SWML_BASIC_AUTH_USER:-admin}"
SWML_BASIC_AUTH_PASSWORD="${SWML_BASIC_AUTH_PASSWORD:-$(openssl rand -base64 12)}"

echo "=== SignalWire Hello World - AWS Lambda Deployment ==="
echo "Function: $FUNCTION_NAME"
echo "Region: $REGION"
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

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Step 1: Create IAM role if it doesn't exist
echo "Step 1: Setting up IAM role..."

TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

if ! aws iam get-role --role-name "$ROLE_NAME" --region "$REGION" 2>/dev/null; then
    echo "Creating IAM role: $ROLE_NAME"
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --region "$REGION"

    # Attach basic Lambda execution policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" \
        --region "$REGION"

    echo "Waiting for role to propagate..."
    sleep 10
else
    echo "IAM role already exists: $ROLE_NAME"
fi

# Step 2: Package the function using Docker
echo ""
echo "Step 2: Packaging function with Docker (linux/amd64)..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR=$(mktemp -d)
PACKAGE_DIR="$BUILD_DIR/package"
ZIP_FILE="$BUILD_DIR/function.zip"

mkdir -p "$PACKAGE_DIR"

# Build dependencies using Lambda Python image for correct architecture
echo "Installing dependencies via Docker..."
docker run --rm \
    --platform linux/amd64 \
    --entrypoint "" \
    -v "$SCRIPT_DIR:/var/task:ro" \
    -v "$PACKAGE_DIR:/var/output" \
    -w /var/task \
    public.ecr.aws/lambda/python:3.11 \
    bash -c "pip install -r requirements.txt -t /var/output --quiet && cp handler.py /var/output/"

# Create zip
echo "Creating deployment package..."
cd "$PACKAGE_DIR"
zip -r "$ZIP_FILE" . -q
cd - > /dev/null

PACKAGE_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
echo "Package size: $PACKAGE_SIZE"

# Step 3: Create or update Lambda function
echo ""
echo "Step 3: Deploying Lambda function..."

if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" 2>/dev/null; then
    echo "Updating existing function..."
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://$ZIP_FILE" \
        --region "$REGION" \
        --cli-read-timeout 300 \
        --output text --query 'FunctionArn'
else
    echo "Creating new function..."
    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime "$RUNTIME" \
        --role "$ROLE_ARN" \
        --handler "$HANDLER" \
        --zip-file "fileb://$ZIP_FILE" \
        --memory-size "$MEMORY_SIZE" \
        --timeout "$TIMEOUT" \
        --region "$REGION" \
        --cli-read-timeout 300 \
        --output text --query 'FunctionArn'
fi

# Wait for function to be active
echo "Waiting for function to be active..."
aws lambda wait function-active --function-name "$FUNCTION_NAME" --region "$REGION"

# Update environment variables (always, for both new and existing functions)
echo "Configuring environment variables..."
aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --environment "Variables={SWML_BASIC_AUTH_USER=$SWML_BASIC_AUTH_USER,SWML_BASIC_AUTH_PASSWORD=$SWML_BASIC_AUTH_PASSWORD}" \
    --output text --query 'FunctionArn' > /dev/null

aws lambda wait function-updated --function-name "$FUNCTION_NAME" --region "$REGION"

# Step 4: Create or get API Gateway
echo ""
echo "Step 4: Setting up API Gateway..."

API_NAME="${FUNCTION_NAME}-api"

# Check if API exists
API_ID=$(aws apigatewayv2 get-apis --region "$REGION" \
    --query "Items[?Name=='$API_NAME'].ApiId" --output text)

if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
    echo "Creating HTTP API..."
    API_ID=$(aws apigatewayv2 create-api \
        --name "$API_NAME" \
        --protocol-type HTTP \
        --region "$REGION" \
        --output text --query 'ApiId')
fi

echo "API ID: $API_ID"

# Step 5: Create Lambda integration
echo ""
echo "Step 5: Creating Lambda integration..."

LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${FUNCTION_NAME}"

# Check for existing integration
INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
    --api-id "$API_ID" \
    --region "$REGION" \
    --query "Items[?IntegrationUri=='${LAMBDA_ARN}'].IntegrationId" \
    --output text 2>/dev/null || echo "")

if [ -z "$INTEGRATION_ID" ] || [ "$INTEGRATION_ID" == "None" ]; then
    echo "Creating integration..."
    INTEGRATION_ID=$(aws apigatewayv2 create-integration \
        --api-id "$API_ID" \
        --integration-type AWS_PROXY \
        --integration-uri "$LAMBDA_ARN" \
        --payload-format-version "2.0" \
        --region "$REGION" \
        --output text --query 'IntegrationId')
fi

echo "Integration ID: $INTEGRATION_ID"

# Step 6: Create routes
echo ""
echo "Step 6: Creating routes..."

create_route() {
    local route_key="$1"
    local existing=$(aws apigatewayv2 get-routes \
        --api-id "$API_ID" \
        --region "$REGION" \
        --query "Items[?RouteKey=='$route_key'].RouteId" \
        --output text 2>/dev/null || echo "")

    if [ -z "$existing" ] || [ "$existing" == "None" ]; then
        echo "Creating route: $route_key"
        aws apigatewayv2 create-route \
            --api-id "$API_ID" \
            --route-key "$route_key" \
            --target "integrations/$INTEGRATION_ID" \
            --region "$REGION" \
            --output text --query 'RouteId'
    else
        echo "Route exists: $route_key"
    fi
}

# Create routes for SWML and SWAIG
create_route "GET /"
create_route "POST /"
create_route "POST /swaig"
create_route "ANY /{proxy+}"

# Step 7: Create/update stage
echo ""
echo "Step 7: Deploying stage..."

STAGE_NAME="\$default"

if ! aws apigatewayv2 get-stage --api-id "$API_ID" --stage-name "$STAGE_NAME" --region "$REGION" 2>/dev/null; then
    aws apigatewayv2 create-stage \
        --api-id "$API_ID" \
        --stage-name "$STAGE_NAME" \
        --auto-deploy \
        --region "$REGION" > /dev/null
fi

# Step 8: Add Lambda permission for API Gateway
echo ""
echo "Step 8: Configuring permissions..."

STATEMENT_ID="${API_NAME}-invoke"

# Remove existing permission if it exists (ignore errors)
aws lambda remove-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id "$STATEMENT_ID" \
    --region "$REGION" 2>/dev/null || true

# Add permission
aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id "$STATEMENT_ID" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*" \
    --region "$REGION" > /dev/null

# Get the endpoint URL
ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com"

# Cleanup
rm -rf "$BUILD_DIR"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Endpoint URL: $ENDPOINT"
echo ""
echo "Authentication:"
echo "  Username: $SWML_BASIC_AUTH_USER"
echo "  Password: $SWML_BASIC_AUTH_PASSWORD"
echo ""
echo "Test SWML output:"
echo "  curl -u $SWML_BASIC_AUTH_USER:$SWML_BASIC_AUTH_PASSWORD $ENDPOINT/"
echo ""
echo "Test SWAIG function:"
echo "  curl -u $SWML_BASIC_AUTH_USER:$SWML_BASIC_AUTH_PASSWORD -X POST $ENDPOINT/swaig \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"function\": \"say_hello\", \"argument\": {\"parsed\": [{\"name\": \"Alice\"}]}}'"
echo ""
echo "Configure SignalWire:"
echo "  Set your phone number's SWML URL to: https://$SWML_BASIC_AUTH_USER:$SWML_BASIC_AUTH_PASSWORD@${API_ID}.execute-api.${REGION}.amazonaws.com/"
echo ""
