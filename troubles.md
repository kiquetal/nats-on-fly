#### After exposing 8222 on the fly.toml I should add the tls, because otherway did not work!

#### WireGuard and Internal Network Access

1. **Create WireGuard Config:**
   Use the following command to create a WireGuard configuration and obtain the config file:
   ```bash
   fly wireguard create
   ```

2. **Up and Down WireGuard:**
   To bring the WireGuard interface up or down:
   ```bash
   sudo wg-quick up laptop-asuncion
   sudo wg-quick down laptop-asuncion
   ```

3. **Fix MTU Issues:**
   If you experience connection drops or stalls, you may need to lower the MTU on the interface (e.g., `laptop-asuncion`).
   ```bash
   sudo ip link set dev laptop-asuncion mtu 1280
   ```

4. **DNS Resolution via /etc/hosts:**
   To access the internal NATS server URL (`nats-server-summer-tree-8296.internal:4222`) from your local machine, add an entry to your `/etc/hosts` file pointing the internal hostname to its IPv6 address (reachable via WireGuard).
   ```
   <IPv6_ADDRESS> nats-server-summer-tree-8296.internal
   ```

#### Testing Connectivity

1. **Verify Interface:**
   Ensure the WireGuard interface is active and has an IP assigned:
   ```bash
   ip addr show laptop-asuncion
   ```

2. **Ping Internal IPv6:**
   Test connectivity to the internal network by pinging the Fly DNS server or your app's internal IPv6:
   ```bash
   ping6 fdaa::3
   ping6 <IPv6_ADDRESS>
   ```

3. **Test Private DNS Resolution:**
   Check if the internal DNS is resolving hostnames correctly:
   ```bash
   dig @fdaa::3 nats-server-summer-tree-8296.internal AAAA
   ```

4. **Verify NATS Port Accessibility:**
   Use `nc` or `telnet` to ensure you can reach the NATS port over the tunnel:
   ```
   nc -zv nats-server-summer-tree-8296.internal 4222
   ```

#### Verify NATS Installation with CLI

1. **Check Server Information:**
   Use the NATS CLI to retrieve server information:
   ```bash
   nats server info -s nats-server-summer-tree-8296.internal:4222
   ```

2. **Test Messaging (Pub/Sub):**
   Open two terminals. In the first, subscribe to a test subject:
   ```bash
   nats sub -s nats-server-summer-tree-8296.internal:4222 test.subject
   ```
   In the second, publish a message:
   ```bash
   nats pub -s nats-server-summer-tree-8296.internal:4222 test.subject "Hello NATS"
   ```

3. **Check Round-Trip Time:**
   ```bash
   nats rtt -s nats-server-summer-tree-8296.internal:4222
   ```