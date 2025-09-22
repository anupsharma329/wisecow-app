# 🚀 Wisecow Deployment Guide

This guide provides step-by-step instructions for deploying the Wisecow application in various environments.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Docker Deployment](#docker-deployment)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

## 📋 Prerequisites

### Required Tools
- **Docker**: For containerization
- **kubectl**: For Kubernetes management
- **Git**: For version control

### Optional Tools
- **minikube**: For local Kubernetes testing
- **kind**: Alternative local Kubernetes
- **helm**: For advanced deployments

### System Requirements
- **CPU**: 1 core minimum, 2 cores recommended
- **Memory**: 512MB minimum, 1GB recommended
- **Storage**: 1GB free space
- **Network**: Internet access for image pulls

## 🏠 Local Development

### Step 1: Clone Repository
```bash
git clone https://github.com/anupsharma329/wisecow-app.git
cd wisecow-app
```

### Step 2: Install Dependencies
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install fortune-mod cowsay -y

# macOS
brew install fortune cowsay

# Alpine Linux
apk add fortune cowsay
```

### Step 3: Run Application
```bash
# Make script executable
chmod +x wisecow.sh

# Run the application
./wisecow.sh
```

### Step 4: Test Application
```bash
# Test with curl
curl http://localhost:4499

# Or open in browser
open http://localhost:4499
```

## 🐳 Docker Deployment

### Step 1: Build Docker Image
```bash
# Build the image
docker build -t wisecow-app .

# Verify image
docker images | grep wisecow-app
```

### Step 2: Run Container
```bash
# Run with port mapping
docker run -d --name wisecow -p 4499:4499 wisecow-app

# Check container status
docker ps | grep wisecow

# View logs
docker logs wisecow
```

### Step 3: Test Application
```bash
# Test the application
curl http://localhost:4499

# Stop container
docker stop wisecow
docker rm wisecow
```

### Step 4: Push to Registry (Optional)
```bash
# Tag for registry
docker tag wisecow-app your-username/wisecow-app:latest

# Push to Docker Hub
docker push your-username/wisecow-app:latest
```

## ☸️ Kubernetes Deployment

### Option 1: Minikube (Local Testing)

#### Step 1: Start Minikube
```bash
# Start minikube
minikube start

# Verify cluster
kubectl cluster-info
```

#### Step 2: Deploy Application
```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Deploy application
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

#### Step 3: Access Application
```bash
# Get service URL
minikube service wisecow-service-nodeport -n wisecow --url

# Or use port-forward
kubectl port-forward svc/wisecow-service 8080:80 -n wisecow
```

### Option 2: Cloud Provider (Production)

#### Step 1: Configure kubectl
```bash
# For GKE
gcloud container clusters get-credentials CLUSTER_NAME --zone ZONE

# For EKS
aws eks update-kubeconfig --region REGION --name CLUSTER_NAME

# For AKS
az aks get-credentials --resource-group RESOURCE_GROUP --name CLUSTER_NAME
```

#### Step 2: Deploy with Kustomize
```bash
# Deploy all resources
kubectl apply -k k8s/

# Verify deployment
kubectl get all -n wisecow
```

#### Step 3: Configure LoadBalancer
```bash
# Apply LoadBalancer service
kubectl apply -f k8s/service-loadbalancer.yaml

# Get external IP
kubectl get svc wisecow-service-loadbalancer -n wisecow
```

### Option 3: Using Helm (Advanced)

#### Step 1: Create Helm Chart
```bash
# Create chart structure
helm create wisecow-chart

# Update values.yaml
cat > wisecow-chart/values.yaml << EOF
replicaCount: 3
image:
  repository: your-username/wisecow-app
  tag: latest
  pullPolicy: Always
service:
  type: ClusterIP
  port: 80
  targetPort: 4499
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: wisecow.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: wisecow-tls
      hosts:
        - wisecow.example.com
EOF
```

#### Step 2: Deploy with Helm
```bash
# Install chart
helm install wisecow wisecow-chart -n wisecow --create-namespace

# Upgrade chart
helm upgrade wisecow wisecow-chart -n wisecow
```

## 🌐 Production Deployment

### Step 1: Set Up TLS (Optional)
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s

# Deploy cluster issuer
kubectl apply -f k8s/cluster-issuer.yaml
```

### Step 2: Configure Ingress
```bash
# Update ingress with your domain
kubectl apply -f k8s/ingress.yaml

# Deploy certificate
kubectl apply -f k8s/certificate.yaml
```

### Step 3: Set Up Monitoring
```bash
# Deploy monitoring scripts
kubectl create configmap monitoring-scripts \
  --from-file=monitoring/ \
  -n wisecow

# Create monitoring job
kubectl apply -f - << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: monitoring-job
  namespace: wisecow
spec:
  template:
    spec:
      containers:
      - name: monitor
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Monitoring...'; sleep 60; done"]
      restartPolicy: OnFailure
EOF
```

### Step 4: Configure CI/CD
1. **Set up GitHub Secrets**:
   - `DOCKER_USERNAME`: Your Docker Hub username
   - `DOCKER_PASSWORD`: Your Docker Hub password/token

2. **Update deployment.yaml** with your image:
   ```yaml
   spec:
     containers:
     - name: wisecow
       image: your-username/wisecow-app:latest
   ```

3. **Push changes** to trigger CI/CD pipeline

## 🔧 Configuration Options

### Environment Variables
```yaml
# In configmap.yaml
data:
  SRVPORT: "4499"        # Server port
  RSPFILE: "response"    # Response file name
```

### Resource Limits
```yaml
# In deployment.yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

### Scaling
```bash
# Scale deployment
kubectl scale deployment wisecow-deployment --replicas=5 -n wisecow

# Auto-scaling (requires metrics-server)
kubectl autoscale deployment wisecow-deployment --min=2 --max=10 -n wisecow
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Pod Not Starting
```bash
# Check pod status
kubectl get pods -n wisecow

# Describe pod for details
kubectl describe pod <pod-name> -n wisecow

# Check logs
kubectl logs <pod-name> -n wisecow
```

#### 2. Service Not Accessible
```bash
# Check service
kubectl get svc -n wisecow

# Check endpoints
kubectl get endpoints -n wisecow

# Test with port-forward
kubectl port-forward svc/wisecow-service 8080:80 -n wisecow
```

#### 3. Image Pull Errors
```bash
# Check image
docker pull your-username/wisecow-app:latest

# Update image in deployment
kubectl set image deployment/wisecow-deployment wisecow=your-username/wisecow-app:latest -n wisecow
```

#### 4. TLS Certificate Issues
```bash
# Check certificate status
kubectl describe certificate wisecow-tls -n wisecow

# Check certificate requests
kubectl get certificaterequests -n wisecow

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

### Debug Commands
```bash
# Check all resources
kubectl get all -n wisecow

# Check events
kubectl get events -n wisecow --sort-by='.lastTimestamp'

# Check ingress
kubectl describe ingress wisecow-ingress -n wisecow

# Check configmap
kubectl describe configmap wisecow-config -n wisecow
```

### Performance Tuning
```bash
# Check resource usage
kubectl top pods -n wisecow

# Check node resources
kubectl top nodes

# Adjust resource limits in deployment.yaml
```

## 📊 Monitoring and Maintenance

### Health Checks
```bash
# Check application health
curl http://your-domain.com/health

# Check Kubernetes health
kubectl get pods -n wisecow -o wide
```

### Logs
```bash
# Application logs
kubectl logs -f deployment/wisecow-deployment -n wisecow

# System logs
kubectl logs -f -n kube-system -l component=kubelet
```

### Updates
```bash
# Update image
kubectl set image deployment/wisecow-deployment wisecow=your-username/wisecow-app:new-tag -n wisecow

# Rollback if needed
kubectl rollout undo deployment/wisecow-deployment -n wisecow
```

---

**Happy Deploying! 🚀**