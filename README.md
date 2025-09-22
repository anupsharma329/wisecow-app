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
  - [Argo CD (GitOps)](#argo-cd-gitops)
  - [Direct deploy with kubeconfig (optional)](#direct-deploy-with-kubeconfig-optional)
  - [Semantic version releases](#semantic-version-releases)
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
Client (Browser/curl)
        │  HTTPS (TLS) / HTTP
        ▼
┌──────────────────────────┐
│ Ingress (nginx, optional)│  ← TLS terminates here (wisecow-tls)
└─────────────┬────────────┘
              │ routes host/path
              ▼
┌──────────────────────────┐
│ Service                  │  ← One of: ClusterIP (default inside cluster),
│  - ClusterIP / NodePort  │            NodePort (minikube access),
│  - LoadBalancer (tunnel) │            LoadBalancer (via minikube tunnel)
└─────────────┬────────────┘
              │ selects app=wisecow
              ▼
┌──────────────────────────┐
│ Deployment (3 replicas)  │  ← Pods listen on 4499
│  Pods: wisecow containers│
└──────────────────────────┘
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
- Argo CD installed (recommended for CD)
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

# Install Argo CD (one-time)
kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create Argo CD Application (points to k8s/)
kubectl apply -f k8s/argocd-application.yaml

# Sync once (or wait for auto-sync)
argocd app sync wisecow || true
```

## 🚀 Deployment Options

### Option 1: Basic Deployment
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service-nodeport.yaml
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
1. For local Minikube: use a local TLS secret (mkcert/self-signed)
2. For public cloud: install cert-manager and point DNS to your ingress
3. Update ingress.yaml hosts to match your domain/host

### Setup Steps
1. **Install cert-manager**:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. **Configure ClusterIssuer**:
   ```bash
   kubectl apply -f k8s/cluster-issuer.yaml
   ```

3. **Update domain/host in ingress.yaml**:
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

### TLS for local Minikube (mkcert)
```bash
brew install mkcert nss  # macOS
mkcert -install
mkcert wisecow.local
kubectl -n wisecow create secret tls wisecow-tls \
  --cert=wisecow.local.pem --key=wisecow.local-key.pem \
  --dry-run=client -o yaml | kubectl apply -f -
echo "$(minikube ip) wisecow.local" | sudo tee -a /etc/hosts
curl -vk https://wisecow.local/
```

## 🚀 CI/CD Pipeline

### GitHub Actions Setup

1. **Configure Secrets** in GitHub repository:
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Your Docker Hub access token
   - Optional (only for manual kubeconfig deploy): `KUBECONFIG_B64`

2. **Pipeline Features**:
   - ✅ Automatic build on push to main
   - ✅ Docker image build and push (multi-arch: amd64+arm64)
   - ✅ Updates `k8s/deployment.yaml` with the new image tag
   - ✅ Argo CD auto-sync deploys changes (GitOps)
   - ✅ Optional manual direct deploy with kubeconfig

### Argo CD (GitOps)
- App manifest: `k8s/argocd-application.yaml` (auto-sync, self-heal, kustomize)
- Default flow: CI commits a new image tag to `k8s/deployment.yaml` → Argo CD detects Git change → deploys

### Direct deploy with kubeconfig (optional)
- Workflow dispatch input `use_kubeconfig=true` writes `KUBECONFIG_B64` and runs `kubectl apply -f k8s/`.
- Use only when Argo CD is unavailable; GitOps is preferred.

### Semantic version releases
- Push a Git tag `vX.Y.Z` to publish `:vX.Y.Z` and `:latest`, and write that tag into `k8s/deployment.yaml`.
```bash
git tag v1.0.0
git push origin v1.0.0
```

### Accessing the app locally
- Exact LAN port 4499 on your Mac (recommended):
```bash
kubectl -n wisecow port-forward --address 0.0.0.0 svc/wisecow-service-nodeport 4499:4499
open http://127.0.0.1:4499/
```
- Via NodePort on Minikube VM (may not be reachable on macOS LAN):
```bash
minikube ip; kubectl -n wisecow get svc wisecow-service-nodeport
curl http://$(minikube ip):<nodePort>/
```
- Via LoadBalancer using tunnel:
```bash
sudo minikube tunnel --bind-address=0.0.0.0 --cleanup
kubectl -n wisecow get svc wisecow-service-loadbalancer -o wide
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
│       └── ci-cd.yaml             # GitHub Actions pipeline
├── k8s/                           # Kubernetes manifests
│   ├── namespace.yaml             # Namespace definition
│   ├── configmap.yaml             # Configuration
│   ├── deployment.yaml            # Application deployment
│   ├── service.yaml               # ClusterIP service (not used by default)
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