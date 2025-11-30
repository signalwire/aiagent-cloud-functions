# SignalWire AI Agents - Cloud Functions

Deploy SignalWire AI Agents to serverless platforms: AWS Lambda, Google Cloud Functions, and Azure Functions.

## Overview

Each directory contains a complete, deployable Hello World agent with:
- SWML output for SignalWire phone integration
- SWAIG functions (say_hello, get_platform_info, echo)
- Native CLI deployment scripts

## Platform Comparison

| Feature | AWS Lambda | Google Cloud | Azure Functions |
|---------|------------|--------------|-----------------|
| CLI | `aws` | `gcloud` | `az` |
| Runtime | Python 3.11 | Python 3.11 | Python 3.11 |
| Entry Point | `lambda_handler` | `main` | `main` |
| Max Timeout | 15 min | 60 min (Gen 2) | 10 min (Consumption) |
| Cold Starts | ~1-3s | ~1-2s | ~2-5s |
| Min Memory | 128 MB | 128 MB | Flex |
| Free Tier | 1M requests/mo | 2M invocations/mo | 1M executions/mo |

## CLI Setup

### AWS CLI

```bash
# Install AWS CLI
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Windows
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

# Configure credentials
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Default region, Output format
```

### Google Cloud CLI

```bash
# Install gcloud CLI
# macOS
brew install --cask google-cloud-sdk

# Linux/Windows - Download from:
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login

# Set project
gcloud config set project YOUR_PROJECT_ID
```

### Azure CLI

```bash
# Install Azure CLI
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Windows
winget install -e --id Microsoft.AzureCLI

# Authenticate
az login
```

## Quick Start

### AWS Lambda

```bash
cd aws
chmod +x deploy.sh
./deploy.sh
```

### Google Cloud Functions

```bash
cd gcloud
chmod +x deploy.sh
./deploy.sh
```

### Azure Functions

```bash
cd azure
chmod +x deploy.sh
./deploy.sh
```

## Directory Structure

```
cloud-functions/
├── README.md           # This file
├── aws/
│   ├── handler.py      # Lambda handler
│   ├── requirements.txt
│   ├── deploy.sh       # AWS CLI deployment
│   └── README.md
├── gcloud/
│   ├── main.py         # Cloud Functions entry point
│   ├── requirements.txt
│   ├── deploy.sh       # gcloud CLI deployment
│   └── README.md
└── azure/
    ├── function_app/
    │   ├── __init__.py # Azure Functions handler
    │   └── function.json
    ├── host.json
    ├── requirements.txt
    ├── deploy.sh       # Azure CLI deployment
    └── README.md
```

## Agent Features

All three agents implement identical functionality:

### SWAIG Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `say_hello` | Personalized greeting | `name` (string, required) |
| `get_platform_info` | Platform runtime information | none |
| `echo` | Echo back a message | `message` (string, required) |

### Voice Configuration

- Language: English (en-US)
- Voice: rime.spore

## Environment Variables

All platforms support these optional environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `SWML_BASIC_AUTH_USER` | Basic auth username | Auto-generated |
| `SWML_BASIC_AUTH_PASSWORD` | Basic auth password | Auto-generated |

**Note:** If not set, the SDK automatically generates secure credentials. The deploy scripts display the credentials after deployment.

## Authentication

The SignalWire Agents SDK automatically enables HTTP Basic Authentication for security. You can:

1. **Let the SDK generate credentials** - Secure random credentials are created automatically
2. **Set your own credentials** - Via environment variables before deployment:
   ```bash
   SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass ./deploy.sh
   ```

## Testing

### Test SWML Output

```bash
# Replace with your endpoint and credentials
curl -u username:password https://your-endpoint/
```

### Test SWAIG Function

```bash
curl -u username:password -X POST https://your-endpoint/swaig \
    -H 'Content-Type: application/json' \
    -d '{"function": "say_hello", "argument": {"parsed": [{"name": "Alice"}]}}'
```

### Local Testing with swaig-test

```bash
# AWS Lambda
cd aws
swaig-test handler.py --simulate-serverless lambda --dump-swml

# Google Cloud Functions
cd gcloud
swaig-test main.py --simulate-serverless cloud_function --dump-swml

# Azure Functions
cd azure/function_app
swaig-test __init__.py --simulate-serverless azure_function --dump-swml
```

## SignalWire Configuration

After deployment, configure your SignalWire phone number:

1. Log into your SignalWire Space
2. Navigate to **Phone Numbers**
3. Select your phone number
4. Set **Handle Calls Using** to **SWML Script**
5. Enter the endpoint URL with credentials: `https://user:pass@your-endpoint/`

## Request Flow

```
┌──────────────┐      ┌─────────────────┐      ┌──────────────────┐
│  SignalWire  │──────│  API Gateway/   │──────│  Cloud Function  │
│   Platform   │      │  HTTP Trigger   │      │  (Your Agent)    │
└──────────────┘      └─────────────────┘      └──────────────────┘
       │                      │                        │
       │   POST /             │                        │
       │─────────────────────>│───────────────────────>│
       │                      │     Returns SWML       │
       │<─────────────────────│<───────────────────────│
       │                      │                        │
       │   POST /swaig        │                        │
       │─────────────────────>│───────────────────────>│
       │                      │  Execute SWAIG func    │
       │<─────────────────────│<───────────────────────│
       │                      │                        │
```

## Best Practices

### Cold Start Optimization
- Initialize agent outside the handler function
- Keep dependencies minimal
- Use provisioned concurrency (AWS) or min instances (GCP/Azure)

### Security
- Use environment variables for secrets
- Enable basic auth for production (enabled by default)
- Use HTTPS endpoints only

### Monitoring
- Enable logging on each platform
- Monitor invocation counts and errors
- Set up alerts for failures

## Cleanup

### AWS
```bash
aws lambda delete-function --function-name signalwire-hello-world
```

### Google Cloud
```bash
gcloud functions delete signalwire-hello-world --region=us-central1 --gen2 --quiet
```

### Azure
```bash
az group delete --name signalwire-hello-world-rg --yes
```

## Requirements

- Python 3.11+
- Docker (for building deployment packages)
- signalwire-agents >= 1.0.10
- Platform CLI tools (see CLI Setup above)
