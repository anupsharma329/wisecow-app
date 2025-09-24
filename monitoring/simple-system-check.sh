#!/bin/bash

# Simple Wisecow System Health Checker
# Compatible with all bash versions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "  Wisecow Simple System Health Checker"
echo "======================================="
echo " Started: $(date)"
echo ""

# Function to check CPU usage
check_cpu() {
    local name="CPU"
    
    echo -n " Checking $name... "
    
    # Get system CPU usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' | cut -d. -f1)
    
    if [[ "$cpu_usage" -gt 80 ]]; then
        echo -e "${RED}❌ HIGH${NC} - ${cpu_usage}% (Threshold: 80%)"
        return 1
    else
        echo -e "${GREEN} OK${NC} - ${cpu_usage}%"
        return 0
    fi
}

# Function to check memory usage
check_memory() {
    local name="Memory"
    
    echo -n " Checking $name... "
    
    # Get memory info using vm_stat
    local pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local pages_active=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
    local pages_inactive=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
    local pages_wired=$(vm_stat | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
    
    # Calculate memory usage percentage
    local total_used=$((pages_active + pages_inactive + pages_wired))
    local total_memory=$((total_used + pages_free))
    local memory_percentage=$((total_used * 100 / total_memory))
    
    if [[ "$memory_percentage" -gt 85 ]]; then
        echo -e "${RED}❌ HIGH${NC} - ${memory_percentage}% (Threshold: 85%)"
        return 1
    else
        echo -e "${GREEN} OK${NC} - ${memory_percentage}%"
        return 0
    fi
}

# Function to check disk space
check_disk() {
    local name="Disk"
    
    echo -n " Checking $name... "
    
    # Get disk usage for main volume
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [[ "$disk_usage" -gt 90 ]]; then
        echo -e "${RED}❌ HIGH${NC} - ${disk_usage}% (Threshold: 90%)"
        return 1
    else
        echo -e "${GREEN} OK${NC} - ${disk_usage}%"
        return 0
    fi
}

# Function to check Kubernetes cluster
check_k8s_cluster() {
    local name="K8s-Cluster"
    
    echo -n " Checking $name... "
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ FAILED${NC} - kubectl not found"
        return 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ FAILED${NC} - Cannot connect to cluster"
        return 1
    fi
    
    # Check node status
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
    local total_nodes=$(kubectl get nodes --no-headers | wc -l || echo "0")
    
    if [[ "$ready_nodes" == "$total_nodes" && "$ready_nodes" != "0" ]]; then
        echo -e "${GREEN} OK${NC} - All $ready_nodes nodes ready"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC} - Only $ready_nodes/$total_nodes nodes ready"
        return 1
    fi
}

# Function to check running processes
check_processes() {
    local name="Processes"
    
    echo -n " Checking $name... "
    
    # Count critical processes
    local docker_processes=$(ps aux | grep -c "[D]ocker" || echo "0")
    local kubectl_processes=$(ps aux | grep -c "[k]ubectl" || echo "0")
    local minikube_processes=$(ps aux | grep -c "[m]inikube" || echo "0")
    
    # Check if essential processes are running
    local issues=0
    
    if [[ "$docker_processes" -eq 0 ]]; then
        echo -e "${YELLOW}  WARN${NC} - No Docker processes found"
        return 1
    fi
    
    if [[ "$minikube_processes" -eq 0 ]]; then
        echo -e "${YELLOW}  WARN${NC} - No Minikube processes found"
        return 1
    fi
    
    echo -e "${GREEN} OK${NC} - Docker: $docker_processes, Minikube: $minikube_processes, kubectl: $kubectl_processes"
    return 0
}

# Function to check network connectivity
check_network() {
    local name="Network"
    
    echo -n " Checking $name... "
    
    # Test local connectivity
    if ping -c 1 127.0.0.1 &> /dev/null; then
        local local_ping="OK"
    else
        local local_ping="FAILED"
    fi
    
    # Test external connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        local external_ping="OK"
    else
        local external_ping="FAILED"
    fi
    
    # Test Minikube connectivity
    local minikube_ip=$(minikube ip 2>/dev/null || echo "N/A")
    local minikube_ping="N/A"
    if [[ "$minikube_ip" != "N/A" ]]; then
        if ping -c 1 "$minikube_ip" &> /dev/null; then
            minikube_ping="OK"
        else
            minikube_ping="FAILED"
        fi
    fi
    
    if [[ "$local_ping" == "OK" && "$external_ping" == "OK" ]]; then
        echo -e "${GREEN} OK${NC} - Local: $local_ping, External: $external_ping, Minikube: $minikube_ping ($minikube_ip)"
        return 0
    else
        echo -e "${RED} FAILED${NC} - Local: $local_ping, External: $external_ping, Minikube: $minikube_ping"
        return 1
    fi
}

# Main system check
echo "🚀 Running System Health Checks..."
echo "--------------------------------"

# Initialize counters
passed=0
total=0

# Check CPU
total=$((total + 1))
if check_cpu; then
    passed=$((passed + 1))
fi

# Check Memory
total=$((total + 1))
if check_memory; then
    passed=$((passed + 1))
fi

# Check Disk
total=$((total + 1))
if check_disk; then
    passed=$((passed + 1))
fi

# Check Kubernetes Cluster
total=$((total + 1))
if check_k8s_cluster; then
    passed=$((passed + 1))
fi

# Check Processes
total=$((total + 1))
if check_processes; then
    passed=$((passed + 1))
fi

# Check Network
total=$((total + 1))
if check_network; then
    passed=$((passed + 1))
fi

# Generate summary
echo ""
echo " System Health Summary"
echo "======================="
echo " Passed: $passed/$total"

health_percentage=$((passed * 100 / total))
echo " Health: $health_percentage%"

if [[ $health_percentage -ge 85 ]]; then
    echo -e "  ${GREEN} Status: EXCELLENT${NC}"
elif [[ $health_percentage -ge 70 ]]; then
    echo -e "  ${YELLOW} Status: GOOD${NC}"
else
    echo -e "  ${RED} Status: NEEDS ATTENTION${NC}"
fi

# Show resource details
echo ""
echo " Resource Details"
echo "=================="

# CPU details
cpu_info=$(top -l 1 | grep "CPU usage")
echo "  CPU: $cpu_info"

# Memory details
mem_info=$(vm_stat | grep -E "(Pages free|Pages active)")
echo " Memory: $(echo "$mem_info" | tr '\n' ' ')"

# Disk details
disk_info=$(df -h / | tail -1)
echo " Disk: $disk_info"

# Minikube status
if command -v minikube &> /dev/null; then
    echo " Minikube: $(minikube status --format '{{.Host}} {{.Kubelet}} {{.APIServer}}')"
fi

echo ""
echo " Quick Commands:"
echo "   Pods: kubectl get pods -n wisecow"
echo "   Nodes: kubectl get nodes"
echo "   Resources: kubectl top pods -n wisecow"
echo ""
echo " System health check completed!"
