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