#!/bin/bash

# Simple Wisecow Health Checker
# Compatible with all bash versions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo " Wisecow Simple Health Checker"
echo "================================="
echo " Started: $(date)"
echo ""

# Function to check HTTP endpoint
check_endpoint() {
    local name=$1
    local url=$2
    
    echo -n " Checking $name ($url)... "
    
    # Check if endpoint is reachable
    local response=$(curl -s -w "%{http_code}" -k --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
    local http_code="${response: -3}"
    
    # Extract response body (everything except last 3 characters)
    local response_body="${response%???}"
    
    if [[ "$http_code" == "200" ]]; then
        # Check if response contains wisecow content
        if echo "$response_body" | grep -q "cowsay\|fortune\|^<pre>"; then
            echo -e "${GREEN} OK${NC} - Wisecow responding"
            return 0
        else
            echo -e "${YELLOW}  WARN${NC} - HTTP 200 but no wisecow content"
            return 1
        fi
    else
        echo -e "${RED} FAILED${NC} - HTTP $http_code"
        return 1
    fi
}

# Function to check Kubernetes deployment
check_k8s_deployment() {
    local name="K8s-Deployment"
    
    echo -n " Checking $name... "
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED} FAILED${NC} - kubectl not found"
        return 1
    fi
    
    # Check if deployment exists and is ready
    local ready_replicas=$(kubectl get deployment wisecow-deployment -n wisecow -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired_replicas=$(kubectl get deployment wisecow-deployment -n wisecow -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    if [[ "$ready_replicas" == "$desired_replicas" && "$ready_replicas" != "0" ]]; then
        echo -e "${GREEN} OK${NC} - $ready_replicas/$desired_replicas pods ready"
        return 0
    else
        echo -e "${RED} FAILED${NC} - Only $ready_replicas/$desired_replicas pods ready"
        return 1
    fi
}

# Function to check Kubernetes pods
check_k8s_pods() {
    local name="K8s-Pods"
    
    echo -n " Checking $name... "
    
    running_pods=$(kubectl get pods -n wisecow -l app=wisecow --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    total_pods=$(kubectl get pods -n wisecow -l app=wisecow --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    
    if [[ "$running_pods" == "$total_pods" && "$running_pods" != "0" ]]; then
        echo -e "${GREEN} OK${NC} - $running_pods/$total_pods pods running"
        return 0
    else
        echo -e "${RED} FAILED${NC} - Only $running_pods/$total_pods pods running"
        return 1
    fi
}

# Function to check system resources
check_system_resources() {
    local name="System-Resources"
    
    echo -n " Checking $name... "
    
    # Get basic system info
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' | cut -d. -f1)
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [[ "$cpu_usage" -lt 80 && "$disk_usage" -lt 90 ]]; then
        echo -e "${GREEN} OK${NC} - CPU: ${cpu_usage}%, Disk: ${disk_usage}%"
        return 0
    else
        echo -e "${YELLOW}  WARN${NC} - CPU: ${cpu_usage}%, Disk: ${disk_usage}%"
        return 1
    fi
}

# Main health check
echo "🚀 Running Health Checks..."
echo "-------------------------"

# Initialize counters
passed=0
total=0

# Check HTTPS endpoint
total=$((total + 1))
if check_endpoint "HTTPS" "https://localhost:8443"; then
    passed=$((passed + 1))
fi

# Check HTTP port forward
total=$((total + 1))
if check_endpoint "HTTP-PortForward" "http://localhost:8080"; then
    passed=$((passed + 1))
fi

# Check Minikube service
total=$((total + 1))
if check_endpoint "Minikube-Service" "http://127.0.0.1:62985"; then
    passed=$((passed + 1))
fi

# Check Kubernetes deployment
total=$((total + 1))
if check_k8s_deployment; then
    passed=$((passed + 1))
fi

# Check Kubernetes pods
total=$((total + 1))
if check_k8s_pods; then
    passed=$((passed + 1))
fi

# Check system resources
total=$((total + 1))
if check_system_resources; then
    passed=$((passed + 1))
fi

# Generate summary
echo ""
echo " Health Check Summary"
echo "======================"
echo " Passed: $passed/$total"

health_percentage=$((passed * 100 / total))
echo " Health: $health_percentage%"

if [[ $health_percentage -ge 80 ]]; then
    echo -e "  ${GREEN} Status: EXCELLENT${NC}"
elif [[ $health_percentage -ge 60 ]]; then
    echo -e "  ${YELLOW} Status: GOOD${NC}"
else
    echo -e "  ${RED} Status: NEEDS ATTENTION${NC}"
fi

echo ""
echo " Quick Commands:"
echo "   HTTPS: curl -k https://localhost:8443"
echo "   HTTP:  curl http://localhost:8080"
echo "   Service: minikube service wisecow-service -n wisecow"
echo "   Pods: kubectl get pods -n wisecow"
echo ""
echo " Health check completed!"
