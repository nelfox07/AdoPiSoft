🚀 THE ULTIMATE PISOWIFI SYSTEM ACCELERATOR is HERE! 🚀
Master Boot Optimizer v10.8 is officially ready! Built by Flarego Technologies, this master script provides universal performance tuning, crash-prevention shields, and network optimization for x86 Mini PCs, Raspberry Pi 4/5, and Orange Pi boards.
If you are running complex multi-user setups, high VLAN counts, or heavy PPPoE client traffic, this script transforms your machine into a bulletproof enterprise router.
Here is the complete, breakdown of the engineering behind all 13 Steps:
🛠️ FULL CORE FEATURES BREAKDOWN (STEPS 1–13) 🛠️
🔍 [Step 0 to 0.5] Hardware Intelligence & Pre-Boot Diagnostics
0. Smart Hardware Auto-Discovery: Instantly identifies your architecture (x86_64, RPi, or OPi) and auto-detects your primary WAN gateway so configuration is fully custom-fit to your board.
0.1-0.2. Multi-Database Auto-Sync: Deep-scans system configs to seamlessly bind and extract parameters for both SQLite and PostgreSQL deployments without losing credentials.
0.3. Kernel Race-Condition Shield: Stops typical RTNETLINK and Duplicate Address Detection (DAD) conflicts, allowing the portal software to bind securely during high-concurrency boot sequences.
0.4. Physical Gigabit Enforcement: Forces hardware link speed advertisements to lock cleanly at 1000Mbps, stopping faulty cables or ports from dropping down to a slow 100Mbps.
0.5. SQLites WAL Concurrency Engine: Upgrades SQLite databases to Write-Ahead Logging (WAL) Mode and adds a 5-second busy timeout. This allows concurrent reads and writes, permanently stopping "Database is Locked" crash loops on high-traffic units.
🏎️ [Step 1 to 2] The Anti-Hang Boot Accelerator
1. Netplan Hierarchy Self-Repair: Standardizes broken YAML configurations, automatically maps parent links for USB-to-LAN cards, and structures your interfaces to avoid network configuration failure.
2. The 15% & 100% Dashboard Hang Fix: Masks unresponsive system online wait-services that slow down boot times. Inserts a smart dynamic timer that safely pauses services until the WAN interface secures an IP, preventing system boot lockups.
🛡️ [Step 3 to 4] Network & Gateway Optimization
3. Aggressive DNS Hierarchy & Walled Garden Accelerator: Locks your DNS configuration (8.8.8.8 ➔ 1.1.1.1 ➔ Gateway IP) with a fast 1-second timeout. Maps primary financial portals (GCash, Maya, PayMongo, Xendit) directly into /etc/hosts to completely eliminate payment gateway loading delay.
4. Ghost IPTables Wrapper (30% & 40% Boot Fix): Deploys an ultra-fast temporary wrapper during the first 5 minutes of system startup to bypass reverse DNS log jams (fixing the infamous dashboard 30%/40% stuck counter). It then switches seamlessly into an invisible passthrough to accurately parse live active users.
🐎 [Step 5 to 6] High-Capacity Performance Tuning
5. CPU Performance Governor Lock: Forces your system CPU cores out of "on-demand" power-saving modes and locks them permanently into Maximum Performance Mode. Expands connection limits up to 1 Million tracking states to handle over 700+ concurrent active portal devices effortlessly.
6. The 10,000 User Armor (TC Wrapper Engine): Compiles an internal C-based Traffic Control guard on your machine. If user sessions approach enterprise scales, this smart gate handles class tokens safely to avoid system-wide packet routing bottlenecks.
🌐 [Step 7 to 8] Advanced Routing & Hardware Stability
7. PPPoE Server Repair & MSS Clamping: Automates internal NAT Masquerading, syncs selected panel interfaces, and introduces optimized LCP Echo checks to cleanly destroy "Ghost Sessions". Implements TCP MSS Clamping to accelerate webpage loading for PPPoE clients.
8. CPU Load Imbalance & Interrupt Balancing: Safely routes Ethernet card queues based on hardware capability. Activates automated IRQ balancing on powerful multi-core x86 machines, while explicitly safeguarding built-in Ethernet on Orange Pi/Raspberry Pi architectures to prevent core locks.
🧹 [Step 9 to 10] Smart Maintenance & USB Integrity
9. Self-Healing Daily Maintenance Engine: Establishes an automated daily script to monitor database weights. If the unit reaches over 8,000 stale sessions, it automatically invokes a smart database purge and a deep VACUUM cleanup to maintain high read/write speeds.
10. Universal USB Autosuspend Disabler: Applies hardware overrides across GRUB, ArmbianEnv, and Udev directories to shut down USB power savings. This guarantees that external USB-to-LAN network adapters never randomly fall asleep or drop customers.
📡 [Step 11 to 13] Enterprise Features & Bufferbloat Eraser
11. Captive Portal API Support (RFC 8908): Injects native infrastructure support for modern operating systems via DHCP Option 114. Mobile clients receive instantaneous, native system push notifications to open the log-in page upon connection.
12. High-VLAN Concurrency Firewall Guard: Solves the massive "40-minute boot hang" often found on heavy x86 network installations with 54+ VLANs. Pre-builds clean iptables chain configurations in the kernel so the manager software can immediately apply customer rules without stuttering.
13. Per-Client Leaf SQM (Bufferbloat Suppression): The crown jewel of network optimization. Automatically evaluates system support to deploy advanced CAKE (Triple Isolation/Host Fairness) queue rules, falling back gracefully to fq_codel if required. It dynamically enforces lag-free client queues across all live interfaces, ensuring smooth ping for online gaming (like Mobile Legends) even when other users max out their downloads.
⚡ THE BOTTOM LINE:
This script transforms a normal SBC or Mini PC from a basic local hotspot machine into a rock-solid, carrier-grade router deployment. It is entirely idempotent (meaning you can run it multiple times safely—it will only apply fixes where they are missing) and features a smart, graceful shutdown counter to safely clear kernel locks before completing its job.
#FlaregoTechnologies #PisoWiFi #FlareWiFi #NetworkEngineering #BufferbloatFix #OpenWrt #linuxoptimization

Step 1: Connect to your server via SSH
IMPORTANT: You must SSH into your machine using your WAN IP (e.g., your local router's IP, like 192.168.1.x). Do not use the local PisoWiFi network IP (10.0.0.1). Because this script optimizes network interfaces, connecting via 10.0.0.1 will cause your terminal to disconnect in the middle of the process!
Step 2: Download the Optimizer Script Copy and paste this command into your terminal to download the latest v5.1.7 compatible script into your temporary folder:

NOTE: Tested both on PostgreSQL database, and SQLite. For version 5.1.7-20260106 only.

sudo wget -O /tmp/bootoptimizer.sh https://raw.githubusercontent.com/nelfox07/AdoPiSoft/refs/heads/Nelfox-Network-and-Data-Solution/5.1.7/Optimizer/bootoptimizer.sh

Step 3: Make the Script Executable Give the system permission to run the file by executing:
sudo chmod +x /tmp/bootoptimizer.sh

Step 4: Run the Optimizer Execute the script with root privileges. Follow any on-screen prompts if asked:
sudo /tmp/bootoptimizer.sh
