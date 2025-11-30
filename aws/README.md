# AWS Lambda Deployment

Deploy a SignalWire Hello World agent to AWS Lambda with API Gateway.

## Prerequisites

- AWS CLI installed and configured (`aws configure`)
- Docker installed and running
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

# Deploy with custom credentials
SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass ./deploy.sh
```

## What the Script Does

1. **Creates IAM Role** - Lambda execution role with basic permissions
2. **Packages Function** - Uses Docker to build dependencies for Lambda's linux/amd64 architecture
3. **Deploys Lambda** - Creates or updates the Lambda function with authentication configured
4. **Creates API Gateway** - HTTP API for public endpoint
5. **Configures Routes** - Routes for SWML (/) and SWAIG (/swaig)
6. **Sets Permissions** - Allows API Gateway to invoke Lambda

## Authentication

The SignalWire agent requires HTTP Basic Authentication. Credentials are configured via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `SWML_BASIC_AUTH_USER` | Basic auth username | `admin` |
| `SWML_BASIC_AUTH_PASSWORD` | Basic auth password | Random (generated at deploy) |

### Setting Credentials at Deploy Time

```bash
# Set credentials before deployment
SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=secretpass ./deploy.sh
```

### Updating Credentials After Deployment

```bash
aws lambda update-function-configuration \
    --function-name signalwire-hello-world \
    --region us-east-1 \
    --environment "Variables={SWML_BASIC_AUTH_USER=newuser,SWML_BASIC_AUTH_PASSWORD=newpass}"
```

## Testing

### Test SWML Output

```bash
# Replace with your credentials and endpoint
curl -u admin:yourpassword https://<api-id>.execute-api.<region>.amazonaws.com/
```

### Test SWAIG Function

```bash
curl -u admin:yourpassword -X POST https://<api-id>.execute-api.<region>.amazonaws.com/swaig \
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
5. Enter your endpoint URL with credentials: `https://user:pass@<api-id>.execute-api.<region>.amazonaws.com/`

## SWAIG Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `say_hello` | Greet a user | `name` (required) |
| `get_platform_info` | Get Lambda runtime info | none |
| `echo` | Echo back a message | `message` (required) |

## AWS IAM Permissions

The deploying user needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:GetFunction",
        "lambda:DeleteFunction",
        "lambda:AddPermission",
        "lambda:RemovePermission",
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:function:signalwire-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "apigateway:*",
        "apigatewayv2:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:GetRole",
        "iam:AttachRolePolicy",
        "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::*:role/signalwire-*"
    }
  ]
}
```

## Cleanup

```bash
# Delete Lambda function
aws lambda delete-function --function-name signalwire-hello-world --region us-east-1

# Delete API Gateway
API_ID=$(aws apigatewayv2 get-apis --region us-east-1 --query "Items[?Name=='signalwire-hello-world-api'].ApiId" --output text)
aws apigatewayv2 delete-api --api-id $API_ID --region us-east-1

# Delete IAM role
aws iam detach-role-policy --role-name signalwire-hello-world-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name signalwire-hello-world-role
```

## Troubleshooting

### Check Lambda Logs

```bash
aws logs tail /aws/lambda/signalwire-hello-world --follow --region us-east-1
```

### Test Lambda Directly

```bash
aws lambda invoke \
    --function-name signalwire-hello-world \
    --region us-east-1 \
    --payload '{"requestContext":{"http":{"method":"GET","path":"/"}},"rawPath":"/"}' \
    --cli-binary-format raw-in-base64-out \
    response.json && cat response.json
```

### Common Issues

1. **"fastapi is required" error**: The deployment package was built with wrong architecture. Ensure Docker is running and the script uses `--platform linux/amd64`.

2. **401 Unauthorized**: Check your credentials match what's configured in Lambda environment variables.

3. **Timeout errors**: Increase Lambda timeout (default: 30s)

4. **Memory errors**: Increase memory allocation (default: 512MB)

5. **Permission denied**: Check IAM role has correct policies

6. **Cold starts**: First request may be slow; consider provisioned concurrency

7. **Upload timeout**: Large packages may timeout on slow connections. The script uses `--cli-read-timeout 300` to allow up to 5 minutes.
