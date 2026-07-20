#!/bin/bash

echo "========================================================="
echo " MASTER BOOT OPTIMIZER 13.8 (NELFOX PROXMOX EDITION)     "
echo " Universal Setup (SQLite/PostgreSQL)                     "
echo " Flarego Technologies - Performance & Stability          "
echo "========================================================="
echo ""
echo "--- CHANGE LOG ---"
echo "v13.8 | UPDATED: Surgical Kernel Maintenance Strategy"
echo "      | ADDED: Surgical Cleanup Logic to FlareWiFi Daily Maintenance."
echo "      |        Uses active session cross-referencing to remove only"
echo "      |        orphaned TC classes, preventing structural tree collapse."
echo "      | FIX: Replaced destructive 'tc qdisc del' root-scrubbing with"
echo "      |      non-blocking handle-level synchronization to eliminate"
echo "      |      'Change operation not supported' and RTNETLINK crashes."
echo "      | NOTE: Maintenance operations now run asynchronously to"
echo "      |       ensure zero-impact on live traffic sessions."
echo "v13.5 | UPDATED: Relational Session Purge & Voucher Immunization"
echo "      | FIX: Resolved PostgreSQL 'status' column verification errors"
echo "      |      within the automated and manual cleanup routines."
echo "      | ADDED: Standard Relational Subquery Safeguard to validate parent"
echo "      |        voucher state before session purging. Completely immunizes"
echo "      |        active ('Activated') vouchers against user slot drains"
echo "      |        and voucher reuse loopholes."
echo ""
echo "v13.4 | UPDATED: Hybrid x86/ARM Architecture & SQM Pipeline"
echo "      | ADDED: Step 12.5 Idempotent TC Wrapper placement immediately"
echo "      |        before CAKE SQM to eradicate 72-hour EEXIST crashes."
echo "      | FIX: Dynamic WAN interface discovery (removed hardcoded enp4s0),"
echo "      |      reliable uname -m arch detection, hardened config.json DB"
echo "      |      password extraction, and wired dynamic REBOOT_DELAY."
echo ""
echo "v13.3 | UPDATED: Session Cleanup Logic"
echo "      | FIX: Resolved voucher 'used' flag reset issue by decoupling session"
echo "      |      purging from voucher management. Now uses metric-based "
echo "      |      (time/data) criteria for session removal."
echo ""
echo "v13.2 | ADDED: Runtime RTNETLINK Immunization Shield"
echo "      | NOTE: Atomic C-Wrapper Upsert applied for stability."
echo "========================================================="

# --- ROOT PRIVILEGE CHECK ---
if [ "$EUID" -ne 0 ]; then
  echo "❌ ERROR: Please run as root (e.g., sudo ./bootoptimizer.sh)"
  exit 1
fi

# --- STEP 0: IDENTIFYING HARDWARE ---
echo "[0/14] IDENTIFYING HARDWARE..."
WAN_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
[ -z "$WAN_IFACE" ] && WAN_IFACE="eth0"
TOTAL_CORES=$(nproc)
ARCH=$(uname -m)

# --- NEW: OPI PC DETECTION GUARD ---
IS_OPI_PC=false
if [[ "$ARCH" == "armv7l" ]]; then
    IS_OPI_PC=true
    echo "  -> 🛡️ OPI PC Safe-Mode Active."
fi

echo "  -> ✅ WAN: $WAN_IFACE | Cores: $TOTAL_CORES | Arch: $ARCH"

# --- STEP 0.1: UNIVERSAL AUTO-DISCOVERY ---
echo "[0/14] PROBING SYSTEM CREDENTIALS & DATABASE..."

# ALWAYS extract the Postgres password so Step 2 never injects a blank variable
DB_PASS=$(grep -Po '(?<="password":")[^"]*' /opt/adopisoft/db/config.json 2>/dev/null || echo "adopisoft")
export PGPASSWORD="$DB_PASS"

DB_MODE="postgres"
# STRICT CHECK: Only trust the actual config file, ignore leftover .sqlite files
if grep -qi '"dbType"\s*:\s*"sqlite"' /opt/adopisoft/db/config.json 2>/dev/null; then
    DB_MODE="sqlite"
    echo "  -> Database detected: SQLite (Active in Config)"
    
    # Auto-install sqlite3 quietly so the script can manipulate it
    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "  -> Installing sqlite3 driver..."
        sudo apt-get update -y >/dev/null 2>&1
        sudo apt-get install -y sqlite3 >/dev/null 2>&1
    fi
else
    echo "  -> Database detected: PostgreSQL (Active in Config)"

    DB_NAME=$(psql -U postgres -t -A -c "SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%' AND datname != 'postgres';" 2>/dev/null | head -n 1)
    if [ -z "$DB_NAME" ]; then
         DB_NAME=$(sudo -u postgres psql -t -A -c "SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%' AND datname != 'postgres';" 2>/dev/null | head -n 1)
    fi
    echo "  -> Credentials synced. Database: ${DB_NAME:-NOT FOUND}"
fi

CURRENT_HOSTNAME=$(cat /etc/hostname | tr -d ' \n')
if ! grep -q "$CURRENT_HOSTNAME" /etc/hosts; then
    echo "127.0.0.1 $CURRENT_HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
    echo "  -> Hostname mapping fixed."
fi

# --- STEP 0.2: ROBUST WAN DETECTION ---
# Automatically finds the interface providing the default internet route
WAN_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
[ -z "$WAN_IFACE" ] && WAN_IFACE="eth0"

echo "  -> ✅ Detected WAN: $WAN_IFACE"

# --- STEP 0.3: IMMEDIATE KERNEL PRE-TUNING ---
# Allow Adopisoft to bind to the bridge IP even if it's not fully ready
sudo sysctl -w net.ipv4.ip_nonlocal_bind=1 >/dev/null 2>&1

# Stop Duplicate Address Detection (DAD) - This is the main RTNETLINK fix
sudo sysctl -w net.ipv6.conf.all.accept_dad=0 >/dev/null 2>&1
sudo sysctl -w net.ipv6.conf.default.accept_dad=0 >/dev/null 2>&1

# Prevent IPv6 route conflicts without turning off the physical signal light
sudo sysctl -w net.ipv6.conf.all.autoconf=0 >/dev/null 2>&1
sudo sysctl -w net.ipv6.conf.default.autoconf=0 >/dev/null 2>&1

# ONLY force link up if it's NOT an OPI PC
if [ "$IS_OPI_PC" = false ]; then
    # This wakes up the light on x86 and RPi/OPI 5 builds
    sudo ip link set dev "$WAN_IFACE" up >/dev/null 2>&1
fi

echo "  -> ✅ Kernel Race-Condition Shields active in memory."

# Installing haveged for Entropy fix
if ! command -v haveged &> /dev/null; then
    echo "  -> ⚡ Checking package repositories and attempting to install Haveged..."
    
    # 1. Capture the exact success/failure of the installation command
    if sudo apt-get install haveged -y >/dev/null 2>&1; then
        echo "  -> 📥 Package installed successfully. Synchronizing systemd registry..."
        
        # 2. FORCE systemd to reload and index the new service file from the disk instantly
        sudo systemctl daemon-reload
        sleep 0.5
        
        # 3. Final verification: Ensure the service configuration is active and present
        if systemctl list-unit-files | grep -q "haveged.service"; then
            echo "  -> 🎲 Configuring system userspace entropy source..."
            sudo systemctl enable haveged >/dev/null 2>&1 || true
            sudo systemctl start haveged >/dev/null 2>&1 || true
            echo "  -> ✅ Haveged entropy daemon successfully enabled and running."
        fi
    else
        # If apt-get returns an error, the package does not exist in their OS repository (Modern Kernel 5.6+)
        echo "  -> 🚀 Modern system environment detected (Package unavailable in repository)."
        echo "     Utilizing native Linux hardware jitter entropy engine (Skipping HAVEGED safely)."
    fi
fi

# --- STEP 0.4: PHYSICAL LINK GIGABIT ENFORCEMENT ---
# Prevents negotiation down to 100Mbps if the hardware supports Gigabit
if command -v ethtool >/dev/null 2>&1; then
    echo "[0.4/10] OPTIMIZING PHYSICAL LINK SPEED ($WAN_IFACE)..."
    
    # Check if the hardware physically supports 1000baseT/Full
    SUPPORTED_1000=$(ethtool "$WAN_IFACE" 2>/dev/null | grep "1000baseT/Full")
    
    if [ -n "$SUPPORTED_1000" ]; then
        echo "  -> Gigabit support detected. Locking advertisement to 1000Mbps..."
        # This tells the partner device to ONLY negotiate at 1000Mbps
        sudo ethtool -s "$WAN_IFACE" advertise 0x02f >/dev/null 2>&1
        
        # Verify the change
        NEW_SPEED=$(ethtool "$WAN_IFACE" | grep "Speed" | awk '{print $2}')
        echo "  -> Link Target: 1000Mb/s | Current Status: $NEW_SPEED"
    else
        echo "  -> ℹ️ Hardware is 10/100 limited. Skipping speed lock."
    fi
else
    echo "  -> ⚠️ ethtool not found. Skipping link optimization until Step 8.3."
fi

# --- STEP 0.5: SQLITE CONCURRENCY TUNING (CRASH FIX) ---
if [ "$DB_MODE" == "sqlite" ]; then
    echo "[0.5/10] TUNING SQLITE FOR HIGH-CONCURRENCY..."
    # 1. Enable WAL Mode (Allows concurrent reads while writing)
    # 2. Increase Busy Timeout (Wait up to 5s before erroring)
    # 3. Synchronous Normal (Speeds up writes on fast x86 SSDs)
    sqlite3 -cmd ".timeout 5000" /etc/adopisoft.sqlite <<EOF
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=5000;
PRAGMA synchronous=NORMAL;
PRAGMA wal_autocheckpoint=1000;
EOF
    echo "  -> ✅ SQLite WAL Mode & 5s Busy Timeout enabled."
fi

# --- STEP 0.6: UNIVERSAL BOOT ACCELERATOR (Active Service Detection) ---
echo "[0.6/14] Detecting active network wait-service..."
echo "Protection against longer booting time for many VLANS"

# 1. Identify the active service name
ACTIVE_WAIT_SVC=$(systemctl list-units --type=service --all | grep -oE "(systemd-networkd-wait-online|NetworkManager-wait-online)" | head -n1)

if [ -z "$ACTIVE_WAIT_SVC" ]; then
    echo "  -> ⚠️ No standard wait-service detected. Skipping boot acceleration."
else
    SVC_PATH="/lib/systemd/system/${ACTIVE_WAIT_SVC}.service"
    echo "  -> 🔍 Active Service: $ACTIVE_WAIT_SVC"

    # 2. Check for existing optimization (Idempotency)
    if grep -qE "\-\-any|\-\-timeout=15|-s -q" "$SVC_PATH"; then
        echo "  -> ✅ Status: Already optimized. Skipping."
    else
        echo "  -> 🔄 Applying 15s timeout fix to $SVC_PATH..."
        
        if [[ "$ACTIVE_WAIT_SVC" == "systemd-networkd-wait-online" ]]; then
            # Fix for systemd-networkd (x86/OPi)
            sudo sed -i 's|^ExecStart=.*|ExecStart=/lib/systemd/systemd-networkd-wait-online --any --timeout=15|' "$SVC_PATH"
        else
            # Fix for NetworkManager (RPi/Desktop)
            sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/nm-online -s -q --timeout=15|' "$SVC_PATH"
        fi
        
        sudo systemctl daemon-reload
        echo "  -> ✅ Status: Boot optimization applied successfully."
    fi
fi

# --- STEP 1.2: UNIVERSAL NETPLAN FORCED-STANDARDIZATION ---
echo "[1/14] FORCING NETPLAN HIERARCHY REPAIR (Standardized Mode)..."

# 1.2.1. AUTO-DETECT PRIMARY CONFIG
PRIMARY_NETPLAN=$(ls /etc/netplan/*.yaml 2>/dev/null | grep -vE ".bak|.revert" | head -n 1)

if [ -n "$PRIMARY_NETPLAN" ]; then
    echo "  -> Found Active Config: $(basename "$PRIMARY_NETPLAN")"
    sudo cp "$PRIMARY_NETPLAN" "${PRIMARY_NETPLAN}.revert_bak"
    
    TEMP_PLAN="/tmp/standard_netplan.yaml"
    sudo cp "$PRIMARY_NETPLAN" "$TEMP_PLAN"

    # 1.2.2. THE TOTAL PURGE
    sudo sed -i '/^[ ]*id: /d' "$TEMP_PLAN"
    sudo sed -i '/^[ ]*link: /d' "$TEMP_PLAN"
    sudo sed -i '/^[ ]*optional: true/d' "$TEMP_PLAN"

    # 1.2.3. FORCE PHYSICAL INTERFACE OPTIMIZATION
    PHYS_PORTS=$(grep -E '^[ ]*(eth|en|wlan|br)[0-9a-z]+:' "$TEMP_PLAN" | grep -v '\.' | sed 's/://' | xargs)
    for PORT in $PHYS_PORTS; do
        [[ "$PORT" =~ ^(ethernets|vlans|bridges|network|version|renderer)$ ]] && continue
        echo "  -> Standardizing Physical Port: $PORT"
        sudo sed -i "/^[ ]*$PORT:/a \      optional: true" "$TEMP_PLAN"
    done

    # 1.2.4. FORCE VLAN REPAIR & USB TRUNCATION FIX
    # Updated regex: Catches ANY alphanumeric name with a dot (fixes missing 'enx' prefixes)
    VLAN_NAMES=$(grep -E '^[ ]*[0-9a-z]+\.[0-9]+:' "$TEMP_PLAN" | grep '\.' | sed 's/://' | xargs)
    for V_NAME in $VLAN_NAMES; do
        RAW_LINK=$(echo "$V_NAME" | cut -d. -f1 | xargs)
        V_ID=$(echo "$V_NAME" | cut -d. -f2 | xargs)

        # SMART RESOLVER: Check if the link exists as-is, or if it needs the 'enx' prefix reattached
        if [[ " $PHYS_PORTS " =~ " $RAW_LINK " ]]; then
            V_LINK="$RAW_LINK"
        elif [[ " $PHYS_PORTS " =~ " enx$RAW_LINK " ]]; then
            V_LINK="enx$RAW_LINK"
        else
            V_LINK="$RAW_LINK" # Fallback
        fi

        if [[ "$V_ID" =~ ^[0-9]+$ ]]; then
            echo "  -> Standardizing VLAN: $V_NAME (Mapped Parent: $V_LINK)"
            sudo sed -i "/^[ ]*$V_NAME:/a \      id: $V_ID\n      link: $V_LINK\n      optional: true" "$TEMP_PLAN"
        fi
    done

    # 1.2.5. VERIFY, COMPARE, AND FLAG FOR DEFERRED RECOVERY
    if sudo netplan generate --config-file "$TEMP_PLAN" >/dev/null 2>&1; then
        
        if cmp -s "$TEMP_PLAN" "$PRIMARY_NETPLAN"; then
            echo "  -> ⏭️ Netplan is already perfectly optimized. Skipping network reset."
            sudo rm "$TEMP_PLAN" 2>/dev/null
        else
            sudo mv "$TEMP_PLAN" "$PRIMARY_NETPLAN"
            echo "  -> ✅ Netplan structure FORCED to standard (Flagged for deferred network apply & portal restart)."
            REQUIRE_NETWORK_RESET=true
        fi
        
    else
        echo "  -> ❌ Forced repair failed verification. Configuration remains unchanged."
        sudo rm "$TEMP_PLAN" 2>/dev/null
    fi
else
    echo "  -> ⏭️ No Netplan found. Skipping."
fi

# --- STEP 2: UNIVERSAL STARTUP & HANG SHIELD ---
echo "[2/14] STABILIZING BOOT SEQUENCE (15% & 100% Hang Fix)..."

# 2.1. Masking Network Wait Services (Prevents 100% Hang)
# This stops Ubuntu from waiting for virtual/VLAN ports that aren't ready yet.
echo "  -> Masking systemd-networkd & NetworkManager wait-services..."
sudo systemctl mask systemd-networkd-wait-online.service 2>/dev/null
sudo systemctl mask NetworkManager-wait-online.service 2>/dev/null

# --- STEP 2.2: DYNAMIC IP-WAIT (PREVENTS 15% & 60% HANG) ---
ADOPI_SERVICE=$(systemctl list-unit-files | grep -i adopisoft | awk '{print $1}' | head -n 1)

if [ -n "$ADOPI_SERVICE" ]; then
    echo "  -> Injecting Smart Wait Logic into $ADOPI_SERVICE..."
    
    # DYNAMIC TIMEOUT: Default 60s for RPi/OPi fast recovery. 360s for heavy x86 VLAN loading.
    WAIT_TIMEOUT=60
    if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
        WAIT_TIMEOUT=340
    fi

    # Force-Disable the physical coin acceptor hardware check for x86 stability
    # Scoped sed fix: Only replace 'enabled: true' if it occurs within 3 lines of a coin/bill acceptor definition
    sudo sed -i -E '/"(coin_acceptor|bill_validator|hardware)"/,/}/ { s/"enabled"[[:space:]]*:[[:space:]]*true/"enabled": false/; }' /opt/adopisoft/db/config.json 2>/dev/null
    
    sudo mkdir -p "/etc/systemd/system/${ADOPI_SERVICE}.d"
    cat <<EOF | sudo tee "/etc/systemd/system/${ADOPI_SERVICE}.d/stability.conf" > /dev/null
[Service]
# Wait for WAN IP before starting Adopisoft to prevent database timeouts
ExecStartPre=-/bin/bash -c 'timeout $WAIT_TIMEOUT sh -c "until ip -4 addr show dev $WAN_IFACE | grep -q inet; do sleep 1; done"'
Environment="PGPASSWORD=$DB_PASS"
EOF

    sudo systemctl daemon-reload
    echo "     ✅ Smart Wait (${WAIT_TIMEOUT}s Max) & Hardware Shield Active."
else
    echo "     ⚠️ Adopisoft service not detected. Skipping Service Patch."
fi

# 2.3. Applying Hardware Interface Delay (The 'Cable Plug' Simulation)
# This prevents race conditions on RPi, OPi, and x86 physical ports.
IFACE_CONF="/etc/network/interfaces"
if [ -f "$IFACE_CONF" ]; then
    echo "  -> Patching hardware interfaces for physical stability..."
    if ! grep -q "pre-up sleep 5" "$IFACE_CONF"; then
        # Add a 5s delay to the physical WAN and any associated VLANs
        sudo sed -i "/iface $WAN_IFACE/a \    pre-up sleep 5" "$IFACE_CONF" 2>/dev/null
        sudo sed -i "/iface ${WAN_IFACE}.vlan/a \    pre-up sleep 5" "$IFACE_CONF" 2>/dev/null
        echo "     ✅ 5s Hardware delay added to $WAN_IFACE."
    else
        echo "     ✅ Hardware delay already present."
    fi
else
    echo "     ℹ️ /etc/network/interfaces not found (Normal for Netplan). Using Service Wait only."
fi

echo "  -> ✅ Startup Stabilization Completed Successfully."

# --- STEP 3: SMART FIREWALL & AGGRESSIVE DNS ---
echo "[3/14] CONFIGURING FIREWALL & DNS TIMEOUTS..."

# Universal auto-detect for the Default Gateway
DETECTED_GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)

if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
    sudo update-alternatives --set iptables /usr/sbin/iptables-nft 2>/dev/null
    sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-nft 2>/dev/null
    sudo ufw disable 2>/dev/null && sudo systemctl disable ufw 2>/dev/null
fi

echo "[3/14] FORCING DNS HIERARCHY (8.8.8.8 -> 1.1.1.1 -> Gateway IP)..."

# 3.1. DETECT BOTH: Your Local IP and the Router's IP
WAN_IP=$(ip -4 addr show dev "$WAN_IFACE" | grep -Po 'inet \K[\d.]+')
GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -n 1) # <--- Correct Gateway detection

# 3.2. BYPASS LOCKS
# AdoPiSoft Boot Optimizer with Immutable DNS Lock - Flarego Edition

# --- OPI One Stability Adjustment ---
ARCH=$(uname -m)
if [[ "$ARCH" == "armv7l" ]]; then
    sleep 15
else
    sleep 10
fi

echo "Running Boot Optimization Diagnostics..."

# ==============================================================================
# --- SYSTEM PERFORMANCE OPTIMIZATIONS ---
# ==============================================================================
# Disable swap to reduce I/O bottlenecks on SD Cards
sudo swapoff -a

# Optimize network socket bucket sizes
sudo sysctl -w net.core.somaxconn=1024
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=1024

# Set scaling governor to performance for faster core execution
if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then
    echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
fi

# ==============================================================================
# --- CRITICAL: FIX RESOLV.CONF & LOCK LOCAL DNS PRECEDENCE ---
# ==============================================================================
RESOLV_CONF="/etc/resolv.conf"

echo "Optimizing DNS configuration engine..."

# Force remove any existing symlinks or stubborn network-manager locks
sudo chattr -i /etc/resolv.conf 2>/dev/null
sudo rm -f /etc/resolv.conf 2>/dev/null

# 3.3. RECREATE RESOLV.CONF USING THE GATEWAY
{
  echo "nameserver 127.0.0.1"         # Forcing local loopback precedence to prevent portal.now upstream leakage
  echo "nameserver 8.8.8.8"           # Secondary: Google          
  echo "nameserver 1.1.1.1"           # 3rd Entry: Cloudflare
  
  # Inject gateway dynamic tiering if variable is present
  if [ -n "$GATEWAY_IP" ]; then
    echo "nameserver $GATEWAY_IP"     # 4th Entry: Gateway (Correct for DNS)
  else
    echo "nameserver 9.9.9.9"         # Fallback if Gateway is missing
  fi
  
  echo "options timeout:1 attempts:1"
} | sudo tee /etc/resolv.conf > /dev/null

# Apply the immutable system flag to write-lock the file permanently
# This blocks NetworkManager, systemd-resolved, and dhcpcd from reverting our rules.
sudo chattr +i "$RESOLV_CONF" 2>/dev/null
    
echo "  -> ✅ /etc/resolv.conf optimized and locked to localhost."

# ==============================================================================
# --- SERVICES REFRESH TIE-IN ---
# ==============================================================================
# Flush kernel cache allocations
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
 
echo "✅ Boot DNS Optimization Routine Successfully Finalized."

# --- STEP 3.4: Firewall DNS Lag Fix ---
echo "[3.4/14] Mapping Walled Garden IPs to /etc/hosts..."
if grep -q "PisoWiFi Walled Garden" /etc/hosts; then
    echo "⏭️  Hosts already optimized. Skipping."
else
    cat <<EOF | sudo tee -a /etc/hosts > /dev/null

# PisoWiFi Walled Garden Optimization
31.13.71.36    api.gcash.com m.gcash.app gcash.app www.gcash.com
18.140.194.9   pg.maya.ph payments.maya.ph pg.paymaya.com payments.paymaya.com
110.173.128.0  os.alipayobjects.com render.alipay.com m.alipay.com
13.226.210.20  api.paymongo.com checkout.paymongo.com paymongo.com
3.1.181.233    api.xendit.co checkout.xendit.co xendit.co
142.250.190.46 gstatic.com googleapis.com
EOF
    echo "✅ Added IP mappings."
fi

# --- STEP 3.5: Increase Connection Tracking for high-concurrency (up to 1 million connections)
sudo sysctl -w net.netfilter.nf_conntrack_max=1048576 2>/dev/null
sudo sysctl -w net.nf_conntrack_max=1048576 2>/dev/null
sudo sysctl -w fs.file-max=2097152 2>/dev/null
sudo sysctl -w net.core.somaxconn=4096 2>/dev/null
sudo sysctl -w net.core.netdev_max_backlog=5000 2>/dev/null

# --- STEP 4: GHOST IPTABLES WRAPPER (DNS SHIELD & UI FIX) ---
echo "     ✅ Enabling Iptable wrapper for the first 2 minutes to make it passthrough 30% and 40%"
# This uses time dalay for 240 seconds
# For the first 240 seconds of booting, it forces 
# the lag-free -n flag so your system flies past 30% and 40%.
# After 240 seconds, the wrapper effectively turns itself off and acts as a 100% 
# transparent passthrough to the real iptables. 
echo " [4/14] DEPLOYING IPTABLES DNS SHIELD..."
echo " -- Fixing Multiple VLAN Problem (30% Hang) & Active Users Counter -- "

# Removed the x86_64 check so this applies to Raspberry Pi and Orange Pi as well
# DYNAMIC NATIVE INTERFACE DETECTION
NATIVE_IPTABLES=""
for path in /usr/sbin/iptables /sbin/iptables /usr/bin/iptables /bin/iptables; do
    if [ -x "$path" ] && [ "$path" != "/usr/local/sbin/iptables" ]; then
        NATIVE_IPTABLES="$path"
        break
    fi
done

if [ -z "$NATIVE_IPTABLES" ]; then
    NATIVE_IPTABLES=$(command -v iptables 2>/dev/null | grep -v "/usr/local/sbin/iptables" | head -n1)
fi
[ -z "$NATIVE_IPTABLES" ] && NATIVE_IPTABLES="/usr/sbin/iptables"

# WRITE TEMPLATE WRAPPER FILE WITH PLACEHOLDER
sudo tee /usr/local/sbin/iptables > /dev/null << 'EOF'
#!/bin/bash
REAL_IPTABLES="TARGET_PATH_PLACEHOLDER"
# Grab the system uptime in seconds
UPTIME=$(cut -d. -f1 /proc/uptime)

# PHASE 1: Protect the boot sequence (First 1.5 minutes / 240 seconds)
# Forces the '-n' flag to prevent DNS reverse-lookup lag causing the 30% hang.
if [ "$UPTIME" -lt 240 ]; then
    if [[ " $@ " == *" -L "* ]] || [[ " $@ " == *" --list "* ]]; then
        if [[ " $@ " != *" -n "* ]] && [[ " $@ " != *" --numeric "* ]]; then
            exec -a "iptables" "$REAL_IPTABLES" "$@" -n
        fi
    fi
fi

# PHASE 2: Transparent Passthrough (After 2 minutes)
# Passes the exact, unedited native output to the Adopisoft Dashboard 
# so the "Connected to WiFi" parser successfully reads active users.
exec -a "iptables" "$REAL_IPTABLES" "$@"
EOF

# INJECT REAL DETECTED PATH
sudo sed -i "s|REAL_IPTABLES=\"TARGET_PATH_PLACEHOLDER\"|REAL_IPTABLES=\"$NATIVE_IPTABLES\"|g" /usr/local/sbin/iptables
sudo chmod +x /usr/local/sbin/iptables

# --- STEP 5: CPU PERFORMANCE MODE ---
echo "[5/14] LOCKING CPU TO PERFORMANCE GOVERNOR (REBOOT PERSISTENT)..."

# 5.1. Install the utility first to ensure the config file path exists
sudo apt-get install -y cpufrequtils > /dev/null 2>&1

# 5.2. Write to the system config so it stays 'performance' after a reboot
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils > /dev/null

# 5.3. Apply the setting immediately to all cores
sudo cpufreq-set -r -g performance 2>/dev/null || \
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

echo "  -> ✅ CPU Governor locked at maximum performance (Persistent)."

# 5.4. Increase System-wide File Descriptors and Increase Network Backlog Queue (Prevents "Portal not showing")
echo "     ✅ Support for morethan 500 simultaneous active users  "
cat <<EOF | sudo tee /etc/sysctl.d/99-adopisoft-concurrency.conf > /dev/null
# Adopisoft 700+ Concurrent User Optimization
net.netfilter.nf_conntrack_max=1048576
net.nf_conntrack_max=1048576
fs.file-max=2097152
net.core.somaxconn=4096
net.core.netdev_max_backlog=5000
# Adopisoft Tentative IP Lockout Fix (100% Boot Hang)
net.ipv4.ip_nonlocal_bind=1
net.ipv6.ip_nonlocal_bind=1
net.ipv6.conf.all.accept_dad=0
net.ipv6.conf.default.accept_dad=0
EOF
# 5.5. Increase limits for the root user and services
cat <<EOF | sudo tee /etc/security/limits.d/99-adopisoft.conf > /dev/null
# Adopisoft Socket Exhaustion Fix
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

# Reload system settings to confirm
sudo sysctl --system >/dev/null 2>&1
echo "     ✅ Concurrency limits expanded and safely locked."

# --- STEP 6: THE 10,000 USER ARMOR (SMART-ARMED TC WRAPPER) ---

# 1. ROBUST PATH DISCOVERY
# We force check /sbin/tc and /usr/sbin/tc specifically
if [ -f "/sbin/tc" ]; then TARGET_TC="/sbin/tc"; else TARGET_TC="/usr/sbin/tc"; fi

# 2. STEP 6 CLEANUP: Purge legacy Bash wrapper
if grep -q "#!/bin/bash" "$TARGET_TC" 2>/dev/null; then
    echo "  -> 🧹 Found legacy bash wrapper. Restoring original..."
    # If the .original exists, restore it. If not, we are in a bad state.
    if [ -f "${TARGET_TC}.original" ]; then
        sudo mv "${TARGET_TC}.original" "$TARGET_TC"
        sudo chmod +x "$TARGET_TC"
    fi
fi

echo "[6/14] DEPLOYING SMART-ARMED TC WRAPPER..."
TC_PATH=$(which tc)

# 1. FIXED SIGNATURE CHECK: Match the exact string embedded in the C code below
STR_CHECK=$(strings "$TC_PATH" 2>/dev/null | grep -q "SmartArmedTCWrapper_Active"; echo $?)
FILE_CHECK=0
[ -f "${TC_PATH}.original" ] || [ -f "/usr/sbin/tc.original" ] || [ -f "/sbin/tc.original" ] && FILE_CHECK=1

if [ "$STR_CHECK" -ne 0 ] && [ "$FILE_CHECK" -eq 0 ]; then
    # 2. GENERATE C SOURCE: Do this BEFORE touching the live system binary
    cat << 'WRAP_EOF' > /tmp/tc_wrapper.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Embedded signature for idempotent binary detection in bash
const char *wrapper_sig = "SmartArmedTCWrapper_Active";

int main(int argc, char *argv[]) {
    char *orig = "/sbin/tc.original";
    if (access("/usr/sbin/tc.original", F_OK) == 0) { orig = "/usr/sbin/tc.original"; }
    
    // SMART GATE: Only arm if the /tmp/armor_on flag exists
    int arm_armor = (access("/tmp/armor_on", F_OK) == 0);

    char **new_argv = malloc((argc + 1) * sizeof(char *));
    new_argv[0] = orig;

    for (int i = 1; i < argc; i++) {
        // IMMUNIZATION SHIELD: Auto-convert 'add' to 'replace' to permanently prevent 'RTNETLINK answers: File exists' errors
        if (strcmp(argv[i], "add") == 0) {
            new_argv[i] = strdup("replace");
        } else {
            new_argv[i] = strdup(argv[i]);
        }

        if (arm_armor) {
            char *col = strchr(argv[i], ':');
            if (col != NULL && strchr(col + 1, ':') == NULL) {
                // FIXED HEX PARSING: Use strtol with base 16 instead of atoi
                int val = (int)strtol(col + 1, NULL, 16);
                if (val >= 10000) {
                    int major_len = col - argv[i];
                    char new_arg[64];
                    snprintf(new_arg, sizeof(new_arg), "%.*s:%x", major_len, argv[i], 40960 + (val % 24575));
                    free(new_argv[i]); 
                    new_argv[i] = strdup(new_arg);
                }
            }
        }
    }
    new_argv[argc] = NULL; 
    execv(orig, new_argv); 
    return 1;
}
WRAP_EOF
    
    # 3. COMPILE FIRST: Build to a temporary binary to ensure compilation succeeds
    sudo gcc -O2 /tmp/tc_wrapper.c -o /tmp/tc_wrapper_bin 2>/dev/null
    
    # 4. SAFE SWAP: Only alter system files if the temporary binary compiled successfully
    if [ -f /tmp/tc_wrapper_bin ]; then
        sudo systemctl stop adopisoft 2>/dev/null
        [ ! -f "${TC_PATH}.original" ] && sudo mv "$TC_PATH" "${TC_PATH}.original"
        sudo mv /tmp/tc_wrapper_bin "$TC_PATH" && sudo chmod +x "$TC_PATH"
        sudo systemctl start adopisoft 2>/dev/null
        echo "  -> ✅ Smart-Armed Armor installed (Standby Mode Active)."
    else
        echo "  -> ❌ ERROR: Failed to compile TC Wrapper (is gcc installed?). System binary unchanged."
    fi
    
    rm -f /tmp/tc_wrapper.c
else
    echo "  -> ⚡ Armor already present. Skipping."
fi

# --- STEP 7: OPTIMIZING PPPOE SERVER & NAT ROUTING ---
echo "[7/14] Optimizing PPPoE Server & NAT Routing..."

# Check if PPPoE server components actually exist
if [ ! -f "/etc/ppp/pppoe-config.ini" ] && [ ! -d "/opt/adopisoft/plugins/pppoe" ] && [ ! -d "/opt/adopisoft/plugins/pppoe-server" ]; then
    echo "      -> ⏭️ PPPoE Server plugin not installed/used on this machine. Skipping routing overrides."
else
    echo "      -> PPPoE Server validated. Checking current configuration..."

    # DEPENDENCY CHECK: Ask the package manager directly if tools exist
    if ! command -v pppoe-server >/dev/null 2>&1 || ! dpkg -s iptables-persistent >/dev/null 2>&1; then
        echo "      -> ⚠️ Required routing packages missing! Installing tools via apt..."
        
        # FIX 2: Silent Package Manager Lockouts (Wait Loop)
		while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
            echo "      -> ⏳ Waiting for apt locks to clear..."
            sleep 5
        done

        sudo debconf-set-selections <<< "iptables-persistent iptables-persistent/autosave_v4 boolean true"
        sudo debconf-set-selections <<< "iptables-persistent iptables-persistent/autosave_v6 boolean true"
        
        sudo apt-get update -y >/dev/null 2>&1
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            -q pppoe ppp iptables-persistent >/dev/null 2>&1
    fi

    # MULTI-PATH DETECTION: Works on Orange Pi 5 and standard Raspberry Pi/Ubuntu setups
    if [ -d "/opt/adopisoft/plugins/pppoe-server" ] || [ -d "/opt/adopisoft/plugins/pppoe" ] || command -v pppoe-server >/dev/null 2>&1; then
        PPP_FILE="/etc/ppp/pppoe-server-options"
        [ ! -f "$PPP_FILE" ] && PPP_FILE="/etc/ppp/options"
        
        CONFIG_INI="/etc/ppp/pppoe-config.ini"
        PPPOE_CONF="/etc/ppp/pppoe.conf"

        sudo touch "$PPP_FILE"

        # DYNAMIC CHECK: Extract user's selected dashboard interface if available
        CHOSEN_IFACE=""
        if [ -f "$CONFIG_INI" ]; then
            CHOSEN_IFACE=$(grep -E "^interface=" "$CONFIG_INI" | cut -d'=' -f2 | tr -d '\r\n ')
        fi

        # ==============================================================================
        # 🛠️ ADVANCED PPPOE INTERFACE TROUBLESHOOTING & DIAGNOSTICS ENGINE
        # ==============================================================================
        echo "      -> 🔍 Running PPPoE Interface Diagnostics..."
        echo "         [i] Dashboard Target Interface: [$CHOSEN_IFACE]"
        
        if [ -z "$CHOSEN_IFACE" ]; then
            echo "         ❌ ERROR: 'interface=' parameter is missing or empty in pppoe-config.ini!"
        elif [[ "$CHOSEN_IFACE" =~ ^vlan[0-9]+ ]]; then
            VLAN_NUM=$(echo "$CHOSEN_IFACE" | grep -o -E "[0-9]+")
            echo "         ⚠️ WARNING: Descriptive name [$CHOSEN_IFACE] found instead of a Linux kernel interface."
            
            # FIX 4: Robust VLAN Regex (Handles complex PCIe names like enp2s0f1.100)
            REAL_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1 | xargs -n1 | grep -E "\.${VLAN_NUM}$" | head -n 1)
            
            if [ -z "$REAL_IFACE" ]; then
                REAL_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E "(br-vlan${VLAN_NUM}|br-${CHOSEN_IFACE})" | head -n 1)
            fi
            if [ -n "$REAL_IFACE" ]; then
                echo "         ✅ Auto-Mapped: $CHOSEN_IFACE -> Using Real Link [$REAL_IFACE]"
                CHOSEN_IFACE="$REAL_IFACE"
            else
                echo "         ❌ DIAGNOSTIC FAILURE: No active network adapter matches VLAN ID $VLAN_NUM!"
            fi
        else
            if ip link show "$CHOSEN_IFACE" >/dev/null 2>&1; then
                LINK_STATE=$(ip link show "$CHOSEN_IFACE" | grep -o -E "state [A-Z]+")
                echo "         ✅ Interface [$CHOSEN_IFACE] exists in network stack ($LINK_STATE)."
            else
                echo "         ❌ DIAGNOSTIC FAILURE: Interface [$CHOSEN_IFACE] does NOT exist in Linux!"
                USB_MATCH=$(ip -o link show | awk -F': ' '{print $2}' | grep -E "^enx" | cut -d'@' -f1 | head -n 1)
                if [ -n "$USB_MATCH" ]; then
                    echo "            💡 Suggestion: Found a active USB-to-LAN adapter named [$USB_MATCH]."
                    echo "               Please update your dashboard setting to match this device string."
                fi
            fi
        fi
        # ==============================================================================

        # Determine if pppoe.conf needs an active interface sync update
        NEED_SYNC=false
        if [ -n "$CHOSEN_IFACE" ] && [ -f "$PPPOE_CONF" ] && ip link show "$CHOSEN_IFACE" >/dev/null 2>&1; then
            if ! grep -q "^ETH='$CHOSEN_IFACE'" "$PPPOE_CONF"; then
                NEED_SYNC=true
            fi
        fi

        # FIX 1: Dynamic WAN re-evaluation to escape the fast-boot 'eth0' trap
        WAN_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        if [ -z "$WAN_IFACE" ]; then
            WAN_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1 | xargs -n1 | grep -E '^(en|eth)' | grep -v 'vlan' | head -n1)
        fi
        [ -z "$WAN_IFACE" ] && WAN_IFACE="eth0"

        # SMART CHECK: Check if the fixes are already written into your active ruleset
        if grep -q "lcp-echo-interval 10" "$PPP_FILE" 2>/dev/null && \
           sudo iptables -t nat -C POSTROUTING -o "$WAN_IFACE" -j MASQUERADE >/dev/null 2>&1 && \
           [ "$NEED_SYNC" = false ]; then
            echo "      -> ⏭️ PPPoE rules, interface mapping, and NAT routing are already optimized. Skipping restart."
        else
            # 1. DYNAMIC INTERFACE ALIGNMENT SCREEN LOGGING (RESTORED DOCUMENTATION)
            if [ "$NEED_SYNC" = true ]; then
                echo "      -> 📝 Syncing Dashboard PPPoE Interface ($CHOSEN_IFACE) to underlying pppoe.conf map..."
                sudo sed -i "s/^ETH=.*/ETH='$CHOSEN_IFACE'/" "$PPPOE_CONF"
            elif [ -z "$CHOSEN_IFACE" ]; then
                echo "      -> ⚠️ Warning: pppoe-config.ini missing. Preserving current adapter configurations."
            else
                echo "      -> 📝 Interface alignment verified: pppoe.conf is correctly mapped to active interface ($CHOSEN_IFACE)."
            fi

            echo "      -> Patching LCP Echo Rules (Ghost Session Fix)..."
            sudo sed -i '/lcp-echo-interval/d' "$PPP_FILE" 2>/dev/null
            sudo sed -i '/lcp-echo-failure/d' "$PPP_FILE" 2>/dev/null
            echo "lcp-echo-interval 10" | sudo tee -a "$PPP_FILE" > /dev/null
            echo "lcp-echo-failure 3" | sudo tee -a "$PPP_FILE" > /dev/null

            echo "      -> Enabling Kernel IP Forwarding..."
            sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
            if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
                echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
            fi
            sudo sysctl -p > /dev/null

            echo "      -> Applying NAT Masquerade for WAN ($WAN_IFACE)..."
            if ! sudo iptables -t nat -C POSTROUTING -o "$WAN_IFACE" -j MASQUERADE >/dev/null 2>&1; then
                sudo iptables -t nat -A POSTROUTING -o "$WAN_IFACE" -j MASQUERADE
            fi
            
            if ! sudo iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; then
                sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
            fi

            echo "      -> Saving active routing configuration permanently..."
            sudo netfilter-persistent save >/dev/null 2>&1

            echo "      -> Restarting PPPoE Service to apply new rules..."
            sudo killall pppoe-server 2>/dev/null || true
            
            # FIX 3: Sleep delays added to prevent service race conditions
            sleep 1
            
            # Let Adopisoft natively manage the daemon so IP pools are injected
            if [ -n "$CHOSEN_IFACE" ] && ip link show "$CHOSEN_IFACE" >/dev/null 2>&1; then
                # We do NOT manually spawn pppoe-server here. We trigger the native services.
                sudo systemctl restart pppoe-server 2>/dev/null || true
                sleep 2
                pm2 restart pppoe-server 2>/dev/null || true
                
                # Restart the main manager to ensure the database hooks inject the IPs
                NEEDS_REBOOT=true
                
                echo "      -> ✅ PPPoE & Routing optimized and rule stability locked."
            else
                echo "      -> ❌ ABORTED: PPPoE Server daemon could not start due to an invalid interface name."
            fi
        fi
    else
        echo "      -> ⏭️ PPPoE Server engine not ready. Skipping this step."
    fi
fi

# --- STEP 8: CPU LOAD IMBALANCE FIX ---
echo "[8/14] CPU LOAD IMBALANCE FIX"

# ------ 8.1. SELF-CLEANING (FIX WINDOWS ERRORS) ---
if grep -q $'\r' "$0"; then
    echo "[FIX] Windows line endings detected. Cleaning script..."
    sed -i 's/\r$//' "$0"
    exec bash "$0" "$@"
fi

# ------ 8.2. DISCOVERY & HARDWARE IDENTIFICATION ---
TOTAL_CORES=$(nproc)
ARCH=$(uname -m)
BOARD="Generic/MiniPC"

if grep -qi "raspberry" /proc/cpuinfo 2>/dev/null; then BOARD="Raspberry Pi"; fi
if grep -qi "orange" /proc/cpuinfo 2>/dev/null; then BOARD="Orange Pi"; fi

echo "------------------------------------------------"
echo "Starting Universal Adopisoft Optimizer"
echo "Board: $BOARD | Cores: $TOTAL_CORES | Arch: $ARCH"
echo "------------------------------------------------"

# ------ 8.3. SMART INSTALL TOOLS (RERUN-SAFE & ARCH-AWARE) ---
echo "[SETUP] Checking system tools..."
# FIX: Moved zip and unzip to the universal list for ALL boards
REQUIRED_PKGS="irqbalance ethtool pciutils cpufrequtils rfkill zip unzip"

if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
    REQUIRED_PKGS="$REQUIRED_PKGS build-essential dkms git"
fi

# FIX: Actually calculate which packages are missing before trying to install them
MISSING_PKGS=""
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "  -> Downloading missing packages ($ARCH): $MISSING_PKGS"
    
    # 1. BULLETPROOF LOCK GUARD
    echo "  -> Checking for system deployment locks..."
	while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        echo "     [WAIT] Another package manager is running. Retrying in 5s..."
        sleep 5
    done

    # 2. BULLETPROOF RETRY LOOP
    MAX_ATTEMPTS=3
    ATTEMPT=1
    SUCCESS=false

    while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        echo "  -> Package installation attempt $ATTEMPT of $MAX_ATTEMPTS..."
        
        if sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y $MISSING_PKGS >/dev/null 2>&1; then
            SUCCESS=true
            break
        else
            echo "  -> ⚠️ Attempt $ATTEMPT failed. Network may be initializing or repository congested."
            ((ATTEMPT++))
            [ $ATTEMPT -le $MAX_ATTEMPTS ] && sleep 5
        fi
    done

    if [ "$SUCCESS" = true ]; then
        echo "  -> ✅ Installation complete."
    else
        echo "  -> ❌ CRITICAL ERROR: Failed to install required packages after $MAX_ATTEMPTS attempts."
        NEEDS_REBOOT=true
    fi
else
    echo "  -> ✅ All required system tools are already installed."
fi

# ------ 8.4. REALTEK 2.5G DRIVER (FIXED IDEMPOTENCY) ---
DRIVER_UPDATED=false
if [[ "$ARCH" == "x86_64" ]] && command -v lspci &> /dev/null; then
    DEVICE_ID=$(lspci -nn | grep -i ethernet | grep "8125")
    if [[ -n "$DEVICE_ID" ]]; then
        FIRST_IFACE=$(ls /sys/class/net | grep -E 'eth|enp|eno' | head -n 1)
        CURRENT_DRIVER=$(ethtool -i "$FIRST_IFACE" 2>/dev/null | grep driver | awk '{print $2}')
        if [[ "$CURRENT_DRIVER" != "r8125" ]]; then
            echo "[MATCH] 2.5G Card found. Upgrading driver to r8125..."
            rm -rf /tmp/r8125
            git clone --depth 1 https://github.com/awesometic/realtek-r8125-dkms.git /tmp/r8125
            cd /tmp/r8125 && sudo ./dkms-install.sh
            echo "blacklist r8169" | sudo tee /etc/modprobe.d/blacklist-r8169.conf > /dev/null
            sudo update-initramfs -u > /dev/null
            DRIVER_UPDATED=true
            NEEDS_REBOOT=true
        fi
    fi
fi

# ------ 8.5. CPU PERFORMANCE GOVERNOR ---
echo "[CPU] Locking all $TOTAL_CORES cores to PERFORMANCE mode..."
sudo cpufreq-set -r -g performance 2>/dev/null || \
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

# ------ 8.6. INTERRUPT BALANCING ---
if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
    echo "[SERVICE] Enabling IRQ Balancing for Mini PC..."
    sudo systemctl unmask irqbalance.service 2>/dev/null
    sudo systemctl enable --now irqbalance 2>/dev/null
    if ! systemctl is-active --quiet irqbalance; then
        sudo irqbalance --oneshot 2>/dev/null
    fi
else
    echo "[SERVICE] Skipping IRQ Balancing (Protects built-in Ethernet on $BOARD)"
    sudo systemctl disable irqbalance.service --now 2>/dev/null
    sudo killall irqbalance 2>/dev/null
fi

# ------ 8.7. NETWORK QUEUE OPTIMIZATION ---
INTERFACES=$(ls /sys/class/net | grep -E 'eth|enp|eno|enx')
for IFACE in $INTERFACES; do
    echo "[CONFIG] Tuning Port: $IFACE"
    QUEUES=$(( TOTAL_CORES > 8 ? 8 : TOTAL_CORES ))
    sudo ethtool -L "$IFACE" combined "$QUEUES" 2>/dev/null || \
    sudo ethtool -L "$IFACE" rx "$QUEUES" tx "$QUEUES" 2>/dev/null || \
    echo "  -> Note: Static hardware queues (Normal for $BOARD)."
done

echo "----------------------------------------------------------"
echo "SUCCESS: Optimization Complete."
[ "$DRIVER_UPDATED" = true ] && echo "!!! REBOOT REQUIRED for new 2.5G Driver !!!" || echo "Changes are now live."
echo "  -> ✅ Step 8: Hardware core load optimizations applied. "
echo "----------------------------------------------------------"

# --- STEP 9: CRONTAB & LOG SCRUBBING (Standard Relational Patch Integrated) ---
echo "[9/14] Configuring Maintenance & Logs..."
sudo systemctl disable apt-daily.timer apt-daily-upgrade.timer --now 2>/dev/null

# 9.1. IMMEDIATE EXECUTION LOGS TRUNCATION
sudo journalctl --vacuum-time=2d
LOGS_INIT="/var/log/syslog /var/log/dmesg /var/log/pppoe-server-log /var/log/auth.log /var/log/kern.log /var/log/lastlog /var/log/wtmp /var/log/apt/eipp.log.xz /var/log/apt/dataplicity.log /var/log/apt/alternative.log /var/log/nginx/access.log /var/log/armbian-hardware-monitor.log /var/log/supervisor/supervisor.log /var/log/postgresql/postgresql-16-main.log /var/log/adopisoft_maintenance.log /var/log/supervisor/supervisord.log /var/log/alternatives.log"
for f in $LOGS_INIT; do [ -f "$f" ] && sudo truncate -s 0 "$f" 2>/dev/null; done

# 9.2. GENERATE DAILY MAINTENANCE SCRIPT (Standard Relational Fix)
DAILY_SCRIPT="/usr/local/bin/flarewifi-daily.sh"
cat << 'EOF' | sudo tee "$DAILY_SCRIPT" > /dev/null
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOG_FILE="/var/log/adopisoft_maintenance.log"

# =================================================================
# CORE MAINTENANCE OPERATIONS (Executes at exactly 3:40 AM)
# =================================================================
DB_MODE="postgres"
# STRICT CHECK: Trust ONLY the config file. Ignore leftover ghost files.
if grep -qi '"dbType"\s*:\s*"sqlite"' /opt/adopisoft/db/config.json 2>/dev/null; then
    DB_MODE="sqlite"
fi

DAY_OF_WEEK=$(date +%u)

if [ "$DB_MODE" == "sqlite" ]; then
    ROW_COUNT=$(sqlite3 -cmd ".timeout 5000" /etc/adopisoft.sqlite "SELECT COUNT(*) FROM sessions;" 2>/dev/null)
    [ -z "$ROW_COUNT" ] && ROW_COUNT="0"
    EXECUTE_DELETE=false

    if [ "$DAY_OF_WEEK" -eq 7 ]; then
        echo "[$(date)] SUNDAY OVERRIDE: Forcing session cleanup ($ROW_COUNT sessions) [SQLite]" >> $LOG_FILE
        EXECUTE_DELETE=true
        rm -f /tmp/armor_on
    else
        if [ "$ROW_COUNT" -ge 8000 ]; then
            touch /tmp/armor_on
            echo "[$(date)] WEEKDAY ALERT: Sessions at $ROW_COUNT -> Armor Armed [SQLite]" >> $LOG_FILE
        else
            rm -f /tmp/armor_on
        fi

        if [ "$ROW_COUNT" -ge 10000 ]; then
            echo "[$(date)] WEEKDAY CRITICAL CEILING: Purging sessions ($ROW_COUNT sessions) [SQLite]" >> $LOG_FILE
            EXECUTE_DELETE=true
        fi
    fi

    if [ "$EXECUTE_DELETE" = true ]; then
        # STANDARD RELATIONAL FIX: Purge Consumed/Expired sessions while allowing NULLs (Coinslot/Manual) and protecting Activated Vouchers
        sqlite3 -cmd ".timeout 5000" /etc/adopisoft.sqlite "DELETE FROM sessions WHERE (expiration_date < datetime('now') OR (time_seconds > 0 AND running_time_seconds >= time_seconds) OR (data_mb > 0 AND data_consumption_mb >= data_mb)) AND (voucher_code IS NULL OR voucher_code = '' OR voucher_code NOT IN (SELECT code FROM vouchers WHERE activated_at IS NOT NULL OR session_id IS NOT NULL));"
        sqlite3 -cmd ".timeout 5000" /etc/adopisoft.sqlite "VACUUM;"
        echo "[$(date)] SESSION CLEANUP COMPLETE [SQLite]" >> $LOG_FILE
        
        # Smart Restart: Only resets the cache if a deletion was triggered
        sudo systemctl restart adopisoft
    fi
else
    DB_PASS=$(grep -Po '(?<="password":")[^"]*' /opt/adopisoft/db/config.json 2>/dev/null || echo "adopisoft")
    export PGPASSWORD="$DB_PASS"
    
    PSQL="sudo -u postgres /usr/bin/psql"
    DB_NAME=$($PSQL -t -A -c "SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%' AND datname != 'postgres';" 2>/dev/null | head -n 1)
    
    if [ -n "$DB_NAME" ]; then
        ROW_COUNT=$($PSQL -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM sessions;" 2>/dev/null)
        [ -z "$ROW_COUNT" ] && ROW_COUNT="0"
        EXECUTE_DELETE=false

        if [ "$DAY_OF_WEEK" -eq 7 ]; then
            echo "[$(date)] SUNDAY OVERRIDE: Forcing session cleanup ($ROW_COUNT sessions) [PG]" >> $LOG_FILE
            EXECUTE_DELETE=true
            rm -f /tmp/armor_on
        else
            if [ "$ROW_COUNT" -ge 8000 ]; then
                touch /tmp/armor_on
                echo "[$(date)] WEEKDAY ALERT: Sessions at $ROW_COUNT -> Armor Armed [PG]" >> $LOG_FILE
            else
                rm -f /tmp/armor_on
            fi

            if [ "$ROW_COUNT" -ge 10000 ]; then
                echo "[$(date)] WEEKDAY CRITICAL CEILING: Purging sessions ($ROW_COUNT sessions) [PG]" >> $LOG_FILE
                EXECUTE_DELETE=true
            fi
        fi

        if [ "$EXECUTE_DELETE" = true ]; then
            # STANDARD RELATIONAL FIX: Purge Consumed/Expired sessions while allowing NULLs (Coinslot/Manual) and protecting Activated Vouchers
            $PSQL -d "$DB_NAME" -c "DELETE FROM sessions WHERE (expiration_date < NOW() OR (time_seconds > 0 AND running_time_seconds >= time_seconds) OR (data_mb > 0 AND data_consumption_mb >= data_mb)) AND (voucher_code IS NULL OR voucher_code = '' OR voucher_code NOT IN (SELECT code FROM vouchers WHERE activated_at IS NOT NULL OR session_id IS NOT NULL));"
            $PSQL -d "$DB_NAME" -c "VACUUM ANALYZE sessions;"
            echo "[$(date)] SESSION CLEANUP COMPLETE [PG]" >> $LOG_FILE
            
            # Smart Restart: Only resets the cache if a deletion was triggered
            sudo systemctl restart adopisoft
        fi
    fi
fi
echo "  -> Running The "Surgical" Cleanup Strategy..." | tee -a "$LOG_FILE"
(
# 1. Define the network interface
INTERFACE="br0"

# 2. Get the list of all currently active session IDs from PostgreSQL
# We assume the database 'id' corresponds to the tc 'classid' suffix.
ACTIVE_IDS=$(sudo -u postgres psql -d adopisoft -t -c "SELECT id FROM sessions;" | tr -d '[:space:]')

# 3. Get the list of ALL classes currently managed by tc on this interface
# This extracts the number after '1:'
CURRENT_TC_CLASSES=$(tc class show dev $INTERFACE | grep "class hfsc 1:" | awk '{print $3}' | cut -d: -f2)

# 4. Compare and cleanup
for class_id in $CURRENT_TC_CLASSES; do
    # Skip the master parent class (usually 1:4) so we don't break the tree
    if [[ "$class_id" == "4" ]]; then
        continue
    fi

    # Check if this class_id exists in our list of active database sessions
    if [[ ! "$ACTIVE_IDS" =~ "$class_id" ]]; then
        echo " -> Detected orphan: 1:$class_id. Removing..."
        sudo tc class del dev $INTERFACE classid 1:$class_id
    fi
done

echo " -> Cleanup complete."
) >> "$LOG_FILE" 2>&1 &
EOF
sudo chmod +x "$DAILY_SCRIPT"

# 9.2.1. Reboot Delay
REBOOT_DELAY=15

# Safely catches x86, x64, i386, i686 architectures
if [[ "$(uname -m)" =~ (86|amd64) ]]; then
    REBOOT_DELAY=300
fi

# 9.3. GENERATE VACUUM MAINTENANCE SCRIPT
VACUUM_SCRIPT="/usr/local/bin/adopisoft-vacuum.sh"
cat << 'EOF' | sudo tee "$VACUUM_SCRIPT" > /dev/null
#!/bin/bash
LOG_FILE="/var/log/adopisoft_vacuum_maintenance.log"
echo "[$(date)] STARTING 6-HOUR FULL SYSTEM VACUUM..." | tee -a "$LOG_FILE"

LOGS="/var/log/syslog /var/log/dmesg /var/log/pppoe-server-log /var/log/auth.log /var/log/kern.log /var/log/lastlog /var/log/wtmp /var/log/apt/eipp.log.xz /var/log/apt/dataplicity.log /var/log/apt/alternative.log /var/log/nginx/access.log /var/log/armbian-hardware-monitor.log /var/log/supervisor/supervisor.log /var/log/postgresql/postgresql-16-main.log /var/log/adopisoft_maintenance.log /var/log/supervisor/supervisord.log /var/log/alternatives.log"

echo "  -> Truncating system logs..." | tee -a "$LOG_FILE"
for log in $LOGS; do
    if [ -f "$log" ]; then
        truncate -s 0 "$log"
    fi
done
truncate -s 0 /opt/adopisoft/logs/*.log 2>/dev/null

# FIX: Use 'reload' instead of 'restart' to prevent dropping active captive portal connections
systemctl reload nginx 2>/dev/null

echo "  -> Clearing Nginx temporary cache..." | tee -a "$LOG_FILE"
rm -rf /opt/adopisoft/tmp/nginx/* 2>/dev/null

echo "  -> Running database maintenance..." | tee -a "$LOG_FILE"
DB_MODE="postgres"
# STRICT CHECK: Trust ONLY the config file. Ignore leftover ghost files.
if grep -qi '"dbType"\s*:\s*"sqlite"' /opt/adopisoft/db/config.json 2>/dev/null; then
    DB_MODE="sqlite"
fi

if [ "$DB_MODE" == "sqlite" ]; then
    sqlite3 -cmd ".timeout 5000" /etc/adopisoft.sqlite "VACUUM;" >> "$LOG_FILE" 2>&1
else
    DB_PASS=$(grep -Po '(?<="password":")[^"]*' /opt/adopisoft/db/config.json 2>/dev/null || echo "adopisoft")
    export PGPASSWORD="$DB_PASS"
    PSQL=$(which psql)
    DB_NAME=$($PSQL -U postgres -t -A -c "SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%' AND datname != 'postgres';" 2>/dev/null | head -n 1)
    if [ -n "$DB_NAME" ]; then
        $PSQL -U postgres -d "$DB_NAME" -c "VACUUM ANALYZE;" >> "$LOG_FILE" 2>&1
        # FIX: Removed 'systemctl restart postgresql'. 
        # VACUUM ANALYZE is an online operation. Restarting the DB causes system watchdogs to trigger auto-reboots.
    fi
fi
echo "[$(date)] 6-HOUR FULL SYSTEM VACUUM SUCCESSFUL." | tee -a "$LOG_FILE"
EOF
sudo chmod +x "$VACUUM_SCRIPT"

# ==============================================================================
# STEP 9.4: IDEMPOTENT CRON REGISTRATION (PREVENTS ALL MULTIPLE LINE COPIES)
# ==============================================================================
echo "[9.4] Enforcing clean crontab state..."

DESIRED_CRON=$(cat << EOF
# --- NAT FIXER ---
*/30 * * * * /usr/bin/natfixer

# --- DAILY SESSION MAINTENANCE (3:40 AM) ---
40 3 * * * /usr/local/bin/flarewifi-daily.sh >> /var/log/adopisoft_maintenance.log 2>&1

# --- 6-HOUR SYSTEM VACUUM (10 MINUTES PAST) ---
10 */6 * * * /usr/local/bin/adopisoft-vacuum.sh >> /var/log/adopisoft_vacuum_maintenance.log 2>&1

# --- REBOOT TASKS ---
@reboot /bin/bash -c 'TRUNK=\$(ls /sys/class/net | grep "." | head -n 1 | cut -d"." -f1); if [ -n "\$TRUNK" ]; then /usr/local/bin/natfixer; fi'
EOF
)

CURRENT_CRON=$(sudo crontab -l 2>/dev/null | grep -v '^$')

if [ "$CURRENT_CRON" == "$DESIRED_CRON" ]; then
    echo "  -> ✅ Cron configuration is already pristine. Skipping execution."
else
    echo "  -> ⚠️ Cron mismatch or clutter discovered. Forcing declarative overwrite..."
    echo "$DESIRED_CRON" > /tmp/clean_cron_template
    sudo crontab /tmp/clean_cron_template
    rm /tmp/clean_cron_template
    echo "  -> ✅ Crontab successfully rebuilt cleanly."
fi


# 9.6--- THE FINAL CHECK (Dual-Database with LIVE COUNTDOWN & Relational Fix) ---
echo "--------------------------------------------------"
echo "SYSTEM HEALTH CHECK (MANUAL OVERRIDE):"

if [ "$DB_MODE" == "sqlite" ]; then
    ROW_COUNT=$(sqlite3 -cmd ".timeout 5000" /etc/adopisoft.sqlite "SELECT COUNT(*) FROM sessions;" 2>/dev/null)
    [ -z "$ROW_COUNT" ] && ROW_COUNT="0"
    
    echo "  -> Connected to Database: SQLite (/etc/adopisoft.sqlite)"
    echo "  -> Current Sessions: $ROW_COUNT"
else
    if [ -n "$DB_NAME" ]; then
        if psql -U postgres -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
            PSQL_CMD="psql -U postgres -d $DB_NAME"
        else
            PSQL_CMD="sudo -u postgres psql -d $DB_NAME"
        fi
        ROW_COUNT=$($PSQL_CMD -t -A -c "SELECT COUNT(*) FROM sessions;" 2>/dev/null)
        [ -z "$ROW_COUNT" ] && ROW_COUNT="0"
        
        echo "  -> Connected to Database: PostgreSQL ($DB_NAME)"
        echo "  -> Current Sessions: $ROW_COUNT"
    else
        ROW_COUNT=""
    fi
fi

if [ -n "$ROW_COUNT" ]; then
    echo "⚠️  MANUAL MAINTENANCE TRIGGERED"

    MANUAL_CLEAN="n"
    for ((i=60; i>0; i--)); do
        printf "\r    Run Database Cleanup now? (y/N) [Continuing in %2d s]: " $i
        read -n 1 -t 1 input
        if [[ "$input" =~ ^[Yy]$ ]]; then
            MANUAL_CLEAN="y"
            break
        elif [[ "$input" =~ ^[Nn]$ ]]; then
            MANUAL_CLEAN="n"
            break
        fi
    done
    printf "\n"

    if [[ "$MANUAL_CLEAN" == "y" ]]; then
        echo "  -> Executing Smart Purge... (Using Relational/Metric-Based Auth)"
        
        if [ "$DB_MODE" == "sqlite" ]; then
            # STANDARD RELATIONAL FIX: Purge Consumed/Expired sessions while allowing NULLs (Coinslot/Manual) and protecting Activated Vouchers
            sqlite3 -cmd ".timeout 5000" /etc/adopisoft.sqlite "DELETE FROM sessions WHERE (expiration_date < datetime('now') OR (time_seconds > 0 AND running_time_seconds >= time_seconds) OR (data_mb > 0 AND data_consumption_mb >= data_mb)) AND (voucher_code IS NULL OR voucher_code = '' OR voucher_code NOT IN (SELECT code FROM vouchers WHERE activated_at IS NOT NULL OR session_id IS NOT NULL));"
            sqlite3 -cmd ".timeout 5000" /etc/adopisoft.sqlite "VACUUM;"
            NEW_COUNT=$(sqlite3 -cmd ".timeout 5000" /etc/adopisoft.sqlite "SELECT COUNT(*) FROM sessions;" 2>/dev/null)
        else
            # STANDARD RELATIONAL FIX: Purge Consumed/Expired sessions while allowing NULLs (Coinslot/Manual) and protecting Activated Vouchers
            $PSQL_CMD -c "DELETE FROM sessions WHERE (expiration_date < NOW() OR (time_seconds > 0 AND running_time_seconds >= time_seconds) OR (data_mb > 0 AND data_consumption_mb >= data_mb)) AND (voucher_code IS NULL OR voucher_code = '' OR voucher_code NOT IN (SELECT code FROM vouchers WHERE activated_at IS NOT NULL OR session_id IS NOT NULL));"
            $PSQL_CMD -c "VACUUM ANALYZE sessions;"
            NEW_COUNT=$($PSQL_CMD -t -A -c "SELECT COUNT(*) FROM sessions;" 2>/dev/null)
        fi
        
        echo "  -> ✅ Cleanup complete."
        
        [ -z "$NEW_COUNT" ] && NEW_COUNT="0"
        
        if [ "$NEW_COUNT" -lt 8000 ]; then
            rm -f /tmp/armor_on
            echo "  -> 🛡️ Session count dropped to $NEW_COUNT. TC Armor returned to Standby."
        else
            touch /tmp/armor_on
            echo "  -> ⚠️ Session count still high ($NEW_COUNT). TC Armor remains Armed."
        fi
        
    else
        echo "  -> Cleanup skipped or timed out."
    fi
else
    echo "❌ ERROR: Database discovery failed on this hardware."
    echo "❌ Check your DB password/permissions."
fi

# --- STEP 10: DISABLING USBCORE.AUTOSUSPEND ---
echo "[10/14]--- Disable USB Autosuspend for Stability ---"
echo "Disabling usbcore.autosuspend across detected platforms..."

# ---------------------------------------------------------
# 10.1. Immediate Runtime Application (sysfs)
# ---------------------------------------------------------
if [ -f /sys/module/usbcore/parameters/autosuspend ]; then
    echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null
    echo "[OK] Applied immediately via sysfs."
else
    echo "[INFO] sysfs path not found (module might be built-in or not loaded yet)."
fi

# ---------------------------------------------------------
# 10.2. Universal Udev Rule (Debian, Ubuntu Server, Armbian)
# ---------------------------------------------------------
UDEV_DIR="/etc/udev/rules.d"
UDEV_RULE_FILE="$UDEV_DIR/50-disable-usb-autosuspend.rules"

if [ -d "$UDEV_DIR" ]; then
    # Overwrites the file completely each time (no duplicates)
    echo 'ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"' > "$UDEV_RULE_FILE"
    if command -v udevadm >/dev/null 2>&1; then
        udevadm control --reload-rules
        udevadm trigger
        echo "[OK] Applied universal Udev rule."
    fi
fi

# ---------------------------------------------------------
# 10.3. Bootloader Patching (For Kernel-level persistence)
# ---------------------------------------------------------

# A. Raspberry Pi (/boot/cmdline.txt or /boot/firmware/cmdline.txt)
for CMDLINE in /boot/cmdline.txt /boot/firmware/cmdline.txt; do
    if [ -f "$CMDLINE" ]; then
        if ! grep -q "usbcore.autosuspend=-1" "$CMDLINE"; then
            sed -i 's/$/ usbcore.autosuspend=-1/' "$CMDLINE"
            echo "[OK] Patched Raspberry Pi boot file: $CMDLINE"
        else
            echo "[INFO] Raspberry Pi boot file already patched: $CMDLINE"
        fi
    fi
done

# B. Orange Pi / Armbian (/boot/armbianEnv.txt)
ARMBIAN_ENV="/boot/armbianEnv.txt"
if [ -f "$ARMBIAN_ENV" ]; then
    if grep -q "^extraargs=" "$ARMBIAN_ENV"; then
        if ! grep -q "usbcore.autosuspend=-1" "$ARMBIAN_ENV"; then
            sed -i 's/^extraargs=.*/& usbcore.autosuspend=-1/' "$ARMBIAN_ENV"
            echo "[OK] Patched Armbian environment file."
        else
            echo "[INFO] Armbian environment file already patched."
        fi
    else
        echo "extraargs=usbcore.autosuspend=-1" >> "$ARMBIAN_ENV"
        echo "[OK] Added extraargs to Armbian environment file."
    fi
fi

# C. x86 / Standard Servers (GRUB)
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ] && command -v update-grub >/dev/null 2>&1; then
    if ! grep -q "usbcore.autosuspend=-1" "$GRUB_FILE"; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 usbcore.autosuspend=-1"/' "$GRUB_FILE"
        update-grub >/dev/null 2>&1
        echo "[OK] Patched GRUB configuration."
    else
        echo "[INFO] GRUB configuration already patched."
    fi
fi

# D. OpenWrt (Persistence via rc.local)
if [ -f /etc/openwrt_release ] || [ -f /etc/openwrt_version ]; then
    RC_LOCAL="/etc/rc.local"
    if [ -f "$RC_LOCAL" ]; then
        if ! grep -q "usbcore/parameters/autosuspend" "$RC_LOCAL"; then
            # Insert the sysfs command right before 'exit 0'
            sed -i '/^exit 0/i echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null\n' "$RC_LOCAL"
            echo "[OK] Patched OpenWrt rc.local for persistence."
        else
            echo "[INFO] OpenWrt rc.local already patched."
        fi
    fi
fi

echo "---------------------------------------------------------"
echo "Script execution complete. A reboot is recommended to ensure kernel parameters are fully applied on startup."

# --- POST-SCRIPT DEFERRED ACTIONS & REBOOT MANAGER ---
NEEDS_REBOOT=false

if [ "$REQUIRE_NETWORK_RESET" = true ]; then
    echo "---------------------------------------------------------"
    echo "🔄 NETWORK CHANGES DETECTED..."
    echo "  -> Netplan structure was updated to standard format."
    NEEDS_REBOOT=true
fi

if [ "$DRIVER_UPDATED" = true ]; then
    echo "---------------------------------------------------------"
    echo "🔄 NEW NETWORK DRIVER INSTALLED..."
    echo "  -> Realtek 2.5G driver requires a clean boot to load."
    NEEDS_REBOOT=true
fi

# --- STEP 11: Captive Portal API Support (RFC 8908) + Auto-Update ---
echo "[11/14]--- Captive Portal API Support (RFC 8908) + DHCP Option 114 ---"

# Detect VLANs for the Concurrency Guard
VLAN_COUNT=$(ip -br link show | grep -c "@")

# Define Permanent Paths
RFC_SCRIPT="/usr/local/bin/adopisoft-rfc8908.sh"
MASTER_INSTALLER="/usr/local/bin/install_rfc8908.sh"
RFC_SERVICE="adopisoft-rfc.service"
DL_URL="https://github.com/cybermind2/Adopisoft-deb-package/releases/download/v5.1.7-20260112/install_rfc8908.sh"

# 1. SYSTEM INTEGRITY & UPDATE CHECK
echo "  -> Verifying permanent system files in /usr/local/bin/..."
UPDATE_REQUIRED=false

# Check if BOTH files exist in the permanent location
if [ ! -f "$RFC_SCRIPT" ] || [ ! -f "$MASTER_INSTALLER" ]; then
    echo "  -> 🛠️ Status: Files missing from /usr/local/bin/. Fresh install required."
    UPDATE_REQUIRED=true
else
    # Download GitHub version to /tmp just for comparison
    wget -q -O "/tmp/remote_rfc.sh" "$DL_URL"
    if [ $? -eq 0 ]; then
        # Compare GitHub file to the MASTER copy in /usr/local/bin/
        LOCAL_HASH=$(md5sum "$MASTER_INSTALLER" | awk '{print $1}')
        REMOTE_HASH=$(md5sum "/tmp/remote_rfc.sh" | awk '{print $1}')
        
        if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
            echo "  -> 🔄 Status: New version detected on GitHub. Updating..."
            UPDATE_REQUIRED=true
        else
            echo "  -> ✅ Status: Permanent files match GitHub version."
        fi
    else
        echo "  -> ⚠️ Status: Offline. Skipping version check."
    fi
    rm -f "/tmp/remote_rfc.sh"
fi

# 2. HIGH-VLAN CONCURRENCY GUARD
SKIP_RESTARTS=false
if [ "$VLAN_COUNT" -gt 5 ]; then
    echo "  -> 🛡️ High VLAN detected ($VLAN_COUNT). Enabling 'No-Restart' mode."
    export SKIP_RESTARTS=true
fi

# 3. EXECUTION DECISION
if [ "$UPDATE_REQUIRED" = true ]; then
    echo "  -> 📥 Updating /usr/local/bin/install_rfc8908.sh..."
    if sudo wget -q -O "$MASTER_INSTALLER" "$DL_URL"; then
        sudo chmod +x "$MASTER_INSTALLER"
        
        echo "  -> 📦 Running Installer (Updating system script)..."
        sudo SKIP_RESTARTS=$SKIP_RESTARTS bash "$MASTER_INSTALLER"
        NEEDS_REBOOT=true
    else
        echo "  -> ❌ ERROR: Download failed."
    fi
else
    # If files are identical, only run if the service is NOT active
    if systemctl is-active --quiet "$RFC_SERVICE"; then
        echo "  -> ✅ Status: Service is already RUNNING. Skipping reinstallation."
    else
        echo "  -> 🛠️ Status: Service is INACTIVE. Repairing..."
        sudo SKIP_RESTARTS=$SKIP_RESTARTS bash "$MASTER_INSTALLER"
        NEEDS_REBOOT=true
    fi
fi

# --- STEP 12: UNIVERSAL HARDWARE-AWARE FIREWALL PATCH ---
echo "[12/14]--- Applying Hardware-Specific Firewall Compatibility ---"

# 1. Count VLANs and identify service name
VLAN_COUNT=$(ip -br link show | grep -c "@")
REAL_SVC=$(systemctl list-units --type=service --all | grep -oE "adopisoft(-manager)?\.service" | head -n1)

# 2. X86 PERFORMANCE TUNING
if [[ "$(uname -m)" =~ (x86_64|amd64) ]]; then
    echo "  -> 💻 Ubuntu x86 Detected: Optimizing Firewall Pipeline..."
    
    # IDEMPOTENCY PRE-CHECK: Protected by system timeout to prevent hanging on initialization checks
    if timeout 5 sudo iptables -t filter -w 3 -L ADOPI_AUTH -n >/dev/null 2>&1 && \
       timeout 5 sudo iptables -t filter -w 3 -L ADOPI_AUTH -n 2>/dev/null | grep -q "x86_fix"; then
        echo "  -> 🎉 High-Concurrency 'Shelves' already active and verified. Skipping creation."
    else
        echo "  -> 🛠️ Building High-Concurrency 'Shelves'..."
        
        # FIX FOR 26.04: Temporarily stop the service early to release active background locks
        if [ -n "$REAL_SVC" ]; then
            echo "     -> 🛑 Stopping $REAL_SVC to clear active firewall locks..."
            sudo systemctl stop "$REAL_SVC" 2>/dev/null
        fi

        # CRITICAL FIX FOR 26.04: ALWAYS pre-load netfilter modules directly into the kernel
        # This completely avoids the auto-load deadlock that happens on modern kernels.
        echo "     -> 🔌 Pre-loading Netfilter kernel modules..."
        for mod in ip_tables iptable_filter iptable_mangle iptable_nat; do
            sudo modprobe $mod 2>/dev/null
        done
        
        # 3. CONCURRENCY OPTIMIZATION: Build the Chains
        TABLES="filter mangle nat"
        CHAINS="ADOPI_AUTH ADOPI_PAUSE ADOPI_MARK ADOPI_POST ADOPI_PRE ADOPI_LOGIN ADOPI_LIMIT"
        
        for t in $TABLES; do
            echo "     -> 📂 Processing Table: $t..."
            # Force initialize the backend table structure using system timeout protection
            timeout 5 sudo iptables -t $t -w 5 -L >/dev/null 2>&1
            
            for c in $CHAINS; do
                # Create the chain ONLY if it doesn't exist
                if ! timeout 5 sudo iptables -t $t -w 5 -L $c -n >/dev/null 2>&1; then
                    timeout 5 sudo iptables -t $t -w 5 -N $c 2>/dev/null
                fi
                
                # Double check that the chain exists before appending placeholder rules
                if timeout 5 sudo iptables -t $t -w 5 -L $c -n >/dev/null 2>&1; then
                    COUNT=$(timeout 5 sudo iptables -t $t -w 5 -L $c -n 2>/dev/null | grep -c "x86_fix")
                    while [ $COUNT -lt 6 ]; do
                        timeout 5 sudo iptables -t $t -w 5 -A $c -m comment --comment "x86_fix" -j RETURN 2>/dev/null
                        COUNT=$((COUNT + 1))
                    done
                fi
            done
        done
        echo "  -> ✅ High-Concurrency 'Shelves' optimization processed."
    fi
    
    # 4. DECISION LOGIC: Preventing the "30% - 55% Dashboard Hang"
    if [ "$VLAN_COUNT" -gt 5 ]; then
        echo "  -> 🚀 High VLAN Count ($VLAN_COUNT) Detected."
        echo "  -> 🛡️ Enabling Safe-Path: Skipping restart to prevent 100% stall."
        echo "  -> ⚠️ A CLEAN REBOOT will be triggered to avoid the 40-minute wait."
        sync
        NEEDS_REBOOT=true
    elif [ -n "$REAL_SVC" ]; then
        echo "  -> ✅ Low VLAN count. Re-starting immediate service sync..."
        sudo systemctl start "$REAL_SVC" 2>/dev/null
    fi
else
    echo "  -> 🛡️ ARM Architecture detected. Applying standard wait-locks..."
    timeout 5 sudo iptables -w 5 -L > /dev/null 2>&1
fi

# --- STEP 13/14: WAN-Only CAKE SQM Deployment (Aggressive Overwrite) ---
echo "[13/14] Deploying Persistent WAN-Only CAKE SQM Service..."

# --- NEW: DELETE CONFLICTING SYSCTL OVERRIDES ---
sudo rm -f /etc/sysctl.d/99-sqm-custom.conf 2>/dev/null
sudo rm -f /etc/sysctl.d/10-adopisoft-performance.conf 2>/dev/null
sudo sysctl -p >/dev/null 2>&1 || true

# ==============================================================================
# 0. PRE-FLIGHT: KERNEL MODULE CHECK & AUTO-INSTALL
# ==============================================================================
if ! modinfo sch_cake >/dev/null 2>&1 && ! lsmod | grep -q "cake"; then
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y sch-cake sch-cake-dkms linux-modules-extra-$(uname -r) >/dev/null 2>&1 || true
    sudo modprobe sch_cake 2>/dev/null || true
fi

SCRIPT_PATH="/usr/local/bin/apply-cake-sqm.sh"
SERVICE_PATH="/etc/systemd/system/cake-sqm.service"

# ==============================================================================
# 1. CREATE THE AGGRESSIVE BACKGROUND WAN-ONLY RECOVERY SCRIPT
# ==============================================================================
cat << 'SQM_SCRIPT_EOF' > $SCRIPT_PATH
#!/bin/bash

# Nelfox Custom: 60-second delay to ensure Proxmox VLANs are fully stabilized
sleep 60

# Wait up to 30 seconds for a default route
for i in {1..30}; do
    TARGET_WAN=$(ip route get 8.8.8.8 2>/dev/null | awk -F'dev ' 'NR==1 {split($2,a," "); print a[1]}')
    [ -n "$TARGET_WAN" ] && break
    sleep 1
done

if [ -z "$TARGET_WAN" ]; then exit 1; fi

# 1. Clean the slate: Explicitly delete any existing qdisc on the root.
sudo tc qdisc del dev "$TARGET_WAN" root 2>/dev/null

# 2. Attempt to load and use CAKE
sudo modprobe sch_cake >/dev/null 2>&1
CAKE_PARAMS="bandwidth 1000mbit triple-isolate nat ack-filter besteffort wash"

# 3. Apply CAKE, and if it fails, fallback to FQ_CoDel
if sudo tc qdisc add dev "$TARGET_WAN" root cake $CAKE_PARAMS 2>/dev/null; then
    logger "SQM: CAKE successfully applied to $TARGET_WAN"
else
    logger "SQM: CAKE failed, falling back to FQ_CoDel on $TARGET_WAN"
    sudo tc qdisc add dev "$TARGET_WAN" root fq_codel
fi
SQM_SCRIPT_EOF

chmod +x $SCRIPT_PATH

# ==============================================================================
# 2. SYSTEMD HOOK & ACTIVATION
# ==============================================================================
cat << 'SQM_SERVICE_EOF' > $SERVICE_PATH
[Unit]
Description=WAN-Only SQM Service (CAKE/FQ_CoDel)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash /usr/local/bin/apply-cake-sqm.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SQM_SERVICE_EOF

chmod +x $SERVICE_PATH
systemctl daemon-reload
systemctl enable cake-sqm.service
systemctl restart cake-sqm.service

# ==============================================================================
# 3. VERIFICATION
# ==============================================================================
echo "  -> Waiting for WAN queues to initialize (60s custom delay + 5s buffer)..."
sleep 65
echo "--- WAN-ONLY VERIFICATION REPORT ---"

TARGET_WAN=$(ip route get 8.8.8.8 | awk -F'dev ' 'NR==1 {split($2,a," "); print a[1]}')

if [ -n "$TARGET_WAN" ]; then
    QDISC_INFO=$(tc -d qdisc show dev "$TARGET_WAN" 2>/dev/null)
    echo -n "Interface $TARGET_WAN: "
    if echo "$QDISC_INFO" | grep -qi "cake"; then
        echo "✅ CAKE Active on WAN"
    elif echo "$QDISC_INFO" | grep -qi "fq_codel"; then
        echo "✅ FQ_CoDel Active (Fallback Mode)"
    else
        echo "❌ SQM Inactive"
    fi
else
    echo "❌ Error: Could not verify WAN interface."
fi

echo "  -> ✅ Step 13: Deployment Completed."

# ==============================================================================
# STEP 14: INTELLIGENT DROPOUT REPAIR & SYNTAX INTEGRITY GUARD
# ==============================================================================
echo ""
echo "[14/14] RUNNING DROP-IN CONFIGURATION INTEGRITY CHECK..."
echo "------------------------------------------------------------"

CONFIG_DIR="/etc/systemd/system/adopisoft.service.d"
CONFIG_FILE="$CONFIG_DIR/stability.conf"
HAS_SYNTAX_ERROR=false

# 1. Run Diagnostic Tests on the existing file
if [ -f "$CONFIG_FILE" ]; then
    echo "  -> Scanning stability.conf for malformations..."
    
    # Check A: Look for broken/split password blocks (lines matching raw password strings without variable keys)
    # Check B: Look for unclosed quotes or lines missing '=' signs
    if grep -E "^[A-Za-z0-9\}\|\&\-]{4,}$" "$CONFIG_FILE" >/dev/null 2>&1 || \
       grep "PGPASSWORD=" "$CONFIG_FILE" | grep -v '"$' >/dev/null 2>&1 || \
       ! grep -q "Environment=" "$CONFIG_FILE"; then
        echo "  -> ⚠️ SYNTAX ALERT: Broken configurations or unclosed quotes detected."
		echo "  -> ⚠️ Applying Fix...................................................."
        HAS_SYNTAX_ERROR=true
    else
        echo "  -> 🟢 PASS: File is structurally clean and free of formatting drops."
    fi
else
    echo "  -> ℹ️ NOTICE: stability.conf does not exist yet. Initializing profile."
    HAS_SYNTAX_ERROR=true
fi

# 2. Conditional Execution Path
if [ "$HAS_SYNTAX_ERROR" = true ]; then
    echo "  -> 🔧 Executing automated repair workflow..."

    # Dynamic WAN Interface Detection
    WAN_IF=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [ -z "$WAN_IF" ]; then
        WAN_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|enp|eno|ens)' | head -n 1)
    fi
    [ -z "$WAN_IF" ] && WAN_IF="eth0"
    echo "     - Target Interface Selected: $WAN_IF"

    # Clean Password Extraction Pattern (Saves the true seed from the malformed layout)
    DB_PASS=""
if [ -f "/opt/adopisoft/db/config.json" ]; then
    DB_PASS=$(grep -Po '(?<="password":")[^"]*' /opt/adopisoft/db/config.json 2>/dev/null)
fi

# Fallback to scraping stability.conf only if JSON extraction yielded nothing
if [ -z "$DB_PASS" ] && [ -f "$CONFIG_FILE" ]; then
    DB_PASS=$(grep "PGPASSWORD=" "$CONFIG_FILE" | head -n 1 | sed -e 's/.*PGPASSWORD=//' -e 's/"//g' -e 's/\r//g' -e 's/ //g')
fi

# Core system recovery default if both sources fail
if [ -z "$DB_PASS" ]; then
    echo "     - Querying central config fallback..."
    DB_PASS="adopisoft"
fi

    # Atomic Reconstruct
    mkdir -p "$CONFIG_DIR"
    cat << EOF > "$CONFIG_FILE"
[Service]
# Automatically managed by bootoptimizer step 14
# Target Interface: $WAN_IF
ExecStartPre=-/bin/bash -c 'timeout 20 sh -c "until ip -4 addr show dev $WAN_IF | grep -q inet; do sleep 1; done"'
Environment="PGPASSWORD=$DB_PASS"
EOF

    chmod 644 "$CONFIG_FILE"
    
    echo "  -> Reloading systemd daemon maps..."
    systemctl daemon-reload

    echo "  -> Flagging system reboot configuration cycle..."
    NEEDS_REBOOT=true
    echo "  -> ✅ Step 14: File structural repair successfully completed."
else
    echo "  -> 🚀 Skipping configuration build process. No changes required."
fi
echo "------------------------------------------------------------"

# --- THE LIVE REBOOT COUNTDOWN (54 VLAN x86 Optimized) ---
if [ "$NEEDS_REBOOT" = true ]; then
    echo ""
    echo "⚠️ SYSTEM REBOOT REQUIRED to safely apply network and kernel changes."
    echo "   (This prevents the 100% hang by clearing the stalled kernel state)"

    # 1. PRE-REBOOT STABILIZATION
    # Stop the manager to release xtables and rtnetlink locks
    echo "  -> 🛑 Stopping AdoPiSoft Manager to release network locks..."
    sudo systemctl stop adopisoft 2>/dev/null
    
    # Flush all filesystem buffers to ensure logs and database are safe
    sync
    sleep 1
    sync

    # 2. THE COUNTDOWN
    # Ensure REBOOT_DELAY has a fallback if jumping straight to Step 14
[ -z "$REBOOT_DELAY" ] && REBOOT_DELAY=15
if [[ "$(uname -m)" =~ (x86_64|amd64) ]]; then
    REBOOT_DELAY=300
fi

for ((i=$REBOOT_DELAY; i>0; i--)); do
    printf "\r🔄 Rebooting in %3d seconds... (Press Ctrl+C to cancel) " $i
    sleep 1
done

    # 3. FORCEFUL EXECUTION
    printf "\n🚀 Triggering Force Reboot...\n"
    
    # -f (force) tells the kernel to reset immediately, bypassing
    # any services like DHCP or TC that are currently hanging.
    sudo reboot -f
fi
