# TLS Setup Guide for Wisecow Application

## Prerequisites

1. **cert-manager installed in your Kubernetes cluster**
2. **NGINX Ingress Controller installed**
3. **Valid domain name pointing to your cluster**

## TLS Implementation Steps

### 1. Install cert-manager (if not already installed)

```bash
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true
```

### 2. Install NGINX Ingress Controller

```bash
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

### 3. Update ClusterIssuer with your email

Edit `k8s/cluster-issuer.yaml` and replace `anupsharma@example.com` with your actual email address.

### 4. Update Certificate with your domain

Edit `k8s/certificate.yaml` and replace `wisecow.local` and `wisecow.example.com` with your actual domain names.

### 5. Update Ingress with your domain

Edit `k8s/ingress.yaml` and replace the host entries with your actual domain names.

### 6. Deploy the application

```bash
kubectl apply -f k8s/
```

### 7. Verify TLS Certificate

```bash
# Check certificate status
kubectl get certificate -n wisecow

# Check certificate details
kubectl describe certificate wisecow-cert -n wisecow

# Check if TLS secret is created
kubectl get secret wisecow-tls -n wisecow
```

## Testing TLS

1. **Add domain to /etc/hosts** (for local testing):
   ```
   <your-cluster-ip> wisecow.local
   ```

2. **Access the application**:
   ```bash
   curl -k https://wisecow.local
   # or
   curl -k https://wisecow.example.com
   ```

## Troubleshooting

### Certificate not issued
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate events
kubectl describe certificate wisecow-cert -n wisecow
```

### Ingress not working
```bash
# Check ingress status
kubectl get ingress -n wisecow

# Check ingress events
kubectl describe ingress wisecow-ingress -n wisecow
```

## Production Considerations

1. **Use Let's Encrypt Staging** for testing:
   - Change `server: https://acme-staging-v02.api.letsencrypt.org/directory` in cluster-issuer.yaml
   - Test certificate issuance
   - Switch back to production server

2. **DNS Configuration**:
   - Ensure your domain points to the ingress controller's external IP
   - Use `kubectl get service -n ingress-nginx` to find the external IP

3. **Security**:
   - The application runs on HTTP internally (port 4499)
   - TLS termination happens at the ingress level
   - All external traffic is encrypted via HTTPS
