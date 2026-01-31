# Service Health Monitor

A lightweight, shell-based systemd service monitoring tool for Linux with desktop notifications. Get alerted instantly when your critical services fail!

## Features

-  **Real-time Monitoring** - Continuously watch your systemd services
-  **Desktop Notifications** - Instant alerts when services change state
-  **Status Dashboard** - Clean terminal UI showing all service states
-  **Activity Logging** - Track all service state changes over time
-  **Easy Configuration** - Simple text file to manage monitored services
-  **Colorful Output** - Color-coded status indicators
-  **Lightweight** - Pure Bash, minimal dependencies

## Screenshots

```
╔════════════════════════════════════════╗
║    Service Health Monitor Status     ║
╚════════════════════════════════════════╝

SERVICE                        STATUS
-------                        ------
ssh                            ✓ RUNNING
nginx                          ✓ RUNNING
mysql                          ✗ FAILED
docker                         ○ STOPPED
```

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/andrej4771/service-health-monitor.git
cd service-health-monitor

# Make the script executable
chmod +x service-monitor.sh

# Create initial configuration
./service-monitor.sh init

# Optional: Install system-wide
sudo cp service-monitor.sh /usr/local/bin/service-monitor
```

## Quick Start

### 1. Initialize Configuration

```bash
./service-monitor.sh init
```

This creates a `services.conf` file with common services commented out.

### 2. Edit Configuration

```bash
nano services.conf
```

Add the services you want to monitor (one per line):

```
ssh
nginx
mysql
docker
```

### 3. Start Monitoring

```bash
./service-monitor.sh monitor
```

The monitor will run continuously and send desktop notifications when services change state.

## Usage

### Basic Commands

```bash
# Start monitoring (runs in foreground)
./service-monitor.sh monitor

# Check current status of all services
./service-monitor.sh status

# Add a service to monitor
./service-monitor.sh add nginx

# Remove a service from monitoring
./service-monitor.sh remove nginx

# List all monitored services
./service-monitor.sh list

# View recent logs
./service-monitor.sh logs

# View last 100 log lines
./service-monitor.sh logs 100

# Test notification system
./service-monitor.sh test
```

### Running as Background Service (Recommended)

The easiest way to run the monitor continuously is to install it as a systemd user service. It will start automatically on boot and run in the background.

#### Automatic Installation (Recommended):

```bash
# Install as systemd service
./install-service.sh
```

That's it! The monitor now runs automatically in the background and will start on boot.

**Useful commands:**
```bash
systemctl --user status service-monitor   # Check status
systemctl --user stop service-monitor     # Stop monitoring
systemctl --user start service-monitor    # Start monitoring
systemctl --user restart service-monitor  # Restart monitoring
journalctl --user -u service-monitor -f   # View live logs
```

**To uninstall:**
```bash
./uninstall-service.sh
```

#### Alternative: Using screen (temporary):

```bash
screen -S service-monitor
./service-monitor.sh monitor
# Press Ctrl+A then D to detach
```

To reattach: `screen -r service-monitor`

## Configuration

### services.conf

The configuration file is a simple text file with one service name per line:

```bash
# This is a comment
ssh
nginx
mysql

# You can add comments anywhere
docker
postgresql
```

Service names should match the systemd service name (without the `.service` extension).

### Customization

You can edit the script to customize:

- `CHECK_INTERVAL` - Time between checks (default: 30 seconds)
- `LOG_FILE` - Location of log file
- `CONFIG_FILE` - Location of config file

## Requirements

- Linux with systemd
- Bash 4.0+
- `notify-send` for desktop notifications (optional)

### Installing notify-send

```bash
# Ubuntu/Debian/Pop!_OS
sudo apt install libnotify-bin

# Fedora
sudo dnf install libnotify

# Arch
sudo pacman -S libnotify
```

## Service States

The monitor tracks four service states:

- **✓ RUNNING** (green) - Service is active and running
- **✗ FAILED** (red) - Service has failed
- **○ STOPPED** (yellow) - Service is inactive/stopped
- **? NOT FOUND** (red) - Service doesn't exist

## Notifications

Desktop notifications are sent when:

- A service **fails** (critical priority)
- A service **recovers** from failure (normal priority)
- A service **stops** (normal priority)

## Logging

All service state changes are logged to `monitor.log` with timestamps:

```
[2026-01-31 10:15:23] [INFO] Monitor started
[2026-01-31 10:15:45] [ERROR] nginx: active -> failed (FAILED)
[2026-01-31 10:16:30] [INFO] nginx: failed -> active (recovered)
```

## Use Cases

Perfect for:

- **Server administrators** - Monitor critical services on production servers
- **Developers** - Watch local development services (databases, web servers)
- **DevOps** - Quick alerts for service failures during deployments
- **Home labs** - Monitor self-hosted services

## Common Services to Monitor

### Web Servers
- `nginx`
- `apache2`

### Databases
- `mysql`
- `postgresql`
- `mongodb`
- `redis`

### System Services
- `ssh`
- `cron`

### Containers
- `docker`
- `containerd`

### Other
- `fail2ban`
- `ufw`
- Custom application services

## Troubleshooting

### "Service not found" warnings

Make sure you're using the correct systemd service name:

```bash
# Check if service exists
systemctl list-unit-files | grep nginx

# The service name is usually without .service extension
# nginx.service → use "nginx" in config
```

### Notifications not working

1. Check if notify-send is installed:
   ```bash
   which notify-send
   ```

2. Test notifications:
   ```bash
   ./service-monitor.sh test
   ```

3. Make sure you're running in a desktop session (notifications won't work over SSH without X forwarding)

### Permission issues

Some services may require root privileges to check status:

```bash
sudo ./service-monitor.sh status
```

However, most standard services can be checked by regular users.

## Tips

- **Start small** - Begin monitoring 3-5 critical services, add more as needed
- **Check interval** - Adjust `CHECK_INTERVAL` based on your needs (shorter = more responsive, longer = less resource usage)
- **Log rotation** - Consider setting up logrotate for the monitor.log file
- **Combine with other tools** - Use alongside monitoring stacks like Prometheus for comprehensive monitoring

## Contributing

Contributions welcome! Feel free to:

- Report bugs
- Suggest features
- Submit pull requests
- Improve documentation

## Roadmap

Future enhancements:

- [ ] Email notifications
- [ ] Slack/Discord webhook integration
- [ ] HTTP health check support
- [ ] Custom check intervals per service
- [ ] Web dashboard
- [ ] Metrics export (Prometheus format)
- [ ] Auto-restart failed services
- [ ] Service dependency tracking
- [ ] Multi-server monitoring

## License

MIT License - See LICENSE file for details

## Author

Created by [andrej4771](https://github.com/andrej4771)

## Related Projects

- [popos-power-manager](https://github.com/andrej4771/popos-power-manager) - Power management for Pop!_OS
- [system-administration](https://github.com/andrej4771/system-administration) - Ubuntu system administration guide
