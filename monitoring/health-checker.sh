#!/bin/bash

# Wisecow Application Health Checker
# This script monitors the health of your Wisecow application endpoints

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
LOG_FILE="/tmp/wisecow-health.log"
ALERT_THRESHOLD_RESPONSE_TIME=5  # seconds
CHECK_INTERVAL=30  # seconds
MAX_FAILURES=3

# Endpoints to check
ENDPOINTS_HTTPS="https://localhost:8443"
ENDPOINTS_HTTP_PORTFORWARD="http://localhost:8080"
ENDPOINTS_MINIKUBE_SERVICE="http://127.0.0.1:62985"

# Kubernetes resources to check
K8S_NAMESPACE="wisecow"
DEPLOYMENT_NAME="wisecow-deployment"
SERVICE_NAME="wisecow-service"

# Initialize counters
FAILURE_COUNT_HTTPS=0
FAILURE_COUNT_HTTP_PORTFORWARD=0
FAILURE_COUNT_MINIKUBE_SERVICE=0
FAILURE_COUNT_K8S_DEPLOYMENT=0
FAILURE_COUNT_K8S_SERVICE=0
FAILURE_COUNT_K8S_PODS=0

echo "🐄 Wisecow Application Health Checker"
echo "====================================="
echo "📅 Started: $(date)"
echo "📝 Log file: $LOG_FILE"
echo ""

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case $level in
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        *) echo -e "${CYAN}[$level]${NC} $message" ;;
    esac
}

# Function to check HTTP endpoint
check_endpoint() {
    local name=$1
    local url=$2
    local start_time=$(date +%s)
    
    # Check if endpoint is reachable
    local response=$(curl -s -w "%{http_code}" -k --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
    local http_code="${response: -3}"
    local end_time=$(date +%s)
    local response_time=$((end_time - start_time))
    
    # Extract response body (everything except last 3 characters)
    local response_body="${response%???}"
    
    if [[ "$http_code" == "200" ]]; then
        # Check if response contains wisecow content
        if echo "$response_body" | grep -q "cowsay\|fortune\|^<pre>"; then
            log_message "SUCCESS" "$name: OK (HTTP $http_code, ${response_time}s) - Wisecow responding"
            FAILURE_COUNT[$name]=0
            return 0
        else
            log_message "WARN" "$name: HTTP $http_code but no wisecow content detected"
            FAILURE_COUNT[$name]=$((FAILURE_COUNT[$name] + 1))
            return 1
        fi
    else
        log_message "ERROR" "$name: HTTP $http_code - Endpoint not responding"
        FAILURE_COUNT[$name]=$((FAILURE_COUNT[$name] + 1))
        return 1
    fi
}

# Function to check Kubernetes deployment
check_k8s_deployment() {
    local name="K8s-Deployment"
    
    if ! command -v kubectl &> /dev/null; then
        log_message "ERROR" "$name: kubectl not found"
        FAILURE_COUNT[$name]=$((FAILURE_COUNT[$name] + 1))
        return 1
    fi
    
    # Check if deployment exists and is ready
    local ready_replicas=$(kubectl get deployment $DEPLOYMENT_NAME -n $K8S_NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired_replicas=$(kubectl get deployment $DEPLOYMENT_NAME -n $K8S_NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    if [[ "$ready_replicas" == "$desired_replicas" && "$ready_replicas" != "0" ]]; then
        log_message "SUCCESS" "$name: OK - $ready_replicas/$desired_replicas pods ready"
        FAILURE_COUNT[$name]=0
        return 0
    else
        log_message "ERROR" "$name: Only $ready_replicas/$desired_replicas pods ready"
        FAILURE_COUNT[$name]=$((FAILURE_COUNT[$name] + 1))
        return 1
    fi
}

# Function to check Kubernetes service
check_k8s_service() {
    local name="K8s-Service"
    
    local service_status=$(kubectl get service $SERVICE_NAME -n $K8S_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "none")
    local service_type=$(kubectl get service $SERVICE_NAME -n $K8S_NAMESPACE -o jsonpath='{.spec.type}' 2>/dev/null || echo "none")
    
    if [[ "$service_status" != "none" || "$service_type" == "ClusterIP" ]]; then
        log_message "SUCCESS" "$name: OK - Service is running ($service_type)"
        FAILURE_COUNT[$name]=0
        return 0
    else
        log_message "ERROR" "$name: Service not accessible"
        FAILURE_COUNT[$name]=$((FAILURE_COUNT[$name] + 1))
        return 1
    fi
}

# Function to check pod health
check_k8s_pods() {
    local name="K8s-Pods"
    
    local running_pods=$(kubectl get pods -n $K8S_NAMESPACE -l app=wisecow --no-headers | grep -c "Running" || echo "0")
    local total_pods=$(kubectl get pods -n $K8S_NAMESPACE -l app=wisecow --no-headers | wc -l || echo "0")
    
    if [[ "$running_pods" == "$total_pods" && "$running_pods" != "0" ]]; then
        log_message "SUCCESS" "$name: OK - $running_pods/$total_pods pods running"
        FAILURE_COUNT[$name]=0
        return 0
    else
        log_message "ERROR" "$name: Only $running_pods/$total_pods pods running"
        FAILURE_COUNT[$name]=$((FAILURE_COUNT[$name] + 1))
        return 1
    fi
}

# Function to generate health report
generate_report() {
    echo ""
    echo "📊 Health Check Summary"
    echo "======================"
    
    local total_checks=0
    local passed_checks=0
    
    for endpoint in "${!ENDPOINTS[@]}"; do
        total_checks=$((total_checks + 1))
        if [[ ${FAILURE_COUNT[$endpoint]} -eq 0 ]]; then
            echo -e "  ${GREEN}✅${NC} $endpoint: Healthy"
            passed_checks=$((passed_checks + 1))
        else
            echo -e "  ${RED}❌${NC} $endpoint: Failed (${FAILURE_COUNT[$endpoint]} consecutive failures)"
        fi
    done
    
    # Kubernetes checks
    for check in "K8s-Deployment" "K8s-Service" "K8s-Pods"; do
        total_checks=$((total_checks + 1))
        if [[ ${FAILURE_COUNT[$check]} -eq 0 ]]; then
            echo -e "  ${GREEN}✅${NC} $check: Healthy"
            passed_checks=$((passed_checks + 1))
        else
            echo -e "  ${RED}❌${NC} $check: Failed (${FAILURE_COUNT[$check]} consecutive failures)"
        fi
    done
    
    local health_percentage=$((passed_checks * 100 / total_checks))
    echo ""
    echo "📈 Overall Health: $passed_checks/$total_checks ($health_percentage%)"
    
    if [[ $health_percentage -ge 80 ]]; then
        echo -e "  ${GREEN}🟢 Status: EXCELLENT${NC}"
    elif [[ $health_percentage -ge 60 ]]; then
        echo -e "  ${YELLOW}🟡 Status: GOOD${NC}"
    else
        echo -e "  ${RED}🔴 Status: POOR${NC}"
    fi
}

# Main monitoring loop
monitor_loop() {
    echo "🔄 Starting continuous monitoring (Press Ctrl+C to stop)"
    echo "⏰ Check interval: ${CHECK_INTERVAL}s"
    echo ""
    
    while true; do
        echo "🔍 Health Check - $(date '+%H:%M:%S')"
        echo "----------------------------------------"
        
        # Check HTTP endpoints
        for endpoint_name in "${!ENDPOINTS[@]}"; do
            check_endpoint "$endpoint_name" "${ENDPOINTS[$endpoint_name]}"
        done
        
        # Check Kubernetes resources
        check_k8s_deployment
        check_k8s_service
        check_k8s_pods
        
        # Generate report
        generate_report
        
        # Check for critical failures
        local critical_failures=0
        for check in "${!FAILURE_COUNT[@]}"; do
            if [[ ${FAILURE_COUNT[$check]} -ge $MAX_FAILURES ]]; then
                critical_failures=$((critical_failures + 1))
                log_message "ERROR" "CRITICAL: $check has failed $MAX_FAILURES times consecutively!"
            fi
        done
        
        if [[ $critical_failures -gt 0 ]]; then
            echo -e "${RED}🚨 CRITICAL ALERT: $critical_failures components have critical failures!${NC}"
        fi
        
        echo ""
        echo "⏳ Waiting ${CHECK_INTERVAL}s for next check..."
        echo "================================================"
        sleep $CHECK_INTERVAL
    done
}

# Single check mode
single_check() {
    echo "🔍 Single Health Check"
    echo "====================="
    
    # Check HTTP endpoints
    for endpoint_name in "${!ENDPOINTS[@]}"; do
        check_endpoint "$endpoint_name" "${ENDPOINTS[$endpoint_name]}"
    done
    
    # Check Kubernetes resources
    check_k8s_deployment
    check_k8s_service
    check_k8s_pods
    
    # Generate report
    generate_report
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --continuous    Run continuous monitoring"
    echo "  -s, --single        Run single health check"
    echo "  -l, --log           Show recent log entries"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s              # Single health check"
    echo "  $0 -c              # Continuous monitoring"
    echo "  $0 -l              # Show recent logs"
}

# Show recent logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "📋 Recent Health Check Logs"
        echo "=========================="
        tail -20 "$LOG_FILE"
    else
        echo "📋 No log file found at $LOG_FILE"
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
