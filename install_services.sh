#!/bin/bash

# Setup script for installing systemd services for Whisplay AI Chatbot

echo "=== Whisplay AI Chatbot Service Installer ==="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "[ERROR] Please do not run this script as root or with sudo"
    echo "The script will ask for sudo password when needed"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "[INFO] Installing systemd service files..."

# Copy service files to systemd directory
sudo cp "$SCRIPT_DIR/llama-server.service" /etc/systemd/system/
sudo cp "$SCRIPT_DIR/whisplay-chatbot.service" /etc/systemd/system/

# Set correct permissions
sudo chmod 644 /etc/systemd/system/llama-server.service
sudo chmod 644 /etc/systemd/system/whisplay-chatbot.service

echo "[INFO] Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "[INFO] Enabling services to start on boot..."
sudo systemctl enable llama-server.service
sudo systemctl enable whisplay-chatbot.service

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Service Management Commands:"
echo "  Start services:   sudo systemctl start llama-server"
echo "                    sudo systemctl start whisplay-chatbot"
echo ""
echo "  Stop services:    sudo systemctl stop whisplay-chatbot"
echo "                    sudo systemctl stop llama-server"
echo ""
echo "  Restart services: sudo systemctl restart llama-server"
echo "                    sudo systemctl restart whisplay-chatbot"
echo ""
echo "  Check status:     sudo systemctl status llama-server"
echo "                    sudo systemctl status whisplay-chatbot"
echo ""
echo "  View logs:        journalctl -u llama-server -f"
echo "                    journalctl -u whisplay-chatbot -f"
echo "                    tail -f ~/whisplay-ai-chatbot/llama.log"
echo "                    tail -f ~/whisplay-ai-chatbot/chatbot.log"
echo ""
echo "  Disable autostart: sudo systemctl disable llama-server"
echo "                     sudo systemctl disable whisplay-chatbot"
echo ""
echo "The services will now start automatically on boot."
echo "To start them now without rebooting, run:"
echo "  sudo systemctl start llama-server"
echo "  sudo systemctl start whisplay-chatbot"
echo ""
