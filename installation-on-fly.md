# NATS Server Installation on Fly.io

## Installation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    NATS on Fly.io Setup                     │
└─────────────────────────────────────────────────────────────┘

Step 1: Create Fly.io App
┌──────────────────────┐
│  fly launch          │
│  - Choose app name   │
│  - Select region     │
│  - Skip database     │
└──────────┬───────────┘
           │
           ▼
Step 2: Configure fly.toml
┌──────────────────────────────────────────┐
│  [services]                              │
│    [[services.ports]]                    │
│      port = 4222                         │
│      handlers = []  ← NO HTTP!           │
│                                          │
│  [env]                                   │
│    NATS_PORT = "4222"                    │
└──────────┬───────────────────────────────┘
           │
           ▼
Step 3: Deploy NATS
┌──────────────────────┐
│  fly deploy          │
│  - Builds image      │
│  - Starts server     │
└──────────┬───────────┘
           │
           ▼
Step 4: Access via Internal DNS
┌─────────────────────────────────────────┐
│  Connection String:                     │
│  nats://<app-name>.internal:4222        │
│                                         │
│  ✓ Private 6PN network                  │
│  ✓ No egress costs                      │
│  ✓ Low latency                          │
└─────────────────────────────────────────┘
```

## Port Configuration: Why NO HTTP Handlers?

NATS uses a **custom TCP protocol**, not HTTP. In your `fly.toml`:

```toml
[[services.ports]]
  port = 4222
  handlers = []  # Empty! NATS is raw TCP, not HTTP
```

**Why this matters:**
- HTTP handlers (`["http"]`) expect HTTP protocol traffic
- NATS speaks its own binary protocol over TCP
- Using HTTP handlers will break NATS connections
- Leave `handlers = []` for raw TCP passthrough

## Internal DNS Usage

### Connection Pattern

```
Your Fly.io App          Fly.io Private Network          NATS Server
┌──────────────┐         ┌──────────────────┐         ┌─────────────┐
│              │         │                  │         │             │
│  Connect to  │────────▶│  Resolves via    │────────▶│  NATS       │
│  nats://     │         │  .internal DNS   │         │  :4222      │
│  nats.       │         │  (6PN network)   │         │             │
│  internal    │         │                  │         │             │
│  :4222       │         │  fdaa::/16       │         │             │
└──────────────┘         └──────────────────┘         └─────────────┘
```

### Why Use `.internal` DNS?

**For apps running on Fly.io:**
```
nats://nats.internal:4222
```

**Benefits:**
- ✓ Routes through Fly.io's private IPv6 network (6PN)
- ✓ Zero egress costs
- ✓ Sub-millisecond latency within same region
- ✓ Automatic service discovery
- ✓ Only accessible within your Fly.io organization

**For external access (avoid if possible):**
```
nats://your-app-name.fly.dev:4222
```

**Trade-offs:**
- ✗ Routes through public internet
- ✗ Incurs egress charges
- ✗ Higher latency
- ✗ Requires additional security (auth tokens, TLS)

### Local Development with WireGuard

Use WireGuard to access `.internal` DNS from localhost:

```bash
# 1. Create WireGuard tunnel
fly wireguard create

# 2. Connect
sudo wg-quick up <config-name>

# 3. Add to /etc/hosts
<IPv6> nats.internal

# 4. Connect from local machine
nats://nats.internal:4222
```

## Testing from Local Machine via WireGuard

### Step-by-Step Setup

```
Local Machine                WireGuard Tunnel              Fly.io 6PN Network
┌─────────────┐             ┌──────────────┐             ┌────────────────┐
│             │   Encrypted │              │   Private   │                │
│  localhost  │────────────▶│  WireGuard   │────────────▶│  nats.internal │
│             │   IPv6      │  Interface   │   IPv6      │  :4222         │
└─────────────┘             └──────────────┘             └────────────────┘
```

### 1. Create WireGuard Configuration

```bash
fly wireguard create
```

This generates a config file (e.g., `laptop-asuncion.conf`) with your tunnel settings.

### 2. Start the Tunnel

```bash
sudo wg-quick up laptop-asuncion
```

**Verify the interface is up:**
```bash
ip addr show laptop-asuncion
```

You should see an IPv6 address in the `fdaa::/16` range.

### 3. Test Fly.io DNS Connectivity

```bash
# Ping Fly.io's internal DNS server
ping6 fdaa::3
```

If this works, your tunnel is connected to Fly.io's network.

### 4. Resolve NATS Internal Hostname

```bash
# Find your NATS server's internal hostname
fly status

# Resolve it to IPv6 address
dig @fdaa::3 nats-server-summer-tree-8296.internal AAAA
```

Copy the IPv6 address from the response (e.g., `fdaa:0:1234::3`).

### 5. Configure /etc/hosts

Add the resolved IPv6 to `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Add this line:
```
fdaa:0:1234::3 nats-server-summer-tree-8296.internal
```

**Why this is needed:** WireGuard connects you to the network, but your system needs to know how to resolve `.internal` domains.

### 6. Test TCP Connection

```bash
# Test if port 4222 is reachable
nc -zv nats-server-summer-tree-8296.internal 4222
```

Expected output:
```
Connection to nats-server-summer-tree-8296.internal 4222 port [tcp/*] succeeded!
```

### 7. Test NATS Connection

**Check server info (requires authentication):**
```bash
nats server info -s nats-server-summer-tree-8296.internal:4222
```
*Note: This command requires system-level privileges. If you get "no results received" error, it means authentication is needed, but basic connectivity works.*

**Subscribe to a test subject:**
```bash
nats sub -s nats-server-summer-tree-8296.internal:4222 test.local
```

**Publish a message (in another terminal):**
```bash
nats pub -s nats-server-summer-tree-8296.internal:4222 test.local "Hello from localhost!"
```

**Check round-trip time:**
```bash
nats rtt -s nats-server-summer-tree-8296.internal:4222
```

Expected output:
```
nats://nats-server-summer-tree-8296.internal:4222:
   nats://[fdaa:7:37bb:...]:4222: ~340-700ms
```

### Test Results Summary

✓ **WireGuard tunnel active** - IPv6 connectivity established  
✓ **DNS resolution working** - `.internal` hostname resolves  
✓ **TCP port 4222 reachable** - NATS protocol accessible  
✓ **Pub/Sub messaging works** - Core functionality verified  
✓ **RTT measured** - Connection latency confirmed  

*Note: `nats server info` may fail without authentication, but pub/sub tests confirm the server is working correctly.*

### Troubleshooting

**Connection drops or timeouts:**
```bash
# Lower MTU to fix packet fragmentation
sudo ip link set dev laptop-asuncion mtu 1280
```

**DNS resolution fails:**
```bash
# Verify Fly DNS is reachable
dig @fdaa::3 nats-server-summer-tree-8296.internal AAAA

# Check /etc/hosts has correct IPv6
cat /etc/hosts | grep internal
```

**Disconnect from tunnel:**
```bash
sudo wg-quick down laptop-asuncion
```

### Benefits of Local Testing via WireGuard

- ✓ Use same connection strings as production (`nats.internal:4222`)
- ✓ No code changes between local and deployed environments
- ✓ Test with production-like latency and networking
- ✓ Access all internal services in your Fly.io organization
- ✓ No need to expose NATS publicly during development
- ✓ Zero egress costs for testing

## Quick Start Commands

```bash
# Deploy NATS
fly deploy

# Check status
fly status

# View logs
fly logs

# Test connection (from another Fly.io app)
nats server info -s nats.internal:4222

# Test pub/sub
nats sub -s nats.internal:4222 test.subject
nats pub -s nats.internal:4222 test.subject "Hello"
```

## Key Takeaways

1. **Port 4222** = NATS default, use raw TCP (no HTTP handlers)
2. **`.internal` DNS** = Private network, free, fast, secure
3. **`.fly.dev` DNS** = Public internet, costs money, slower
4. **WireGuard** = Bridge localhost to `.internal` network for development
