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
├── PLAN.md             # Implementation plan
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
| `say_hello` | Personalized greeting | `name` (string, optional) |
| `get_platform_info` | Platform runtime information | none |
| `echo` | Echo back a message | `message` (string, required) |

### Voice Configuration

- Language: English (en-US)
- Voice: rime.spore

## Environment Variables

All platforms support these optional environment variables:

| Variable | Description |
|----------|-------------|
| `SWML_BASIC_AUTH_USER` | Basic auth username |
| `SWML_BASIC_AUTH_PASSWORD` | Basic auth password |

## Testing

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

### Test SWAIG Function

```bash
swaig-test handler.py --exec say_hello --args '{"name": "Alice"}'
```

## SignalWire Configuration

After deployment, configure your SignalWire phone number:

1. Log into your SignalWire Space
2. Navigate to **Phone Numbers**
3. Select your phone number
4. Set **Handle Calls Using** to **SWML Script**
5. Enter the endpoint URL from your deployment

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
- Enable basic auth for production
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
- signalwire-agents >= 1.0.8
- Platform CLI tools:
  - AWS: `aws` CLI
  - Google Cloud: `gcloud` CLI
  - Azure: `az` CLI
