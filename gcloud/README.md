# Google Cloud Functions Deployment

Deploy a SignalWire Hello World agent to Google Cloud Functions (Gen 2).

## Prerequisites

- gcloud CLI installed and authenticated
- Google Cloud project with billing enabled
- Python 3.11+

### Install gcloud CLI

```bash
# macOS
brew install --cask google-cloud-sdk

# Linux
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh

# Windows - Download installer from:
# https://cloud.google.com/sdk/docs/install
```

### Authenticate and Configure

```bash
# Authenticate
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Verify configuration
gcloud config list
```

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

# Deploy with custom credentials
SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass ./deploy.sh
```

## What the Script Does

1. **Enables APIs** - Cloud Functions, Cloud Build, Artifact Registry
2. **Deploys Function** - Creates Gen 2 Cloud Function with HTTP trigger
3. **Configures Access** - Allows unauthenticated invocations
4. **Returns Endpoint** - Provides the public HTTPS URL

## Required GCP Permissions

The user running the deploy script needs the following IAM roles:

### Using Predefined Roles

Assign these roles at the project level:

| Role | Purpose |
|------|---------|
| `roles/cloudfunctions.developer` | Deploy and manage functions |
| `roles/cloudbuild.builds.builder` | Build function containers |
| `roles/artifactregistry.writer` | Store container images |
| `roles/iam.serviceAccountUser` | Use service accounts |

### Grant Roles via CLI

```bash
PROJECT_ID=$(gcloud config get-value project)
USER_EMAIL=$(gcloud config get-value account)

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$USER_EMAIL" \
    --role="roles/cloudfunctions.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$USER_EMAIL" \
    --role="roles/cloudbuild.builds.builder"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$USER_EMAIL" \
    --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$USER_EMAIL" \
    --role="roles/iam.serviceAccountUser"
```

### Required APIs

The deploy script automatically enables these APIs:

```bash
# Enable manually if needed
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable run.googleapis.com
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SWML_BASIC_AUTH_USER` | Basic auth username | Auto-generated |
| `SWML_BASIC_AUTH_PASSWORD` | Basic auth password | Auto-generated |

**Note:** If not set, the SDK automatically generates secure credentials.

### Setting Credentials

```bash
# At deploy time
SWML_BASIC_AUTH_USER=myuser SWML_BASIC_AUTH_PASSWORD=mypass ./deploy.sh

# Or update after deployment
gcloud functions deploy signalwire-hello-world \
    --region=us-central1 \
    --gen2 \
    --update-env-vars SWML_BASIC_AUTH_USER=myuser,SWML_BASIC_AUTH_PASSWORD=mypass
```

## Testing

### Test SWML Output

```bash
# Replace with your credentials and endpoint
curl -u username:password https://signalwire-hello-world-XXXXX-uc.a.run.app
```

### Test SWAIG Function

```bash
curl -u username:password -X POST https://signalwire-hello-world-XXXXX-uc.a.run.app/swaig \
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
pip install functions-framework
functions-framework --target=main --debug
```

## SignalWire Configuration

1. Log into your SignalWire Space
2. Go to Phone Numbers
3. Select your number
4. Set "Handle Calls Using" to "SWML Script"
5. Enter your endpoint URL with credentials: `https://user:pass@signalwire-hello-world-XXXXX-uc.a.run.app`

## SWAIG Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `say_hello` | Greet a user | `name` (required) |
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
# View recent logs
gcloud functions logs read signalwire-hello-world --region=us-central1 --gen2

# Stream logs in real-time
gcloud functions logs read signalwire-hello-world --region=us-central1 --gen2 --limit=50
```

### Check Function Status

```bash
gcloud functions describe signalwire-hello-world --region=us-central1 --gen2
```

### Common Issues

1. **Permission denied**: Ensure required APIs are enabled and IAM roles are assigned
   ```bash
   gcloud services enable cloudfunctions.googleapis.com
   ```

2. **Build failed**: Check requirements.txt for valid package names
   ```bash
   gcloud builds list --limit=5
   gcloud builds log BUILD_ID
   ```

3. **401 Unauthorized**: Check credentials match the environment variables:
   ```bash
   gcloud functions describe signalwire-hello-world --region=us-central1 --gen2 \
       --format="value(serviceConfig.environmentVariables)"
   ```

4. **Timeout**: Increase timeout (max 60m for Gen 2)
   ```bash
   gcloud functions deploy signalwire-hello-world \
       --region=us-central1 \
       --gen2 \
       --timeout=120s
   ```

5. **Memory errors**: Increase memory allocation (default: 512MB)
   ```bash
   gcloud functions deploy signalwire-hello-world \
       --region=us-central1 \
       --gen2 \
       --memory=1024MB
   ```

6. **Cold starts**: Set min-instances > 0 for lower latency
   ```bash
   gcloud functions deploy signalwire-hello-world \
       --region=us-central1 \
       --gen2 \
       --min-instances=1
   ```

7. **Billing not enabled**: Enable billing for your project at:
   https://console.cloud.google.com/billing

## Gen 2 vs Gen 1

This deployment uses Gen 2 Cloud Functions which provides:

| Feature | Gen 1 | Gen 2 |
|---------|-------|-------|
| Max timeout | 9 min | 60 min |
| Max memory | 8 GB | 16 GB |
| Concurrency | 1 | Up to 1000 |
| Min instances | No | Yes |
| Infrastructure | Cloud Functions | Cloud Run |

For Gen 1, remove the `--gen2` flag from deploy commands.
