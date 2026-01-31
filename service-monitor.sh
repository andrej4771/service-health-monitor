#!/bin/bash
#
# Service Health Monitor
# Monitor systemd services and get notified when they fail
#
# Author: andrej4771
# License: MIT

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/services.conf"
LOG_FILE="${SCRIPT_DIR}/monitor.log"
STATE_FILE="${SCRIPT_DIR}/.service_states"
CHECK_INTERVAL=30  # seconds between checks

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

# Initialize state file
init_state_file() {
    if [[ ! -f "$STATE_FILE" ]]; then
        touch "$STATE_FILE"
        log "INFO" "Created state file: $STATE_FILE"
    fi
}

# Get previous state of a service
get_previous_state() {
    local service="$1"
    grep "^${service}:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 || echo "unknown"
}

# Save current state of a service
save_state() {
    local service="$1"
    local state="$2"
    
    # Remove old entry
    sed -i "/^${service}:/d" "$STATE_FILE" 2>/dev/null || true
    # Add new entry
    echo "${service}:${state}" >> "$STATE_FILE"
}

# Check if service exists
service_exists() {
    local service="$1"
    systemctl list-unit-files "${service}.service" &>/dev/null
}

# Get service status
get_service_status() {
    local service="$1"
    
    if ! service_exists "$service"; then
        echo "not-found"
        return
    fi
    
    if systemctl is-active --quiet "$service"; then
        echo "active"
    elif systemctl is-failed --quiet "$service"; then
        echo "failed"
    else
        echo "inactive"
    fi
}

# Send desktop notification
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"  # low, normal, critical
    
    # Try notify-send (most common)
    if command -v notify-send &> /dev/null; then
        notify-send -u "$urgency" "$title" "$message"
        return 0
    fi
    
    # Fallback: just log it
    log "NOTIFICATION" "$title: $message"
    return 1
}

# Send alert for service state change
send_alert() {
    local service="$1"
    local old_state="$2"
    local new_state="$3"
    
    local title="Service Alert: $service"
    local message=""
    local urgency="normal"
    
    case "$new_state" in
        "active")
            if [[ "$old_state" == "failed" || "$old_state" == "inactive" ]]; then
                message="✓ Service is now RUNNING"
                urgency="normal"
                log "INFO" "$service: $old_state -> $new_state (recovered)"
            fi
            ;;
        "failed")
            message="✗ Service has FAILED"
            urgency="critical"
            log "ERROR" "$service: $old_state -> $new_state (FAILED)"
            ;;
        "inactive")
            message="○ Service is STOPPED"
            urgency="normal"
            log "WARN" "$service: $old_state -> $new_state (stopped)"
            ;;
        "not-found")
            message="? Service NOT FOUND"
            urgency="normal"
            log "WARN" "$service: Service does not exist"
            ;;
    esac
    
    if [[ -n "$message" ]]; then
        send_notification "$title" "$message" "$urgency"
    fi
}

# Check a single service
check_service() {
    local service="$1"
    local current_state=$(get_service_status "$service")
    local previous_state=$(get_previous_state "$service")
    
    # State changed - send alert
    if [[ "$current_state" != "$previous_state" ]]; then
        send_alert "$service" "$previous_state" "$current_state"
        save_state "$service" "$current_state"
    fi
    
    echo "$current_state"
}

# Load services from config file
load_services() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "ERROR" "Config file not found: $CONFIG_FILE"
        echo -e "${RED}Error: Config file not found: $CONFIG_FILE${NC}"
        echo "Create it with: echo 'ssh' > $CONFIG_FILE"
        exit 1
    fi
    
    # Read services (ignore comments and empty lines)
    grep -v '^#' "$CONFIG_FILE" | grep -v '^[[:space:]]*$' || true
}

# Display status of all services
show_status() {
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║    Service Health Monitor Status     ║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}\n"
    
    local services=$(load_services)
    
    if [[ -z "$services" ]]; then
        echo -e "${YELLOW}No services configured${NC}"
        return
    fi
    
    printf "%-30s %s\n" "SERVICE" "STATUS"
    printf "%-30s %s\n" "-------" "------"
    
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        
        local status=$(get_service_status "$service")
        local status_display=""
        
        case "$status" in
            "active")
                status_display="${GREEN}✓ RUNNING${NC}"
                ;;
            "failed")
                status_display="${RED}✗ FAILED${NC}"
                ;;
            "inactive")
                status_display="${YELLOW}○ STOPPED${NC}"
                ;;
            "not-found")
                status_display="${RED}? NOT FOUND${NC}"
                ;;
        esac
        
        printf "%-30s " "$service"
        echo -e "$status_display"
    done <<< "$services"
}

# Monitor services in a loop
monitor_loop() {
    echo -e "${GREEN}Starting service monitor...${NC}"
    echo -e "Checking services every ${CHECK_INTERVAL} seconds"
    echo -e "Press Ctrl+C to stop\n"
    
    init_state_file
    local services=$(load_services)
    
    if [[ -z "$services" ]]; then
        echo -e "${RED}No services to monitor!${NC}"
        exit 1
    fi
    
    log "INFO" "Monitor started"
    
    # Initial check
    echo "Performing initial check..."
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        local status=$(check_service "$service")
        echo "  $service: $status"
    done <<< "$services"
    
    echo -e "\n${GREEN}Monitoring active. Watching for changes...${NC}\n"
    
    # Main monitoring loop
    while true; do
        sleep "$CHECK_INTERVAL"
        
        while IFS= read -r service; do
            [[ -z "$service" ]] && continue
            check_service "$service" > /dev/null
        done <<< "$services"
    done
}

# Create example config file
create_example_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Service Health Monitor Configuration
# Add one service name per line (without .service extension)
# Lines starting with # are comments

# Common system services
ssh
cron

# Web servers (uncomment if you use them)
# nginx
# apache2

# Database servers (uncomment if you use them)
# mysql
# postgresql
# mongodb

# Docker (uncomment if you use it)
# docker

# Add your custom services below:

EOF
    echo -e "${GREEN}Created example config: $CONFIG_FILE${NC}"
    echo "Edit this file to add services you want to monitor"
}

# Add service to config
add_service() {
    local service="$1"
    
    if ! service_exists "$service"; then
        echo -e "${RED}Warning: Service '$service' does not exist on this system${NC}"
        read -p "Add it anyway? (y/n) " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    fi
    
    # Check if already in config
    if grep -q "^${service}$" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Service '$service' already in config${NC}"
        return 1
    fi
    
    echo "$service" >> "$CONFIG_FILE"
    echo -e "${GREEN}Added '$service' to monitoring${NC}"
    log "INFO" "Added service to config: $service"
}

# Remove service from config
remove_service() {
    local service="$1"
    
    if ! grep -q "^${service}$" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Service '$service' not in config${NC}"
        return 1
    fi
    
    sed -i "/^${service}$/d" "$CONFIG_FILE"
    echo -e "${GREEN}Removed '$service' from monitoring${NC}"
    log "INFO" "Removed service from config: $service"
}

# List monitored services
list_services() {
    echo -e "${BOLD}${CYAN}Monitored Services:${NC}\n"
    
    local services=$(load_services)
    
    if [[ -z "$services" ]]; then
        echo -e "${YELLOW}No services configured${NC}"
        echo "Add services with: $0 add <service-name>"
        return
    fi
    
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        echo "  • $service"
    done <<< "$services"
}

# Show logs
show_logs() {
    local lines="${1:-50}"
    
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}No logs yet${NC}"
        return
    fi
    
    echo -e "${BOLD}${CYAN}Recent Logs (last $lines lines):${NC}\n"
    tail -n "$lines" "$LOG_FILE"
}

# Test notifications
test_notification() {
    echo "Testing notification system..."
    
    if send_notification "Service Health Monitor" "Test notification - if you see this, notifications are working!" "normal"; then
        echo -e "${GREEN}✓ Notification sent successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Notification system not available${NC}"
        echo "Install notify-send: sudo apt install libnotify-bin"
    fi
}

# Show help
show_help() {
    cat << EOF
${BOLD}Service Health Monitor${NC}

A systemd service monitoring tool with desktop notifications.

${BOLD}Usage:${NC}
  $0 [command] [options]

${BOLD}Commands:${NC}
  monitor              Start monitoring services (default)
  status               Show current status of all services
  add <service>        Add a service to monitor
  remove <service>     Remove a service from monitoring
  list                 List all monitored services
  logs [lines]         Show recent logs (default: 50 lines)
  test                 Test notification system
  init                 Create example config file
  help                 Show this help message

${BOLD}Examples:${NC}
  $0                   # Start monitoring
  $0 status            # Check current status
  $0 add nginx         # Add nginx to monitoring
  $0 remove ssh        # Remove ssh from monitoring
  $0 logs 100          # Show last 100 log lines

${BOLD}Configuration:${NC}
  Config file: $CONFIG_FILE
  Log file:    $LOG_FILE
  State file:  $STATE_FILE

${BOLD}Setup:${NC}
  1. Run '$0 init' to create example config
  2. Edit $CONFIG_FILE to add your services
  3. Run '$0 monitor' to start monitoring

EOF
}

# Main
main() {
    local command="${1:-monitor}"
    
    case "$command" in
        monitor|start|run)
            monitor_loop
            ;;
        status)
            show_status
            ;;
        add)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 add <service-name>"
                exit 1
            fi
            [[ ! -f "$CONFIG_FILE" ]] && create_example_config
            add_service "$2"
            ;;
        remove|rm)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 remove <service-name>"
                exit 1
            fi
            remove_service "$2"
            ;;
        list|ls)
            list_services
            ;;
        logs|log)
            show_logs "${2:-50}"
            ;;
        test)
            test_notification
            ;;
        init|setup)
            create_example_config
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
