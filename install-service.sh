#!/bin/bash
#
# Install Service Health Monitor as a systemd user service
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="service-monitor.service"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Service Health Monitor Installer    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

# Check if service file exists
if [[ ! -f "${SCRIPT_DIR}/${SERVICE_NAME}" ]]; then
    echo -e "${RED}Error: ${SERVICE_NAME} not found in ${SCRIPT_DIR}${NC}"
    exit 1
fi

# Create systemd user directory if it doesn't exist
if [[ ! -d "$SYSTEMD_USER_DIR" ]]; then
    echo "Creating systemd user directory..."
    mkdir -p "$SYSTEMD_USER_DIR"
fi

# Copy service file
echo "Installing service file..."
cp "${SCRIPT_DIR}/${SERVICE_NAME}" "${SYSTEMD_USER_DIR}/"

# Update WorkingDirectory and ExecStart paths in the service file
sed -i "s|%h/service-health-monitor|${SCRIPT_DIR}|g" "${SYSTEMD_USER_DIR}/${SERVICE_NAME}"

# Reload systemd
echo "Reloading systemd daemon..."
systemctl --user daemon-reload

# Enable the service
echo "Enabling service to start on boot..."
systemctl --user enable service-monitor.service

# Start the service
echo "Starting service..."
systemctl --user start service-monitor.service

echo -e "\n${GREEN}✓ Installation complete!${NC}\n"

# Show status
echo "Service status:"
systemctl --user status service-monitor.service --no-pager

echo -e "\n${YELLOW}Useful commands:${NC}"
echo "  systemctl --user status service-monitor   # Check status"
echo "  systemctl --user stop service-monitor     # Stop monitoring"
echo "  systemctl --user start service-monitor    # Start monitoring"
echo "  systemctl --user restart service-monitor  # Restart monitoring"
echo "  systemctl --user disable service-monitor  # Disable auto-start"
echo "  journalctl --user -u service-monitor -f   # View live logs"

echo -e "\n${GREEN}The monitor is now running in the background!${NC}"
echo -e "It will automatically start on boot and monitor your services.\n"
