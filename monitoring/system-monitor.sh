#!/bin/bash

# Wisecow System Health Monitor
# This script monitors system resources for your Minikube cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="/tmp/wisecow-system.log"
ALERT_CPU_THRESHOLD=80
ALERT_MEMORY_THRESHOLD=85
ALERT_DISK_THRESHOLD=90
CHECK_INTERVAL=60  # seconds

# Kubernetes configuration
K8S_NAMESPACE="wisecow"
K8S_CONTEXT="minikube"

# Initialize per-check alert flags (0 = OK, 1 = ALERT)
ALERT_CPU=0
ALERT_MEMORY=0
ALERT_DISK=0
ALERT_K8S_CLUSTER=0
ALERT_K8S_RESOURCES=0
ALERT_PROCESSES=0
ALERT_NETWORK=0

echo " Wisecow System Health Monitor"
echo "================================="
echo " Started: $(date)"
echo " Log file: $LOG_FILE"
echo ""

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "ALERT") echo -e "${RED}[ALERT]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
        "OK") echo -e "${GREEN}[OK]${NC} $message" ;;
        *) echo -e "${CYAN}[$level]${NC} $message" ;;
    esac
}

# Function to check CPU usage
check_cpu_usage() {
    local name="CPU"
    
    # Get system CPU usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' | cut -d. -f1)
    
    # Get Minikube CPU usage if available
    local minikube_cpu=""
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        minikube_cpu=$(minikube ssh "cat /proc/loadavg" 2>/dev/null | awk '{print $1}' || echo "N/A")
    fi
    
    if [ "$cpu_usage" -gt "$ALERT_CPU_THRESHOLD" ]; then
        log_message "ALERT" "$name: HIGH USAGE - ${cpu_usage}% (Threshold: ${ALERT_CPU_THRESHOLD}%)"
        ALERT_CPU=1
        return 1
    else
        log_message "OK" "$name: Normal - ${cpu_usage}% (Load: ${minikube_cpu})"
        ALERT_CPU=0
        return 0
    fi
}

# Function to check memory usage
check_memory_usage() {
    local name="Memory"
    
    # Get system memory usage
    local memory_info=$(vm_stat | grep -E "(Pages free|Pages active|Pages inactive|Pages speculative|Pages wired down)")
    local pages_free=$(echo "$memory_info" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local pages_active=$(echo "$memory_info" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
    local pages_inactive=$(echo "$memory_info" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
    local pages_speculative=$(echo "$memory_info" | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')
    local pages_wired=$(echo "$memory_info" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
    
    # Calculate memory usage percentage
    local total_used=$((pages_active + pages_inactive + pages_speculative + pages_wired))
    local total_memory=$((total_used + pages_free))
    local memory_percentage=$((total_used * 100 / total_memory))
    
    # Get Minikube memory usage if available
    local minikube_mem=""
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        minikube_mem=$(minikube ssh "free -m | grep Mem" 2>/dev/null | awk '{printf "%.1f%%", $3/$2 * 100.0}' || echo "N/A")
    fi
    
    if [ "$memory_percentage" -gt "$ALERT_MEMORY_THRESHOLD" ]; then
        log_message "ALERT" "$name: HIGH USAGE - ${memory_percentage}% (Threshold: ${ALERT_MEMORY_THRESHOLD}%)"
        ALERT_MEMORY=1
        return 1
    else
        log_message "OK" "$name: Normal - ${memory_percentage}% (Minikube: ${minikube_mem})"
        ALERT_MEMORY=0
        return 0
    fi
}

# Function to check disk space
check_disk_space() {
    local name="Disk"
    
    # Get disk usage for main volume
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    # Get Minikube disk usage if available
    local minikube_disk=""
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        minikube_disk=$(minikube ssh "df -h / | tail -1" 2>/dev/null | awk '{print $5}' || echo "N/A")
    fi
    
    if [ "$disk_usage" -gt "$ALERT_DISK_THRESHOLD" ]; then
        log_message "ALERT" "$name: HIGH USAGE - ${disk_usage}% (Threshold: ${ALERT_DISK_THRESHOLD}%)"
        ALERT_DISK=1
        return 1
    else
        log_message "OK" "$name: Normal - ${disk_usage}% (Minikube: ${minikube_disk}%)"
        ALERT_DISK=0
        return 0
    fi
}

# Function to check Kubernetes cluster health
check_k8s_cluster() {
    local name="K8s-Cluster"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        log_message "ALERT" "$name: kubectl not found"
        ALERT_K8S_CLUSTER=1
        return 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_message "ALERT" "$name: Cannot connect to cluster"
        ALERT_K8S_CLUSTER=1
        return 1
    fi
    
    # Check node status
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
    local total_nodes=$(kubectl get nodes --no-headers | wc -l || echo "0")
    
    if [ "$ready_nodes" = "$total_nodes" ] && [ "$ready_nodes" != "0" ]; then
        log_message "OK" "$name: All $ready_nodes nodes ready"
        ALERT_K8S_CLUSTER=0
        return 0
    else
        log_message "ALERT" "$name: Only $ready_nodes/$total_nodes nodes ready"
        ALERT_K8S_CLUSTER=1
        return 1
    fi
}

# Function to check Kubernetes resource usage
check_k8s_resources() {
    local name="K8s-Resources"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        log_message "ALERT" "$name: kubectl not found"
        ALERT_K8S_RESOURCES=1
        return 1
    fi
    
    # Check if metrics-server is available
    if kubectl top nodes >/dev/null 2>&1; then
        # Get resource usage for wisecow namespace
        local cpu_usage=$(kubectl top pods -n $K8S_NAMESPACE --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum+0}' || echo "0")
        local mem_usage=$(kubectl top pods -n $K8S_NAMESPACE --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum+0}' || echo "0")
        
        log_message "OK" "$name: CPU: ${cpu_usage}m, Memory: ${mem_usage}Mi"
        ALERT_K8S_RESOURCES=0
        return 0
    else
        log_message "WARN" "$name: Metrics server not available"
        ALERT_K8S_RESOURCES=0
        return 0
    fi
}

# Function to check running processes
check_processes() {
    local name="Processes"
    
    # Count critical processes
    local docker_processes=$(ps aux | grep -c "[D]ocker" || echo "0")
    local kubectl_processes=$(ps aux | grep -c "[k]ubectl" || echo "0")
    local minikube_processes=$(ps aux | grep -c "[m]inikube" || echo "0")
    
    # Check if essential processes are running
    local issues=0
    
    if [ "$docker_processes" -eq 0 ]; then
        log_message "WARN" "$name: No Docker processes found"
        issues=$((issues + 1))
    fi
    
    if [ "$minikube_processes" -eq 0 ]; then
        log_message "WARN" "$name: No Minikube processes found"
        issues=$((issues + 1))
    fi
    
    if [ "$issues" -eq 0 ]; then
        log_message "OK" "$name: Docker: $docker_processes, Minikube: $minikube_processes, kubectl: $kubectl_processes"
        ALERT_PROCESSES=0
        return 0
    else
        log_message "WARN" "$name: $issues issues detected"
        ALERT_PROCESSES=1
        return 1
    fi
}

# Function to check network connectivity
check_network() {
    local name="Network"
    
    # Test local connectivity
    if ping -c 1 127.0.0.1 >/dev/null 2>&1; then
        local local_ping="OK"
    else
        local local_ping="FAILED"
    fi
    
    # Test external connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        local external_ping="OK"
    else
        local external_ping="FAILED"
    fi
    
    # Test Minikube connectivity
    local minikube_ip=$(minikube ip 2>/dev/null || echo "N/A")
    local minikube_ping="N/A"
    if [[ "$minikube_ip" != "N/A" ]]; then
        if ping -c 1 "$minikube_ip" >/dev/null 2>&1; then
            minikube_ping="OK"
        else
            minikube_ping="FAILED"
        fi
    fi
    
    if [ "$local_ping" = "OK" ] && [ "$external_ping" = "OK" ]; then
        log_message "OK" "$name: Local: $local_ping, External: $external_ping, Minikube: $minikube_ping ($minikube_ip)"
        ALERT_NETWORK=0
        return 0
    else
        log_message "ALERT" "$name: Connectivity issues - Local: $local_ping, External: $external_ping, Minikube: $minikube_ping"
        ALERT_NETWORK=1
        return 1
    fi
}

# Function to generate system report
generate_report() {
    echo ""
    echo " System Health Summary"
    echo "======================="
    
    local total_checks=0
    local passed_checks=0
    
    total_checks=7
    [ "$ALERT_CPU" -eq 0 ] && echo -e "  ${GREEN}${NC} CPU: Healthy" || echo -e "  ${RED}❌${NC} CPU: Issues"
    [ "$ALERT_MEMORY" -eq 0 ] && echo -e "  ${GREEN}${NC} Memory: Healthy" || echo -e "  ${RED}❌${NC} Memory: Issues"
    [ "$ALERT_DISK" -eq 0 ] && echo -e "  ${GREEN}${NC} Disk: Healthy" || echo -e "  ${RED}❌${NC} Disk: Issues"
    [ "$ALERT_K8S_CLUSTER" -eq 0 ] && echo -e "  ${GREEN}${NC} K8s-Cluster: Healthy" || echo -e "  ${RED}❌${NC} K8s-Cluster: Issues"
    [ "$ALERT_K8S_RESOURCES" -eq 0 ] && echo -e "  ${GREEN}${NC} K8s-Resources: Healthy" || echo -e "  ${RED}❌${NC} K8s-Resources: Issues"
    [ "$ALERT_PROCESSES" -eq 0 ] && echo -e "  ${GREEN}${NC} Processes: Healthy" || echo -e "  ${RED}❌${NC} Processes: Issues"
    [ "$ALERT_NETWORK" -eq 0 ] && echo -e "  ${GREEN}${NC} Network: Healthy" || echo -e "  ${RED}❌${NC} Network: Issues"

    passed_checks=$(( (1-ALERT_CPU) + (1-ALERT_MEMORY) + (1-ALERT_DISK) + (1-ALERT_K8S_CLUSTER) + (1-ALERT_K8S_RESOURCES) + (1-ALERT_PROCESSES) + (1-ALERT_NETWORK) ))
    
    local health_percentage=$((passed_checks * 100 / total_checks))
    echo ""
    echo " Overall System Health: $passed_checks/$total_checks ($health_percentage%)"
    
    if [ "$health_percentage" -ge 85 ]; then
        echo -e "  ${GREEN} Status: EXCELLENT${NC}"
    elif [ "$health_percentage" -ge 70 ]; then
        echo -e "  ${YELLOW} Status: GOOD${NC}"
    else
        echo -e "  ${RED} Status: NEEDS ATTENTION${NC}"
    fi
    
    # Show resource details
    echo ""
    echo " Resource Details"
    echo "=================="
    
    # CPU details
    local cpu_info=$(top -l 1 | grep "CPU usage")
    echo "  CPU: $cpu_info"
    
    # Memory details
    local mem_info=$(vm_stat | grep -E "(Pages free|Pages active)")
    echo " Memory: $(echo "$mem_info" | tr '\n' ' ')"
    
    # Disk details
    local disk_info=$(df -h / | tail -1)
    echo " Disk: $disk_info"
    
    # Minikube status
    if command -v minikube &> /dev/null; then
        echo " Minikube: $(minikube status --format '{{.Host}} {{.Kubelet}} {{.APIServer}}')"
    fi
}

# Main monitoring loop
monitor_loop() {
    echo " Starting continuous system monitoring (Press Ctrl+C to stop)"
    echo " Check interval: ${CHECK_INTERVAL}s"
    echo ""
    
    while true; do
        echo " System Check - $(date '+%H:%M:%S')"
        echo "----------------------------------------"
        
        # Run all checks
        check_cpu_usage
        check_memory_usage
        check_disk_space
        check_k8s_cluster
        check_k8s_resources
        check_processes
        check_network
        
        # Generate report
        generate_report
        
        # Check for critical alerts
        local critical_alerts=0
        [ "$ALERT_CPU" -gt 0 ] && critical_alerts=$((critical_alerts+1))
        [ "$ALERT_MEMORY" -gt 0 ] && critical_alerts=$((critical_alerts+1))
        [ "$ALERT_DISK" -gt 0 ] && critical_alerts=$((critical_alerts+1))
        [ "$ALERT_K8S_CLUSTER" -gt 0 ] && critical_alerts=$((critical_alerts+1))
        [ "$ALERT_K8S_RESOURCES" -gt 0 ] && critical_alerts=$((critical_alerts+1))
        [ "$ALERT_PROCESSES" -gt 0 ] && critical_alerts=$((critical_alerts+1))
        [ "$ALERT_NETWORK" -gt 0 ] && critical_alerts=$((critical_alerts+1))
        
        if [[ $critical_alerts -gt 0 ]]; then
            echo -e "${RED} ALERT: $critical_alerts system components need attention!${NC}"
        fi
        
        echo ""
        echo " Waiting ${CHECK_INTERVAL}s for next check..."
        echo "================================================"
        sleep $CHECK_INTERVAL
    done
}

# Single check mode
single_check() {
    echo " Single System Check"
    echo "====================="
    
    # Run all checks
    check_cpu_usage
    check_memory_usage
    check_disk_space
    check_k8s_cluster
    check_k8s_resources
    check_processes
    check_network
    
    # Generate report
    generate_report
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --continuous    Run continuous monitoring"
    echo "  -s, --single        Run single system check"
    echo "  -l, --log           Show recent log entries"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s              # Single system check"
    echo "  $0 -c              # Continuous monitoring"
    echo "  $0 -l              # Show recent logs"
}

# Show recent logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        echo " Recent System Monitor Logs"
        echo "============================"
        tail -20 "$LOG_FILE"
    else
        echo " No log file found at $LOG_FILE"
    fi
}

# Parse command line arguments
case "${1:-}" in
    -c|--continuous)
        monitor_loop
        ;;
    -s|--single)
        single_check
        ;;
    -l|--log)
        show_logs
        ;;
    -h|--help|"")
        show_usage
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
