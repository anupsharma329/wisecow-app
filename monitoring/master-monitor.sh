#!/bin/bash

# Wisecow Master Monitor
# This script combines application and system monitoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_CHECKER="$SCRIPT_DIR/health-checker.sh"
SYSTEM_MONITOR="$SCRIPT_DIR/system-monitor.sh"

echo "🐄 Wisecow Master Monitor"
echo "========================"
echo "📅 Started: $(date)"
echo ""

# Function to check if scripts exist
check_scripts() {
    if [[ ! -f "$HEALTH_CHECKER" ]]; then
        echo -e "${RED}❌ Health checker script not found: $HEALTH_CHECKER${NC}"
        exit 1
    fi
    
    if [[ ! -f "$SYSTEM_MONITOR" ]]; then
        echo -e "${RED}❌ System monitor script not found: $SYSTEM_MONITOR${NC}"
        exit 1
    fi
    
    if [[ ! -x "$HEALTH_CHECKER" ]]; then
        echo -e "${YELLOW}⚠️  Making health checker executable...${NC}"
        chmod +x "$HEALTH_CHECKER"
    fi
    
    if [[ ! -x "$SYSTEM_MONITOR" ]]; then
        echo -e "${YELLOW}⚠️  Making system monitor executable...${NC}"
        chmod +x "$SYSTEM_MONITOR"
    fi
}

# Function to show dashboard
show_dashboard() {
    echo "📊 Wisecow Monitoring Dashboard"
    echo "=============================="
    echo ""
    
    # Quick application check
    echo "🔍 Quick Application Check"
    echo "-------------------------"
    "$HEALTH_CHECKER" -s | grep -E "(✅|❌|Status:)"
    echo ""
    
    # Quick system check
    echo "🖥️  Quick System Check"
    echo "--------------------"
    "$SYSTEM_MONITOR" -s | grep -E "(✅|❌|Status:)"
    echo ""
}

# Function to run comprehensive check
run_comprehensive() {
    echo "🔍 Comprehensive Wisecow Health Check"
    echo "===================================="
    echo ""
    
    echo "1️⃣ Application Health Check"
    echo "---------------------------"
    "$HEALTH_CHECKER" -s
    echo ""
    
    echo "2️⃣ System Health Check"
    echo "----------------------"
    "$SYSTEM_MONITOR" -s
    echo ""
    
    echo "✅ Comprehensive check completed!"
}

# Function to start continuous monitoring
start_continuous() {
    echo "🔄 Starting Continuous Monitoring"
    echo "================================"
    echo "This will run both monitors in parallel"
    echo "Press Ctrl+C to stop all monitoring"
    echo ""
    
    # Start health checker in background
    echo "🚀 Starting Application Health Monitor..."
    "$HEALTH_CHECKER" -c &
    HEALTH_PID=$!
    
    # Start system monitor in background
    echo "🚀 Starting System Health Monitor..."
    "$SYSTEM_MONITOR" -c &
    SYSTEM_PID=$!
    
    echo ""
    echo "✅ Both monitors are now running!"
    echo "📝 Application logs: /tmp/wisecow-health.log"
    echo "📝 System logs: /tmp/wisecow-system.log"
    echo ""
    echo "Press Ctrl+C to stop all monitoring..."
    
    # Wait for interrupt
    trap 'echo ""; echo "🛑 Stopping all monitors..."; kill $HEALTH_PID $SYSTEM_PID 2>/dev/null; echo "✅ All monitors stopped"; exit 0' INT
    
    # Wait for processes
    wait $HEALTH_PID $SYSTEM_PID
}

# Function to show logs
show_logs() {
    echo "📋 Wisecow Monitoring Logs"
    echo "========================="
    echo ""
    
    echo "🔍 Application Health Logs"
    echo "-------------------------"
    if [[ -f "/tmp/wisecow-health.log" ]]; then
        tail -10 "/tmp/wisecow-health.log"
    else
        echo "No application health logs found"
    fi
    echo ""
    
    echo "🖥️  System Health Logs"
    echo "--------------------"
    if [[ -f "/tmp/wisecow-system.log" ]]; then
        tail -10 "/tmp/wisecow-system.log"
    else
        echo "No system health logs found"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  dashboard      Show monitoring dashboard"
    echo "  check          Run comprehensive health check"
    echo "  monitor        Start continuous monitoring"
    echo "  logs           Show recent logs"
    echo "  health         Run application health check only"
    echo "  system         Run system health check only"
    echo "  help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dashboard   # Quick status overview"
    echo "  $0 check       # Full health check"
    echo "  $0 monitor     # Start continuous monitoring"
    echo "  $0 logs        # Show recent logs"
}

# Main script logic
main() {
    check_scripts
    
    case "${1:-help}" in
        dashboard)
            show_dashboard
            ;;
        check)
            run_comprehensive
            ;;
        monitor)
            start_continuous
            ;;
        logs)
            show_logs
            ;;
        health)
            "$HEALTH_CHECKER" -s
            ;;
        system)
            "$SYSTEM_MONITOR" -s
            ;;
        help|--help|-h|"")
            show_usage
            ;;
        *)
            echo "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
