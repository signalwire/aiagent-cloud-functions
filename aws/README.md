# AWS Lambda Deployment

Deploy a SignalWire Hello World agent to AWS Lambda with API Gateway.

## Prerequisites

- AWS CLI installed and configured (`aws configure`)
- Python 3.11+
- AWS account with appropriate permissions

## Files

| File | Description |
|------|-------------|
| `handler.py` | Lambda function with Hello World agent |
| `requirements.txt` | Python dependencies |
| `deploy.sh` | AWS CLI deployment script |

## Quick Start

```bash
# Make deploy script executable
chmod +x deploy.sh

# Deploy with defaults (function: signalwire-hello-world, region: us-east-1)
./deploy.sh

# Or specify custom function name and region
./deploy.sh my-agent us-west-2
```

## What the Script Does

1. **Creates IAM Role** - Lambda execution role with basic permissions
2. **Packages Function** - Installs dependencies and creates zip
3. **Deploys Lambda** - Creates or updates the Lambda function
4. **Creates API Gateway** - HTTP API for public endpoint
5. **Configures Routes** - Routes for SWML (/) and SWAIG (/swaig)
6. **Sets Permissions** - Allows API Gateway to invoke Lambda

## Environment Variables

Set these in the Lambda console or via AWS CLI:

```bash
# Optional: Basic authentication
aws lambda update-function-configuration \
    --function-name signalwire-hello-world \
    --environment "Variables={SWML_BASIC_AUTH_USER=myuser,SWML_BASIC_AUTH_PASSWORD=mypass}"
```

## Testing

### Test SWML Output

```bash
curl https://<api-id>.execute-api.<region>.amazonaws.com/
```

### Test SWAIG Function

```bash
curl -X POST https://<api-id>.execute-api.<region>.amazonaws.com/swaig \
    -H 'Content-Type: application/json' \
    -d '{
        "function": "say_hello",
        "argument": {
            "parsed": [{"name": "Alice"}]
        }
    }'
```

### Local Testing

```bash
# Test with swaig-test (simulates Lambda environment)
swaig-test handler.py --simulate-serverless lambda --dump-swml

# Test specific function
swaig-test handler.py --exec say_hello --args '{"name": "Alice"}'
```

## SignalWire Configuration

1. Log into your SignalWire Space
2. Go to Phone Numbers
3. Select your number
4. Set "Handle Calls Using" to "SWML Script"
5. Enter your endpoint URL: `https://<api-id>.execute-api.<region>.amazonaws.com/`

## SWAIG Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `say_hello` | Greet a user | `name` (optional) |
| `get_platform_info` | Get Lambda runtime info | none |
| `echo` | Echo back a message | `message` (required) |

## Cleanup

```bash
# Delete Lambda function
aws lambda delete-function --function-name signalwire-hello-world

# Delete API Gateway
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='signalwire-hello-world-api'].ApiId" --output text)
aws apigatewayv2 delete-api --api-id $API_ID

# Delete IAM role
aws iam detach-role-policy --role-name signalwire-hello-world-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name signalwire-hello-world-role
```

## Troubleshooting

### Check Lambda Logs

```bash
aws logs tail /aws/lambda/signalwire-hello-world --follow
```

### Test Lambda Directly

```bash
aws lambda invoke \
    --function-name signalwire-hello-world \
    --payload '{"requestContext":{"http":{"method":"GET","path":"/"}},"rawPath":"/"}' \
    --cli-binary-format raw-in-base64-out \
    response.json && cat response.json
```

### Common Issues

1. **Timeout errors**: Increase Lambda timeout (default: 30s)
2. **Memory errors**: Increase memory allocation (default: 512MB)
3. **Permission denied**: Check IAM role has correct policies
4. **Cold starts**: First request may be slow; consider provisioned concurrency
