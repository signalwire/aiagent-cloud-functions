# Google Cloud Functions Deployment

Deploy a SignalWire Hello World agent to Google Cloud Functions (Gen 2).

## Prerequisites

- gcloud CLI installed and authenticated (`gcloud auth login`)
- Google Cloud project with billing enabled
- Python 3.11+

## Files

| File | Description |
|------|-------------|
| `main.py` | Cloud Function with Hello World agent |
| `requirements.txt` | Python dependencies |
| `deploy.sh` | gcloud CLI deployment script |

## Quick Start

```bash
# Make deploy script executable
chmod +x deploy.sh

# Deploy with defaults (function: signalwire-hello-world, region: us-central1)
./deploy.sh

# Or specify custom function name and region
./deploy.sh my-agent us-east1
```

## What the Script Does

1. **Enables APIs** - Cloud Functions, Cloud Build, Artifact Registry
2. **Deploys Function** - Creates Gen 2 Cloud Function with HTTP trigger
3. **Configures Access** - Allows unauthenticated invocations
4. **Returns Endpoint** - Provides the public HTTPS URL

## Environment Variables

Set via gcloud CLI:

```bash
gcloud functions deploy signalwire-hello-world \
    --region=us-central1 \
    --gen2 \
    --update-env-vars SWML_BASIC_AUTH_USER=myuser,SWML_BASIC_AUTH_PASSWORD=mypass
```

## Testing

### Test SWML Output

```bash
curl https://<region>-<project>.cloudfunctions.net/signalwire-hello-world
```

### Test SWAIG Function

```bash
curl -X POST https://<region>-<project>.cloudfunctions.net/signalwire-hello-world/swaig \
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
# Test with swaig-test (simulates Cloud Functions environment)
swaig-test main.py --simulate-serverless cloud_function --dump-swml

# Test specific function
swaig-test main.py --exec say_hello --args '{"name": "Alice"}'

# Run locally with functions-framework
functions-framework --target=main --debug
```

## SignalWire Configuration

1. Log into your SignalWire Space
2. Go to Phone Numbers
3. Select your number
4. Set "Handle Calls Using" to "SWML Script"
5. Enter your endpoint URL: `https://<region>-<project>.cloudfunctions.net/signalwire-hello-world`

## SWAIG Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `say_hello` | Greet a user | `name` (optional) |
| `get_platform_info` | Get Cloud Functions runtime info | none |
| `echo` | Echo back a message | `message` (required) |

## Cleanup

```bash
# Delete the function
gcloud functions delete signalwire-hello-world --region=us-central1 --gen2 --quiet
```

## Troubleshooting

### View Logs

```bash
gcloud functions logs read signalwire-hello-world --region=us-central1 --gen2
```

### Check Function Status

```bash
gcloud functions describe signalwire-hello-world --region=us-central1 --gen2
```

### Common Issues

1. **Permission denied**: Ensure Cloud Functions API is enabled
2. **Build failed**: Check requirements.txt for valid package names
3. **Timeout**: Increase timeout (max 60m for Gen 2)
4. **Memory errors**: Increase memory allocation (default: 512MB)
5. **Cold starts**: Set min-instances > 0 for lower latency

## Gen 2 vs Gen 1

This deployment uses Gen 2 Cloud Functions which provides:
- Longer request timeout (up to 60 minutes)
- Larger instances (up to 16GB RAM)
- Concurrency (multiple requests per instance)
- Cloud Run integration

For Gen 1, remove the `--gen2` flag from deploy commands.
