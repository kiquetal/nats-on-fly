# NATS Security Hardening - Second Day Operations

## Overview

This guide covers recommended security configurations for production NATS deployments on Fly.io. These are "second day" operations - improvements to make after your initial deployment is working.

## Current State vs. Secure State

### Current State - No Authentication

![Current State](./security-current-state.png)

### Recommended State - With Authentication

![Recommended State](./security-recommended-state.png)

### Security Layers

![Security Layers](./security-layers.png)

See [security-architecture.mmd](./security-architecture.mmd) for the full diagram source.

## Recommended Security Actions

### 1. Enable Authentication

**Current state:** NATS is running without authentication - anyone with network access can connect.

**Recommended:** Use token-based or user/password authentication.

#### Option A: Token Authentication (Simplest)

Add to your NATS configuration file:

```conf
# nats-server.conf
authorization {
  token: "$NATS_TOKEN"
}

# Enable JetStream
jetstream {
  store_dir: "/data"
}

# Monitoring
http_port: 8222
```

**Connection string for apps:**
```
nats://token@nats-server-summer-tree-8296.internal:4222
```

**Set token as Fly.io secret:**
```bash
fly secrets set NATS_TOKEN=your-secure-random-token -a nats-server-summer-tree-8296
```

#### Option B: User/Password Authentication (More Flexible)

```conf
# nats-server.conf
authorization {
  users = [
    {
      user: "app_user"
      password: "$APP_PASSWORD"
    }
    {
      user: "admin"
      password: "$ADMIN_PASSWORD"
      permissions: {
        publish: ">"
        subscribe: ">"
      }
    }
  ]
}

jetstream {
  store_dir: "/data"
}

http_port: 8222
```

**Connection string:**
```
nats://app_user:password@nats-server-summer-tree-8296.internal:4222
```

### 2. Configure System Account for Monitoring

**Why:** Enables `nats server info` and other monitoring commands.

```conf
# nats-server.conf
accounts {
  SYS: {
    users: [
      {user: "admin", password: "$SYS_PASSWORD"}
    ]
  }
  APP: {
    users: [
      {user: "app_user", password: "$APP_PASSWORD"}
    ]
    jetstream: enabled
  }
}

system_account: SYS

jetstream {
  store_dir: "/data"
}

http_port: 8222
```

**Monitor with:**
```bash
nats server info -s nats://admin:password@nats-server-summer-tree-8296.internal:4222
```

### 3. Enable TLS (Optional but Recommended)

**Why:** Encrypts traffic between clients and NATS server.

**Note:** Within Fly.io's private 6PN network, traffic is already isolated to your organization, but TLS adds an extra layer.

```conf
# nats-server.conf
tls {
  cert_file: "/certs/server-cert.pem"
  key_file: "/certs/server-key.pem"
  ca_file: "/certs/ca.pem"
  verify: true
}

authorization {
  token: "$NATS_TOKEN"
}

jetstream {
  store_dir: "/data"
}

http_port: 8222
```

**Connection string:**
```
nats://token@nats-server-summer-tree-8296.internal:4222?tls=true
```

### 4. Implement Subject-Level Permissions

**Why:** Restrict which subjects each user/app can publish or subscribe to.

```conf
# nats-server.conf
authorization {
  users = [
    {
      user: "quarkus_app"
      password: "$QUARKUS_PASSWORD"
      permissions: {
        publish: ["orders.>", "events.quarkus.>"]
        subscribe: ["orders.>", "notifications.>"]
      }
    }
    {
      user: "fsharp_app"
      password: "$FSHARP_PASSWORD"
      permissions: {
        publish: ["events.fsharp.>", "notifications.>"]
        subscribe: ["orders.>", "events.>"]
      }
    }
  ]
}

jetstream {
  store_dir: "/data"
}

http_port: 8222
```

### 5. Configure Resource Limits

**Why:** Prevent resource exhaustion from misbehaving clients.

```conf
# nats-server.conf
max_connections: 100
max_payload: 1048576  # 1MB
max_pending: 67108864  # 64MB

authorization {
  token: "$NATS_TOKEN"
}

jetstream {
  store_dir: "/data"
  max_memory_store: 1073741824  # 1GB
  max_file_store: 10737418240   # 10GB
}

http_port: 8222
```

## Implementation Steps

### Step 1: Create Configuration File

Create `nats-server.conf` with your chosen security settings (start with token auth for simplicity).

### Step 2: Update Dockerfile

**Current command:**
```dockerfile
CMD ["-js", "-sd", "/data", "-m", "8222", "-a", "::"]
```

**Updated command:**
```dockerfile
COPY nats-server.conf /etc/nats/nats-server.conf
CMD ["-c", "/etc/nats/nats-server.conf"]
```

### Step 3: Set Secrets in Fly.io

```bash
# Generate a secure token
TOKEN=$(openssl rand -base64 32)

# Set as Fly.io secret
fly secrets set NATS_TOKEN=$TOKEN -a nats-server-summer-tree-8296
```

### Step 4: Update Application Connection Strings

**Quarkus (application.properties):**
```properties
nats.url=nats://${NATS_TOKEN}@nats-server-summer-tree-8296.internal:4222
```

**F# (configuration):**
```fsharp
let natsUrl = Environment.GetEnvironmentVariable("NATS_URL")
// nats://token@nats-server-summer-tree-8296.internal:4222
```

### Step 5: Deploy and Test

```bash
# Deploy NATS with new config
fly deploy -a nats-server-summer-tree-8296

# Test connectivity with token
nats pub -s nats://$NATS_TOKEN@nats-server-summer-tree-8296.internal:4222 test "Hello Secure NATS"
```

## Monitoring and Observability

### Access Monitoring Dashboard

NATS exposes metrics on port 8222:

```bash
# Via WireGuard
curl http://nats-server-summer-tree-8296.internal:8222/varz

# Check connections
curl http://nats-server-summer-tree-8296.internal:8222/connz

# Check subscriptions
curl http://nats-server-summer-tree-8296.internal:8222/subsz
```

### Key Metrics to Monitor

- **Connections:** Number of active client connections
- **Messages in/out:** Throughput metrics
- **Slow consumers:** Clients falling behind
- **Memory usage:** JetStream memory consumption
- **Disk usage:** JetStream file store size

## Security Checklist

- [ ] Enable authentication (token or user/password)
- [ ] Configure system account for monitoring
- [ ] Set up subject-level permissions per app
- [ ] Configure resource limits (connections, payload, memory)
- [ ] Store credentials in Fly.io secrets (not in code)
- [ ] Enable TLS for encrypted communication (optional)
- [ ] Restrict monitoring port (8222) access
- [ ] Implement connection limits per client
- [ ] Set up alerting for failed auth attempts
- [ ] Regular credential rotation policy

## References

- [NATS Authentication](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro)
- [NATS Authorization](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/authorization)
- [NATS TLS Configuration](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/tls)
- [JetStream Configuration](https://docs.nats.io/running-a-nats-service/configuration#jetstream)
- [NATS Monitoring](https://docs.nats.io/running-a-nats-service/configuration/monitoring)
- [Fly.io Secrets Management](https://fly.io/docs/reference/secrets/)
