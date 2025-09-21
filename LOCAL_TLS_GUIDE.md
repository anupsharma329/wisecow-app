# 🔒 Local TLS Setup Guide (No Domain Required)

This guide will help you set up TLS locally using self-signed certificates and local DNS resolution.

## 🎯 Prerequisites

- **Kubernetes cluster** (minikube, kind, or local cluster)
- **kubectl** configured
- **openssl** installed
- **NGINX Ingress Controller** (for ingress functionality)

## 🚀 Quick Setup (Automated)

### Option 1: One-Command Setup

```bash
# Run the automated setup script
./setup-local-tls.sh
```

This script will:
- Generate self-signed certificates
- Add `wisecow.local` to `/etc/hosts`
- Deploy the application to Kubernetes
- Configure TLS with self-signed certificates

## 🔧 Manual Setup (Step by Step)

### Step 1: Generate Self-Signed Certificates

```bash
# Generate certificates
./generate-local-certs.sh
```

This creates:
- `certs/wisecow-local.crt` - Certificate file
- `certs/wisecow-local.key` - Private key
- `k8s/tls-secret-local.yaml` - Kubernetes TLS secret
- `k8s/ingress-local.yaml` - Local ingress configuration

### Step 2: Add Local Domain to /etc/hosts

```bash
# Add wisecow.local to /etc/hosts
echo "127.0.0.1 wisecow.local" | sudo tee -a /etc/hosts
```

### Step 3: Install NGINX Ingress Controller (if not installed)

```bash
# For minikube
minikube addons enable ingress

# For other clusters
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

### Step 4: Deploy the Application

```bash
# Deploy all components
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/tls-secret-local.yaml
kubectl apply -f k8s/ingress-local.yaml
```

### Step 5: Wait for Deployment

```bash
# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=300s deployment/wisecow-deployment -n wisecow
```

## 🧪 Testing the Application

### Method 1: Using Ingress (Recommended)

```bash
# Get ingress IP
kubectl get ingress wisecow-ingress -n wisecow

# If ingress has an IP, update /etc/hosts
echo "<INGRESS_IP> wisecow.local" | sudo tee -a /etc/hosts

# Test HTTPS
curl -k https://wisecow.local
```

### Method 2: Using Port Forward

```bash
# Port forward for HTTP testing
kubectl port-forward service/wisecow-service 8080:80 -n wisecow
curl http://localhost:8080

# Port forward for HTTPS testing
kubectl port-forward service/wisecow-service 8443:443 -n wisecow
curl -k https://localhost:8443
```

### Method 3: Browser Testing

1. Open browser and go to `https://wisecow.local`
2. Accept the self-signed certificate warning
3. You should see the wisecow application

## 🔍 Verification Commands

```bash
# Check pod status
kubectl get pods -n wisecow

# Check service
kubectl get services -n wisecow

# Check ingress
kubectl get ingress -n wisecow

# Check TLS secret
kubectl get secret wisecow-tls -n wisecow

# Check certificate details
kubectl describe secret wisecow-tls -n wisecow
```

## 🐛 Troubleshooting

### Certificate Issues

```bash
# Check certificate validity
openssl x509 -in certs/wisecow-local.crt -text -noout

# Verify certificate matches private key
openssl x509 -noout -modulus -in certs/wisecow-local.crt | openssl md5
openssl rsa -noout -modulus -in certs/wisecow-local.key | openssl md5
```

### Ingress Issues

```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check ingress events
kubectl describe ingress wisecow-ingress -n wisecow
```

### Application Issues

```bash
# Check application logs
kubectl logs -f deployment/wisecow-deployment -n wisecow

# Check pod events
kubectl describe pods -n wisecow
```

## 🔄 Cleanup

```bash
# Remove application
kubectl delete -f k8s/ingress-local.yaml
kubectl delete -f k8s/tls-secret-local.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/configmap.yaml
kubectl delete -f k8s/namespace.yaml

# Remove from /etc/hosts
sudo sed -i '/wisecow.local/d' /etc/hosts

# Remove certificates
rm -rf certs/
rm -f k8s/tls-secret-local.yaml
rm -f k8s/ingress-local.yaml
```

## 📊 Expected Results

### Successful Deployment
- ✅ Pods running: `kubectl get pods -n wisecow`
- ✅ Service available: `kubectl get services -n wisecow`
- ✅ Ingress configured: `kubectl get ingress -n wisecow`
- ✅ TLS secret created: `kubectl get secret wisecow-tls -n wisecow`

### Successful Testing
- ✅ HTTP response: `curl http://localhost:8080`
- ✅ HTTPS response: `curl -k https://wisecow.local`
- ✅ Browser access: `https://wisecow.local` (with certificate warning)

## 🔐 Security Notes

- **Self-signed certificates** are for development only
- **Browser warnings** are expected and safe to ignore for local testing
- **Production deployments** should use proper certificates from a CA
- **Private keys** are stored in Kubernetes secrets (encrypted at rest)

## 🎯 Next Steps

1. **Test the setup** using the provided commands
2. **Verify TLS** is working with HTTPS requests
3. **Check logs** if you encounter any issues
4. **Clean up** when done testing

Your local TLS setup is now ready for testing! 🚀
