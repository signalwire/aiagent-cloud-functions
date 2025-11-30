# Azure Functions Deployment

Deploy a SignalWire Hello World agent to Azure Functions (Linux, Python).

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- An Azure subscription with appropriate permissions
- Python 3.11+

## Files

| File | Description |
|------|-------------|
| `function_app/__init__.py` | Function with Hello World agent |
| `function_app/function.json` | HTTP trigger configuration |
| `host.json` | Host configuration |
| `requirements.txt` | Python dependencies |
| `local.settings.json` | Local development settings |
| `deploy.sh` | Azure CLI deployment script |

## Quick Start

```bash
# Make deploy script executable
chmod +x deploy.sh

# Deploy with defaults (app: signalwire-hello-world, region: eastus)
./deploy.sh

# Or specify custom app name, region, and resource group
./deploy.sh my-agent westus2 my-resource-group
```

## What the Script Does

1. **Creates Resource Group** - Container for all Azure resources
2. **Creates Storage Account** - Required for Azure Functions
3. **Creates Function App** - Linux consumption plan with Python 3.11
4. **Deploys Code** - Uploads function code via zip deployment
5. **Returns Endpoint** - Provides the public HTTPS URL

## Environment Variables

Set via Azure CLI:

```bash
az functionapp config appsettings set \
    --name signalwire-hello-world \
    --resource-group signalwire-hello-world-rg \
    --settings SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass
```

## Testing

### Test SWML Output

```bash
curl https://signalwire-hello-world.azurewebsites.net/api/function_app
```

### Test SWAIG Function

```bash
curl -X POST https://signalwire-hello-world.azurewebsites.net/api/function_app/swaig \
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
# Test with swaig-test (simulates Azure Functions environment)
cd function_app
swaig-test __init__.py --simulate-serverless azure_function --dump-swml

# Test specific function
swaig-test __init__.py --exec say_hello --args '{"name": "Alice"}'

# Run locally with Azure Functions Core Tools
func start
```

## SignalWire Configuration

1. Log into your SignalWire Space
2. Go to Phone Numbers
3. Select your number
4. Set "Handle Calls Using" to "SWML Script"
5. Enter your endpoint URL: `https://signalwire-hello-world.azurewebsites.net/api/function_app`

## SWAIG Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `say_hello` | Greet a user | `name` (optional) |
| `get_platform_info` | Get Azure Functions runtime info | none |
| `echo` | Echo back a message | `message` (required) |

## Cleanup

```bash
# Delete entire resource group (includes all resources)
az group delete --name signalwire-hello-world-rg --yes --no-wait

# Or delete individual resources
az functionapp delete --name signalwire-hello-world --resource-group signalwire-hello-world-rg
az storage account delete --name signalwirehelloworldstorage --resource-group signalwire-hello-world-rg --yes
```

## Troubleshooting

### View Logs

```bash
# Stream logs
az functionapp log tail --name signalwire-hello-world --resource-group signalwire-hello-world-rg

# View recent logs
az monitor app-insights query \
    --app signalwire-hello-world \
    --analytics-query "traces | order by timestamp desc | take 50"
```

### Check Function Status

```bash
az functionapp show --name signalwire-hello-world --resource-group signalwire-hello-world-rg
```

### Restart Function App

```bash
az functionapp restart --name signalwire-hello-world --resource-group signalwire-hello-world-rg
```

### Common Issues

1. **502 errors**: Function app may be cold starting; wait and retry
2. **Deployment failed**: Check storage account connectivity
3. **Module not found**: Verify requirements.txt is correct
4. **Timeout**: Increase function timeout in host.json
5. **Cold starts**: Consider Premium plan for reduced latency

## Azure Functions Plans

| Plan | Cold Starts | Max Timeout | Scaling |
|------|-------------|-------------|---------|
| Consumption | Yes | 10 min | Automatic |
| Premium | Minimal | 60 min | Pre-warmed |
| Dedicated | No | Unlimited | Manual |

This deployment uses the Consumption plan (pay-per-use). For production with low latency requirements, consider the Premium plan.
