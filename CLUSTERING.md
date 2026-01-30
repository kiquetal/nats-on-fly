# NATS Clustering on Fly.io

This guide outlines the steps to enable NATS clustering using port `6222`.

**Note:** Port `6222` is used for internal cluster communication. It should **not** be exposed to the public internet via `fly.toml` `[[services]]`. It functions entirely over Fly.io's private IPv6 network.

## 1. The Challenge
NATS servers need to know the addresses of other servers to form a cluster. On dynamic platforms like Fly.io, IPs change. We need a startup script to discover other nodes via DNS.

## 2. Create a Startup Script
Create a file named `entrypoint.sh` in your project root. This script will:
1.  Look up other instances of your app using Fly's internal DNS.
2.  Construct the `--routes` flag for NATS.
3.  Start the NATS server.

**File: `entrypoint.sh`**
```bash
#!/bin/sh

# Set the clustering port
CLUSTER_PORT=6222

# Get current IP (internal Fly.io IPv6)
# `fly-local-6pn` is a special hostname in Fly VMs that resolves to the local IPv6
# If that fails, we try to grab it from hostname -i
CURRENT_IP=$(hostname -i | awk '{print $1}')

echo "Current IP: $CURRENT_IP"

# Find other peers
# We look up the global internal address for the app
# Dig is usually available in alpine, or we can use nslookup
# We format the output to be nats://[<ip>]:6222
PEERS=""

# Simple loop to try and resolve peers (simplified for example)
# In production, you might want a more robust discovery mechanism or use NATS 2.10+ specific resolver config if available.
# For a basic setup, we assume we are seeding the first node or using a manual approach.

# A common pattern on Fly is simply explicitly listing the "gateway" or "seed" if known, 
# or iterating through DNS results.

# -- construct the route flag --
# For this example, we will just point to the internal DNS name. 
# NATS can sometimes resolve A/AAAA records directly if configured correctly, 
# but often needs explicit IPs.

# COMMAND CONSTRUCTION
# We start NATS with the cluster flag binding to the local IP (or 0.0.0.0)
CMD="nats-server -js -sd /data -name $(hostname) -cluster nats://0.0.0.0:$CLUSTER_PORT"

# If we have a variable defined for routes (e.g. set in fly.toml secrets or env)
if [ ! -z "$NATS_ROUTES" ]; then
  CMD="$CMD -routes $NATS_ROUTES"
fi

# Execute
echo "Starting: $CMD"
exec $CMD
```

*Note: For a robust auto-discovery on Fly without external dependencies, you might need to install `bind-tools` (for `dig`) in your Dockerfile and write a loop to populate `$NATS_ROUTES` dynamically based on `global.<appname>.internal`.*

## 3. Update `Dockerfile`
You need to add the script to your image and install any dependencies needed for discovery (like `bind-tools` if you use `dig`, or `bash`).

```dockerfile
FROM nats:2.10.25-alpine

# Install tools for DNS lookup if needed (Alpine)
RUN apk add --no-cache bind-tools

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose the cluster port
EXPOSE 4222 8222 6222

# Set the new entrypoint
ENTRYPOINT ["/entrypoint.sh"]
```

## 4. Update `fly.toml`
You no longer need the `cmd` override in `fly.toml` because the `ENTRYPOINT` in the Dockerfile handles it.

**Remove this section from `fly.toml`:**
```toml
[experimental]
  cmd = ['-js', '-sd', '/data']
```

## 5. Deploy and Scale
1.  **Deploy the changes:**
    ```bash
    fly deploy
    ```
2.  **Scale up:**
    Clustering requires at least 2 VMs.
    ```bash
    fly scale count 3
    ```

## 6. Verification
Connect to your NATS monitoring port (now exposed via HTTP on 8222 as per your setup) or check the logs:
```bash
fly logs
```
You should see messages about "Cluster connection established".
