#!/bin/bash

# Raspberry Pi 5 Performance Optimization Script
# This script applies system-level optimizations for better LLM performance

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

echo "=========================================="
echo "Raspberry Pi 5 Performance Optimization"
echo "=========================================="
echo ""

# 1. Configure CPU Overclocking in config.txt
print_info "Step 1: Configuring CPU overclocking..."

CONFIG_FILE="/boot/firmware/config.txt"
BACKUP_FILE="/boot/firmware/config.txt.backup.$(date +%Y%m%d_%H%M%S)"

# Backup config.txt
cp "$CONFIG_FILE" "$BACKUP_FILE"
print_info "Created backup: $BACKUP_FILE"

# Check if overclocking settings already exist
if grep -q "^arm_freq=" "$CONFIG_FILE"; then
    print_warn "arm_freq already set in config.txt, updating..."
    sed -i 's/^arm_freq=.*/arm_freq=2800/' "$CONFIG_FILE"
else
    print_info "Adding arm_freq=2800 to config.txt..."
    echo "" >> "$CONFIG_FILE"
    echo "# Performance overclocking" >> "$CONFIG_FILE"
    echo "arm_freq=2800" >> "$CONFIG_FILE"
fi

if grep -q "^over_voltage=" "$CONFIG_FILE"; then
    print_warn "over_voltage already set in config.txt, updating..."
    sed -i 's/^over_voltage=.*/over_voltage=2/' "$CONFIG_FILE"
else
    print_info "Adding over_voltage=2 to config.txt..."
    echo "over_voltage=2" >> "$CONFIG_FILE"
fi

print_info "✓ Overclocking configured (requires reboot)"

# 2. Configure tmpfs for /tmp
print_info "Step 2: Configuring tmpfs for /tmp..."

if grep -q "tmpfs /tmp" /etc/fstab; then
    print_warn "/tmp tmpfs already configured in /etc/fstab"
else
    echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab
    print_info "✓ Added tmpfs mount for /tmp to /etc/fstab"
fi

# Mount tmpfs now if not already mounted
if ! mount | grep -q "tmpfs on /tmp"; then
    mount -t tmpfs -o defaults,noatime,mode=1777 tmpfs /tmp
    print_info "✓ Mounted tmpfs on /tmp"
else
    print_info "✓ /tmp already mounted as tmpfs"
fi

# 3. Create systemd service for CPU performance mode
print_info "Step 3: Creating CPU performance governor service..."

cat > /etc/systemd/system/cpu-performance.service << 'EOF'
[Unit]
Description=Set CPU Governor to Performance Mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable cpu-performance.service
systemctl start cpu-performance.service

print_info "✓ CPU performance governor service created and enabled"

# 4. Set CPU to performance mode now
print_info "Step 4: Setting CPU governor to performance mode..."

echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

# Verify
CURRENT_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if [ "$CURRENT_GOVERNOR" = "performance" ]; then
    print_info "✓ CPU governor set to: performance"
else
    print_error "Failed to set CPU governor (current: $CURRENT_GOVERNOR)"
fi

echo ""
echo "=========================================="
echo "Optimization Complete!"
echo "=========================================="
echo ""
print_info "Summary of changes:"
echo "  • CPU overclocking: arm_freq=2800, over_voltage=2"
echo "  • tmpfs configured for /tmp (faster temporary files)"
echo "  • CPU governor set to performance mode"
echo ""
print_warn "IMPORTANT: Reboot required for overclocking to take effect"
echo ""
print_info "Current CPU governor: $CURRENT_GOVERNOR"
print_info "Backup saved to: $BACKUP_FILE"
echo ""
print_info "To reboot now, run: sudo reboot"
print_info "To check CPU frequency after reboot: cat /sys/devices/system/cpu/cpu0/cpuinfo_cur_freq"
echo ""
