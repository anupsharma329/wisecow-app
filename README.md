# 🐄 Wisecow - Kubernetes Wisdom Server

A containerized web application that serves random wisdom quotes using `fortune` and `cowsay` commands, deployed on Kubernetes with full CI/CD pipeline and TLS support.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Options](#deployment-options)
- [TLS Configuration](#tls-configuration)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🎯 Overview

Wisecow is a simple HTTP server that:
- Serves random wisdom quotes using `fortune` and `cowsay`
- Runs on port 4499
- Provides health checks and monitoring
- Supports both HTTP and HTTPS (TLS)
- Deploys on Kubernetes with multiple service types

## ✨ Features

- 🐄 **Wisdom Server**: Random quotes served with ASCII art cows
- 🐳 **Dockerized**: Alpine-based container for minimal footprint
- ☸️ **Kubernetes Ready**: Full K8s manifests with multiple service types
- 🔒 **TLS Support**: Automatic SSL certificate management with Let's Encrypt
- 🚀 **CI/CD Pipeline**: Automated build and deployment with GitHub Actions
- 📊 **Monitoring**: Health checks and system monitoring scripts
- 🔧 **Configurable**: Environment-based configuration via ConfigMap

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Ingress       │────│   LoadBalancer   │────│   NodePort      │
│   (TLS/HTTP)    │    │   Service        │    │   Service       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   ClusterIP     │
                    │   Service       │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Deployment    │
                    │   (3 replicas)  │
                    └─────────────────┘
```

## 📋 Prerequisites

### Local Development
```bash
# Ubuntu/Debian
sudo apt install fortune-mod cowsay -y

# macOS
brew install fortune cowsay

# Alpine Linux
apk add fortune cowsay
```

### Kubernetes Deployment
- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- Docker Hub account (for CI/CD)

### TLS Setup (Optional)
- cert-manager installed in cluster
- Domain name configured
- DNS pointing to cluster

## 🚀 Quick Start

### 1. Local Development
```bash
# Clone the repository
git clone https://github.com/anupsharma329/wisecow-app.git
cd wisecow-app

# Make script executable
chmod +x wisecow.sh

# Run locally
./wisecow.sh
```

Visit: `http://localhost:4499`

### 2. Docker
```bash
# Build image
docker build -t wisecow-app .

# Run container
docker run -p 4499:4499 wisecow-app
```

### 3. Kubernetes (Minikube)
```bash
# Start minikube
minikube start

# Deploy application
kubectl apply -f k8s/

# Get service URL
minikube service wisecow-service-nodeport -n wisecow --url
```

## 🚀 Deployment Options

### Option 1: Basic Deployment
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### Option 2: Using Kustomize
```bash
kubectl apply -k k8s/
```

### Option 3: With TLS (Production)
```bash
# Install cert-manager first
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Deploy with TLS
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/certificate.yaml
```

## 🔒 TLS Configuration

### Prerequisites
1. Install cert-manager in your cluster
2. Configure DNS for your domain
3. Update ingress.yaml with your domain

### Setup Steps
1. **Install cert-manager**:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. **Configure ClusterIssuer**:
   ```bash
   kubectl apply -f k8s/cluster-issuer.yaml
   ```

3. **Update domain in ingress.yaml**:
   ```yaml
   spec:
     tls:
     - hosts:
       - your-domain.com
       secretName: wisecow-tls
   ```

4. **Deploy with TLS**:
   ```bash
   kubectl apply -f k8s/ingress.yaml
   kubectl apply -f k8s/certificate.yaml
   ```

## 🚀 CI/CD Pipeline

### GitHub Actions Setup

1. **Configure Secrets** in GitHub repository:
   - `DOCKER_USERNAME`: Your Docker Hub username
   - `DOCKER_PASSWORD`: Your Docker Hub password/token

2. **Pipeline Features**:
   - ✅ Automatic build on push to main
   - ✅ Docker image build and push
   - ✅ Multi-architecture support
   - ✅ Image caching for faster builds
   - ✅ Deployment file updates

### Manual Deployment
After CI/CD builds the image:
```bash
# Update deployment with new image
kubectl set image deployment/wisecow-deployment wisecow=your-username/wisecow-app:latest -n wisecow

# Or apply the updated deployment file
kubectl apply -f k8s/deployment.yaml
```

## 📊 Monitoring

### Health Checks
- **Liveness Probe**: TCP check on port 4499
- **Readiness Probe**: TCP check on port 4499
- **Container Health Check**: Built-in Docker health check

### Monitoring Scripts
```bash
# System health check
./monitoring/simple-health-check.sh

# Master monitoring
./monitoring/master-monitor.sh

# System monitoring
./monitoring/system-monitor.sh
```

### Service Status
```bash
# Check pods
kubectl get pods -n wisecow

# Check services
kubectl get svc -n wisecow

# Check ingress
kubectl get ingress -n wisecow
```

## 🔧 Configuration

### Environment Variables
- `SRVPORT`: Server port (default: 4499)
- `RSPFILE`: Response file name (default: response)

### ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: wisecow-config
  namespace: wisecow
data:
  SRVPORT: "4499"
  RSPFILE: "response"
```

## 🐛 Troubleshooting

### Common Issues

1. **Pod not starting**:
   ```bash
   kubectl describe pod -n wisecow <pod-name>
   kubectl logs -n wisecow <pod-name>
   ```

2. **Service not accessible**:
   ```bash
   kubectl get svc -n wisecow
   kubectl port-forward svc/wisecow-service 8080:80 -n wisecow
   ```

3. **TLS certificate issues**:
   ```bash
   kubectl describe certificate -n wisecow
   kubectl get certificaterequests -n wisecow
   ```

4. **Image pull errors**:
   ```bash
   kubectl describe pod -n wisecow <pod-name>
   # Check if image exists in Docker Hub
   docker pull your-username/wisecow-app:latest
   ```

### Debug Commands
```bash
# Check all resources
kubectl get all -n wisecow

# Check events
kubectl get events -n wisecow --sort-by='.lastTimestamp'

# Check logs
kubectl logs -f deployment/wisecow-deployment -n wisecow
```

## 📁 Project Structure

```
wisecow-app/
├── .github/
│   └── workflows/
│       └── ci-cd.yml              # GitHub Actions pipeline
├── k8s/                           # Kubernetes manifests
│   ├── namespace.yaml             # Namespace definition
│   ├── configmap.yaml             # Configuration
│   ├── deployment.yaml            # Application deployment
│   ├── service.yaml               # ClusterIP service
│   ├── service-nodeport.yaml      # NodePort service
│   ├── service-loadbalancer.yaml  # LoadBalancer service
│   ├── ingress.yaml               # Ingress with TLS
│   ├── certificate.yaml           # TLS certificate
│   ├── cluster-issuer.yaml        # cert-manager issuer
│   └── kustomization.yaml         # Kustomize config
├── monitoring/                    # Monitoring scripts
│   ├── health-checker.sh
│   ├── master-monitor.sh
│   └── system-monitor.sh
├── wisecow.sh                     # Main application script
├── Dockerfile                     # Container definition
└── README.md                      # This file
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original concept by [nyrahul](https://github.com/nyrahul/wisecow)
- Built with `fortune` and `cowsay` utilities
- Containerized with Alpine Linux
- Deployed on Kubernetes

---

**Happy Wisdom Serving! 🐄✨**