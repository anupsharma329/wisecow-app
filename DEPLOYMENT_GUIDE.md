# Wisecow Application - Complete Deployment Guide

## 🎯 Project Overview

The Wisecow application is a containerized web service that serves random wisdom quotes using cowsay. This guide covers the complete CI/CD pipeline with TLS support for Kubernetes deployment.

## 📁 Project Structure

```
wisecow-app/
├── wisecow.sh              # Main application script
├── Dockerfile              # Container definition
├── .dockerignore           # Docker build exclusions
├── README.md               # Project documentation
├── LICENSE                 # Apache 2.0 license
├── TLS_SETUP.md           # TLS configuration guide
├── DEPLOYMENT_GUIDE.md    # This file
├── .github/
│   └── workflows/
│       └── ci-cd.yml      # GitHub Actions CI/CD pipeline
└── k8s/                   # Kubernetes manifests
    ├── namespace.yaml      # Namespace definition
    ├── configmap.yaml      # Application configuration
    ├── deployment.yaml     # Application deployment
    ├── service.yaml        # Service exposure
    ├── ingress.yaml        # Ingress with TLS
    ├── certificate.yaml    # TLS certificate
    ├── cluster-issuer.yaml # Let's Encrypt issuer
    ├── tls-secret.yaml     # TLS secret template
    └── kustomization.yaml  # Kustomize configuration
```

## 🚀 Quick Start

### Prerequisites

1. **Docker** installed locally
2. **Kubernetes cluster** (minikube, kind, or cloud provider)
3. **kubectl** configured
4. **GitHub repository** (public or private)

### Local Development

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd wisecow-app
   ```

2. **Build and run locally:**
   ```bash
   # Build Docker image
   docker build -t wisecow:latest .
   
   # Run container
   docker run -p 8080:4499 wisecow:latest
   
   # Test the application
   curl http://localhost:8080
   ```

3. **Deploy to Kubernetes:**
   ```bash
   # Apply all manifests
   kubectl apply -f k8s/
   
   # Check deployment status
   kubectl get pods -n wisecow
   kubectl get services -n wisecow
   
   # Port forward for testing
   kubectl port-forward service/wisecow-service 8080:80 -n wisecow
   ```

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

The CI/CD pipeline automatically:

1. **Builds Docker image** on every push/PR
2. **Pushes to GitHub Container Registry** (ghcr.io)
3. **Deploys to Kubernetes** (if KUBE_CONFIG secret is configured)
4. **Supports TLS** with cert-manager integration

### Setting up CI/CD

1. **Enable GitHub Actions** in your repository settings

2. **Configure Container Registry:**
   - Go to Settings → Packages
   - Enable GitHub Container Registry
   - The workflow uses `GITHUB_TOKEN` automatically

3. **Configure Kubernetes Deployment (Optional):**
   ```bash
   # Get your kubeconfig
   kubectl config view --raw > kubeconfig.yaml
   
   # Base64 encode it
   base64 -i kubeconfig.yaml
   
   # Add as GitHub Secret:
   # Repository Settings → Secrets and variables → Actions
   # Name: KUBE_CONFIG
   # Value: <base64-encoded-kubeconfig>
   ```

4. **Push changes to trigger pipeline:**
   ```bash
   git add .
   git commit -m "Initial commit with CI/CD"
   git push origin main
   ```

## 🔒 TLS Implementation

### Prerequisites for TLS

1. **cert-manager** installed in cluster
2. **NGINX Ingress Controller** installed
3. **Valid domain name** pointing to cluster

### TLS Setup Steps

1. **Install cert-manager:**
   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
   helm install cert-manager jetstack/cert-manager \
     --namespace cert-manager \
     --create-namespace \
     --version v1.13.0 \
     --set installCRDs=true
   ```

2. **Install NGINX Ingress:**
   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update
   helm install ingress-nginx ingress-nginx/ingress-nginx \
     --namespace ingress-nginx \
     --create-namespace
   ```

3. **Update configuration:**
   - Edit `k8s/cluster-issuer.yaml` with your email
   - Edit `k8s/certificate.yaml` with your domain
   - Edit `k8s/ingress.yaml` with your domain

4. **Deploy with TLS:**
   ```bash
   kubectl apply -f k8s/
   ```

## 🧪 Testing

### Local Testing

```bash
# Test Docker container
docker run -p 8080:4499 wisecow:latest
curl http://localhost:8080

# Test Kubernetes deployment
kubectl port-forward service/wisecow-service 8080:80 -n wisecow
curl http://localhost:8080
```

### TLS Testing

```bash
# Add domain to /etc/hosts
echo "<cluster-ip> wisecow.local" >> /etc/hosts

# Test HTTPS
curl -k https://wisecow.local
```

## 🔧 Configuration

### Environment Variables

The application uses these environment variables (configured via ConfigMap):

- `SRVPORT`: Server port (default: 4499)
- `RSPFILE`: Response file name (default: response)

### Resource Limits

- **CPU**: 100m request, 200m limit
- **Memory**: 64Mi request, 128Mi limit
- **Replicas**: 3 (configurable in deployment.yaml)

## 🐛 Troubleshooting

### Common Issues

1. **Image pull errors:**
   ```bash
   # Check image exists
   docker pull ghcr.io/anupsharma/wisecow-app:latest
   
   # Update imagePullPolicy to Always
   ```

2. **Certificate not issued:**
   ```bash
   # Check cert-manager logs
   kubectl logs -n cert-manager deployment/cert-manager
   
   # Check certificate status
   kubectl describe certificate wisecow-cert -n wisecow
   ```

3. **Ingress not working:**
   ```bash
   # Check ingress controller
   kubectl get pods -n ingress-nginx
   
   # Check ingress status
   kubectl describe ingress wisecow-ingress -n wisecow
   ```

### Debug Commands

```bash
# Check all resources
kubectl get all -n wisecow

# Check logs
kubectl logs -f deployment/wisecow-deployment -n wisecow

# Check events
kubectl get events -n wisecow --sort-by='.lastTimestamp'

# Check certificate status
kubectl get certificate -n wisecow
kubectl describe certificate wisecow-cert -n wisecow
```

## 📊 Monitoring

### Health Checks

The application includes:
- **Liveness probe**: TCP check on port 4499
- **Readiness probe**: TCP check on port 4499
- **Docker health check**: Built into container

### Metrics

Monitor using:
```bash
# Pod status
kubectl get pods -n wisecow

# Resource usage
kubectl top pods -n wisecow

# Service endpoints
kubectl get endpoints wisecow-service -n wisecow
```

## 🔄 Updates and Maintenance

### Updating the Application

1. **Code changes** trigger automatic CI/CD
2. **Manual updates**:
   ```bash
   # Update image tag in deployment.yaml
   kubectl set image deployment/wisecow-deployment wisecow=ghcr.io/anupsharma/wisecow-app:new-tag -n wisecow
   
   # Check rollout status
   kubectl rollout status deployment/wisecow-deployment -n wisecow
   ```

### Scaling

```bash
# Scale up/down
kubectl scale deployment wisecow-deployment --replicas=5 -n wisecow

# Check scaling
kubectl get deployment wisecow-deployment -n wisecow
```

## 🎯 Production Checklist

- [ ] Domain name configured
- [ ] cert-manager installed
- [ ] NGINX Ingress Controller installed
- [ ] GitHub Container Registry configured
- [ ] KUBE_CONFIG secret added (for auto-deployment)
- [ ] Email updated in cluster-issuer.yaml
- [ ] Domain updated in certificate.yaml and ingress.yaml
- [ ] Resource limits appropriate for workload
- [ ] Monitoring and logging configured
- [ ] Backup strategy in place

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
