# NATS on Fly.io Deployment Guide

This guide details how to deploy NATS (specifically enabling JetStream with persistent storage) on Fly.io and how to maintain it.

## Prerequisites

*   [Fly CLI](https://fly.io/docs/hands-on/install-flyctl/) installed.
*   Logged in via `fly auth login`.
*   **A dedicated IPv4 address** (required for non-HTTP TCP services like NATS). This costs $2/month.

## 1. Initialize the App

Run the following command to generate a `fly.toml` configuration file. Do **not** deploy yet when prompted.

```bash
fly launch --image nats:2.10-alpine --no-deploy
```

Follow the prompts to set your app name and region.

## 1.5. Using the Dockerfile

Instead of using a raw image, this project includes a `Dockerfile` to provide a consistent environment and default configuration.

### Dockerfile Breakdown

```dockerfile
FROM nats:2.10.25-alpine

# Expose client, management, and routing ports
EXPOSE 4222 8222 6222

# Default entrypoint is already "nats-server"
CMD ["-js", "-sd", "/data", "-m", "8222"]
```

**Parameters Explained:**

*   **`FROM nats:2.10.25-alpine`**: Uses the official NATS image based on Alpine Linux for a lightweight container.
*   **`EXPOSE 4222 8222 6222`**: Documents the ports used by NATS:
    *   `4222`: Main port for client connections.
    *   `8222`: HTTP monitoring and management API.
    *   `6222`: Cluster routing for inter-node communication.
*   **`CMD ["-js", "-sd", "/data", "-m", "8222"]`**:
    *   `-js`: Enables **JetStream**, providing persistence, streaming, and key-value capabilities.
    *   `-sd /data`: Specifies the **Storage Directory**. This path must correspond to the mount point of your Fly Volume.
    *   `-m 8222`: Starts the **Monitoring** server on the specified port.

To use the Dockerfile, ensure your `fly.toml` points to it:

```toml
[build]
  dockerfile = "Dockerfile"
```

## 2. Allocate a Dedicated IPv4 Address

NATS uses non-HTTP TCP protocols (port 4222 for client connections), which requires a dedicated IPv4 address on Fly.io. Allocate one for your app:

```bash
fly ips allocate-v4
```

> [!NOTE]
> Dedicated IPv4 addresses cost $2/month. This is required because Fly.io's shared IPv4 addresses only support HTTP/HTTPS traffic.

## 3. Create Persistent Storage

NATS JetStream requires persistent storage. Create a Fly Volume:

> [!IMPORTANT]
> **You must create the app first (Step 1)**. If you receive a `401 Unauthorized` error when creating a volume, it usually means the application name defined in `fly.toml` has not been registered to your Fly account yet, or is already taken by another user.

```bash
# Replace 'nats_data' with your preferred volume name if needed
# Replace 'sjc' with your specific region code (e.g., ams, iad, lhr)
fly vol create nats_data --size 1 --region <your-region>
```

## 4. Configure `fly.toml`

Edit the generated `fly.toml` file to mount the volume and pass necessary flags to NATS.

Ensure your `fly.toml` looks similar to this:

```toml
app = "your-app-name"
primary_region = "your-region"

[build]
  dockerfile = "Dockerfile"

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

# CMD override to enable JetStream, point to storage and bind to IPv6
[experimental]
  cmd = ["-js", "-sd", "/data", "-m", "8222", "-a", "::"]
```

*   `-js`: Enables JetStream.
*   `-sd /data`: Sets the store directory to our mounted volume.
*   `-m 8222`: Sets the monitoring port.
*   `-a ::`: Binds to all addresses (including IPv6), which is important for Fly.io's 6PN networking.

> [!NOTE]
> The `cmd` in `fly.toml`'s `[experimental]` section will override the `CMD` defined in the `Dockerfile`.

## 5. Understanding the Configuration

It's important to understand how JetStream and data persistence work together:

*   **JetStream Activation**: JetStream is not "on" by default in the base NATS image. It must be explicitly enabled using the `-js` flag.
*   **Data Persistence**: Even with JetStream enabled, NATS will store data in a temporary directory inside the container by default. To make data survive restarts or redeploys on Fly.io, you must:
    1.  Create and mount a **Fly Volume** (the `[mounts]` section).
    2.  Use the **`-sd /data`** flag to tell NATS to use that specific mounted path for its store directory.

Without both the volume mount and the `-sd` flag, your JetStream data will be lost every time the container restarts.

## 6. Deploy

Deploy the application:

```bash
fly deploy
```

## 7. Future Updates

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
