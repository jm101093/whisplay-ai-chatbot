#!/bin/bash

# Script to install audio volume service

echo "=== Audio Volume Service Installer ==="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "[ERROR] Please do not run this script as root or with sudo"
    echo "The script will ask for sudo password when needed"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "[INFO] Installing audio volume service..."

# Copy service file to systemd directory
sudo cp "$SCRIPT_DIR/set-volume.service" /etc/systemd/system/

# Set correct permissions
sudo chmod 644 /etc/systemd/system/set-volume.service

echo "[INFO] Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "[INFO] Enabling service to run on boot..."
sudo systemctl enable set-volume.service

echo "[INFO] Starting service now..."
sudo systemctl start set-volume.service

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Audio volume will now be set to maximum on every boot."
echo ""
echo "To check status:"
echo "  sudo systemctl status set-volume"
echo ""
echo "To test volume now:"
echo "  amixer sget Master"
echo "  amixer sget PCM"
echo ""
echo "To disable:"
echo "  sudo systemctl disable set-volume"
echo ""
