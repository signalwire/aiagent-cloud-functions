# Azure Functions Deployment

Deploy a SignalWire Hello World agent to Azure Functions (Linux, Python).

## Prerequisites

- Azure CLI installed and authenticated
- Docker installed and running
- An Azure subscription with appropriate permissions

### Install Azure CLI

```bash
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Windows
winget install -e --id Microsoft.AzureCLI
```

### Authenticate

```bash
az login
```

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
# Deploy with defaults (app: signalwire-hello-world, region: eastus)
./deploy.sh

# Or specify custom app name, region, and resource group
./deploy.sh my-agent westus2 my-resource-group

# Deploy with custom credentials
SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass ./deploy.sh
```

## What the Script Does

1. **Creates Resource Group** - Container for all Azure resources
2. **Creates Storage Account** - Required for Azure Functions
3. **Creates Function App** - Linux consumption plan with Python 3.11
4. **Builds with Docker** - Ensures correct linux/amd64 dependencies
5. **Deploys Code** - Uploads function code via zip deployment
6. **Configures Auth** - Sets up authentication environment variables

## Required Azure Permissions

The user running the deploy script needs the following role assignments:

### Using Built-in Roles

Assign these roles at the subscription or resource group level:

| Role | Purpose |
|------|---------|
| `Contributor` | Create and manage resources |
| `User Access Administrator` | (Optional) Assign roles to other users |

### Minimum Custom Role

```json
{
  "Name": "SignalWire Functions Deployer",
  "Description": "Can deploy SignalWire AI Agent functions",
  "Actions": [
    "Microsoft.Resources/subscriptions/resourceGroups/write",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Storage/storageAccounts/write",
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Storage/storageAccounts/listKeys/action",
    "Microsoft.Web/sites/write",
    "Microsoft.Web/sites/read",
    "Microsoft.Web/sites/config/write",
    "Microsoft.Web/sites/config/list/action",
    "Microsoft.Web/sites/publishxml/action",
    "Microsoft.Web/sites/zipdeploy/action",
    "Microsoft.Web/serverfarms/write",
    "Microsoft.Web/serverfarms/read"
  ],
  "AssignableScopes": [
    "/subscriptions/YOUR_SUBSCRIPTION_ID"
  ]
}
```

### Required Resource Providers

The deploy script requires these Azure resource providers to be registered:

```bash
# Register required providers (one-time setup)
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Storage
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SWML_BASIC_AUTH_USER` | Basic auth username | Auto-generated |
| `SWML_BASIC_AUTH_PASSWORD` | Basic auth password | Auto-generated |

**Note:** If not set, the SDK automatically generates secure credentials. The deploy script will display the credentials after deployment.

### Setting Credentials

```bash
# At deploy time
SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass ./deploy.sh

# Or update after deployment
az functionapp config appsettings set \
    --name signalwire-hello-world \
    --resource-group signalwire-hello-world-rg \
    --settings SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass
```

## Testing

### Test SWML Output

```bash
# Replace with your endpoint and credentials
curl -u username:password https://signalwire-hello-world.azurewebsites.net/api/function_app
```

### Test SWAIG Function

```bash
curl -u username:password -X POST https://signalwire-hello-world.azurewebsites.net/api/function_app/swaig \
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
5. Enter your endpoint URL with credentials: `https://user:pass@signalwire-hello-world.azurewebsites.net/api/function_app`

## SWAIG Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `say_hello` | Greet a user | `name` (required) |
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

# View recent logs via Azure Portal
# Navigate to: Function App > Functions > function_app > Monitor
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

1. **502 Bad Gateway**: Function app may be cold starting; wait and retry

2. **Deployment failed**: Check storage account connectivity
   ```bash
   az storage account show --name signalwirehelloworldstorage --resource-group signalwire-hello-world-rg
   ```

3. **Module not found**: Verify requirements.txt is correct and Docker build succeeded

4. **401 Unauthorized**: Check credentials match the app settings:
   ```bash
   az functionapp config appsettings list --name signalwire-hello-world --resource-group signalwire-hello-world-rg
   ```

5. **Timeout**: Increase function timeout in host.json (max 10 min for Consumption plan)

6. **Cold starts**: Consider Premium plan for reduced latency

7. **Resource provider not registered**:
   ```bash
   az provider register --namespace Microsoft.Web --wait
   ```

## Azure Functions Plans

| Plan | Cold Starts | Max Timeout | Scaling | Cost |
|------|-------------|-------------|---------|------|
| Consumption | Yes | 10 min | Automatic | Pay-per-use |
| Premium | Minimal | 60 min | Pre-warmed | Higher base |
| Dedicated | No | Unlimited | Manual | Fixed |

This deployment uses the Consumption plan (pay-per-use). For production with low latency requirements, consider the Premium plan:

```bash
# Create with Premium plan
az functionapp plan create \
    --name signalwire-premium-plan \
    --resource-group signalwire-hello-world-rg \
    --location eastus \
    --sku EP1 \
    --is-linux true
```
