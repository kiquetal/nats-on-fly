# NATS on Fly.io Deployment Guide

This guide details how to deploy NATS (specifically enabling JetStream with persistent storage) on Fly.io and how to maintain it.

## Prerequisites

*   [Fly CLI](https://fly.io/docs/hands-on/install-flyctl/) installed.
*   Logged in via `fly auth login`.

## 1. Initialize the App

Run the following command to generate a `fly.toml` configuration file. Do **not** deploy yet when prompted.

```bash
fly launch --image nats:2.10-alpine --no-deploy
```

Follow the prompts to set your app name and region.

## 2. Create Persistent Storage

NATS JetStream requires persistent storage. Create a Fly Volume:

```bash
# Replace 'nats_data' with your preferred volume name if needed
# Replace 'sjc' with your specific region code (e.g., ams, iad, lhr)
fly vol create nats_data --size 1 --region <your-region>
```

## 3. Configure `fly.toml`

Edit the generated `fly.toml` file to mount the volume and pass necessary flags to NATS.

Ensure your `fly.toml` looks similar to this:

```toml
app = "your-app-name"
primary_region = "your-region"

[build]
  image = "nats:2.10-alpine"

# Mount the volume we created
[mounts]
  source = "nats_data"
  destination = "/data"

# Open standard NATS ports
[[services]]
  protocol = "tcp"
  internal_port = 4222
  ports = [
    { port = 4222, handlers = ["tcp"] }
  ]
  [services.concurrency]
    type = "connections"
    hard_limit = 25
    soft_limit = 20

# Optional: Monitoring port
[[services]]
  protocol = "tcp"
  internal_port = 8222
  ports = [
    { port = 8222, handlers = ["http"] }
  ]

# CMD override to enable JetStream and point to storage
# Alternatively, you can use a distinct start command in the Dockerfile or via [processes]
[experimental]
  cmd = ["-js", "-sd", "/data"]
```

*   `-js`: Enables JetStream.
*   `-sd /data`: Sets the store directory to our mounted volume.

## 4. Deploy

Deploy the application:

```bash
fly deploy
```

## 5. Future Updates

To update the NATS version in the future, simply update the image tag in your `fly.toml` or pass it directly to the deploy command.

**Option A: Update `fly.toml` (Recommended)**

1.  Edit `fly.toml`:
    ```toml
    [build]
      image = "nats:2.11-alpine" # Example new version
    ```
2.  Run `fly deploy`.

**Option B: CLI Override**

```bash
fly deploy --image nats:2.11-alpine
```

Fly.io will perform a rolling update, attaching the existing volume to the new machine, preserving your JetStream data.
