# 🔒 TLS Setup Guide for Wisecow

This guide provides comprehensive instructions for setting up TLS/SSL encryption for the Wisecow application using Let's Encrypt and cert-manager.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [cert-manager Installation](#cert-manager-installation)
- [ClusterIssuer Configuration](#clusterissuer-configuration)
- [TLS Certificate Setup](#tls-certificate-setup)
- [Ingress Configuration](#ingress-configuration)
- [DNS Configuration](#dns-configuration)
- [Testing TLS](#testing-tls)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

## 🎯 Overview

This guide covers:
- ✅ Installing cert-manager in Kubernetes
- ✅ Configuring Let's Encrypt ClusterIssuer
- ✅ Setting up TLS certificates
- ✅ Configuring HTTPS ingress
- ✅ DNS setup for domain validation
- ✅ Testing and troubleshooting

## 📋 Prerequisites

### Required Components
- **Kubernetes Cluster**: Running and accessible
- **Domain Name**: Registered and configurable
- **DNS Access**: Ability to create DNS records
- **kubectl**: Configured and working
- **Internet Access**: For Let's Encrypt validation

### Cluster Requirements
- **Kubernetes Version**: 1.19+ (for cert-manager v1.13+)
- **Ingress Controller**: NGINX, Traefik, or similar
- **LoadBalancer**: For external access (cloud providers)

## 🔧 cert-manager Installation

### Method 1: Using kubectl (Recommended)

#### Step 1: Install cert-manager
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

#### Step 2: Wait for cert-manager to be ready
```bash
# Wait for cert-manager pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s

# Check cert-manager status
kubectl get pods -n cert-manager
```

### Method 2: Using Helm

#### Step 1: Add cert-manager Helm repository
```bash
# Add cert-manager repo
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

#### Step 2: Install cert-manager
```bash
# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true
```

### Method 3: Using Kustomize

#### Step 1: Create kustomization.yaml
```yaml
# cert-manager-kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

patchesStrategicMerge:
- cert-manager-patch.yaml
```

#### Step 2: Apply with Kustomize
```bash
kubectl apply -k .
```

## 🔐 ClusterIssuer Configuration

### Step 1: Create ClusterIssuer for Let's Encrypt

#### Production ClusterIssuer
```yaml
# cluster-issuer-prod.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

#### Staging ClusterIssuer (for testing)
```yaml
# cluster-issuer-staging.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Step 2: Apply ClusterIssuer
```bash
# Apply production issuer
kubectl apply -f cluster-issuer-prod.yaml

# Verify ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

## 📜 TLS Certificate Setup

### Step 1: Create Certificate Resource

#### Basic Certificate
```yaml
# certificate-basic.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wisecow-tls
  namespace: wisecow
spec:
  secretName: wisecow-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - wisecow.example.com  # Replace with your domain
```

#### Advanced Certificate with Multiple Domains
```yaml
# certificate-advanced.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wisecow-tls
  namespace: wisecow
spec:
  secretName: wisecow-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - wisecow.example.com
  - www.wisecow.example.com
  - api.wisecow.example.com
  duration: 2160h  # 90 days
  renewBefore: 360h  # 15 days before expiry
```

### Step 2: Apply Certificate
```bash
# Apply certificate
kubectl apply -f certificate-basic.yaml

# Check certificate status
kubectl get certificate -n wisecow
kubectl describe certificate wisecow-tls -n wisecow
```

### Step 3: Monitor Certificate Creation
```bash
# Watch certificate events
kubectl get events -n wisecow --watch

# Check certificate requests
kubectl get certificaterequests -n wisecow

# Check certificate details
kubectl get secret wisecow-tls -n wisecow -o yaml
```

## 🌐 Ingress Configuration

### Step 1: Configure Ingress with TLS

#### Basic Ingress
```yaml
# ingress-tls-basic.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wisecow-ingress
  namespace: wisecow
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  tls:
  - hosts:
    - wisecow.example.com  # Replace with your domain
    secretName: wisecow-tls
  rules:
  - host: wisecow.example.com  # Replace with your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wisecow-service
            port:
              number: 80
```

#### Advanced Ingress with Multiple Paths
```yaml
# ingress-tls-advanced.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wisecow-ingress
  namespace: wisecow
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
spec:
  tls:
  - hosts:
    - wisecow.example.com
    - www.wisecow.example.com
    secretName: wisecow-tls
  rules:
  - host: wisecow.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wisecow-service
            port:
              number: 80
  - host: www.wisecow.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wisecow-service
            port:
              number: 80
```

### Step 2: Apply Ingress
```bash
# Apply ingress
kubectl apply -f ingress-tls-basic.yaml

# Check ingress status
kubectl get ingress -n wisecow
kubectl describe ingress wisecow-ingress -n wisecow
```

## 🌍 DNS Configuration

### Step 1: Get LoadBalancer IP
```bash
# Get external IP
kubectl get ingress wisecow-ingress -n wisecow

# Or get LoadBalancer service IP
kubectl get svc -n ingress-nginx
```

### Step 2: Configure DNS Records

#### A Record (IPv4)
```
Type: A
Name: wisecow.example.com
Value: <LOAD_BALANCER_IP>
TTL: 300
```

#### CNAME Record (if using subdomain)
```
Type: CNAME
Name: www.wisecow.example.com
Value: wisecow.example.com
TTL: 300
```

#### Example DNS Configuration
```bash
# Using Cloudflare
curl -X POST "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "wisecow",
    "content": "YOUR_LOAD_BALANCER_IP",
    "ttl": 300
  }'
```

### Step 3: Verify DNS Propagation
```bash
# Check DNS resolution
nslookup wisecow.example.com
dig wisecow.example.com

# Test from different locations
curl -I https://wisecow.example.com
```

## 🧪 Testing TLS

### Step 1: Test Certificate Status
```bash
# Check certificate in cluster
kubectl get certificate -n wisecow
kubectl describe certificate wisecow-tls -n wisecow

# Check certificate secret
kubectl get secret wisecow-tls -n wisecow -o yaml
```

### Step 2: Test HTTPS Connection
```bash
# Test HTTPS connection
curl -I https://wisecow.example.com

# Test with verbose output
curl -v https://wisecow.example.com

# Test certificate details
openssl s_client -connect wisecow.example.com:443 -servername wisecow.example.com
```

### Step 3: Test Browser Access
1. Open browser
2. Navigate to `https://wisecow.example.com`
3. Check for SSL lock icon
4. Verify certificate details

### Step 4: Test SSL Labs (Optional)
1. Go to [SSL Labs](https://www.ssllabs.com/ssltest/)
2. Enter your domain
3. Check SSL rating and configuration

## 🐛 Troubleshooting

### Common Issues

#### 1. Certificate Not Issued
**Error**: `Certificate is not ready`

**Solutions**:
```bash
# Check certificate status
kubectl describe certificate wisecow-tls -n wisecow

# Check certificate requests
kubectl get certificaterequests -n wisecow

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager
```

#### 2. DNS Validation Failed
**Error**: `DNS validation failed`

**Solutions**:
- Verify DNS records are correct
- Check DNS propagation
- Ensure domain points to LoadBalancer IP

#### 3. Ingress Not Working
**Error**: `404 Not Found` or `502 Bad Gateway`

**Solutions**:
```bash
# Check ingress status
kubectl describe ingress wisecow-ingress -n wisecow

# Check backend services
kubectl get svc -n wisecow

# Check pods
kubectl get pods -n wisecow
```

#### 4. Rate Limiting
**Error**: `Too many requests`

**Solutions**:
- Use staging environment for testing
- Wait for rate limit reset
- Use different email for staging

### Debug Commands

#### Check cert-manager Status
```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager

# Check ClusterIssuer
kubectl describe clusterissuer letsencrypt-prod
```

#### Check Certificate Details
```bash
# Check certificate
kubectl get certificate -n wisecow -o yaml

# Check certificate requests
kubectl get certificaterequests -n wisecow -o yaml

# Check challenges
kubectl get challenges -n wisecow
```

#### Check Ingress Status
```bash
# Check ingress
kubectl get ingress -n wisecow -o yaml

# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

## 🔧 Advanced Configuration

### Custom Certificate Duration
```yaml
# certificate-custom-duration.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wisecow-tls
  namespace: wisecow
spec:
  secretName: wisecow-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - wisecow.example.com
  duration: 2160h  # 90 days
  renewBefore: 360h  # 15 days before expiry
```

### Wildcard Certificate
```yaml
# certificate-wildcard.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wisecow-wildcard-tls
  namespace: wisecow
spec:
  secretName: wisecow-wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.wisecow.example.com"
  - wisecow.example.com
```

### HTTP-01 Challenge Configuration
```yaml
# cluster-issuer-http01.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                kubernetes.io/os: linux
```

### DNS-01 Challenge (for wildcard certificates)
```yaml
# cluster-issuer-dns01.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-dns
    solvers:
    - dns01:
        cloudflare:
          email: your-email@example.com
          apiKeySecretRef:
            name: cloudflare-api-key
            key: api-key
```

## 📊 Monitoring and Maintenance

### Certificate Monitoring
```bash
# Check certificate expiry
kubectl get certificate -n wisecow -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter

# Monitor certificate renewal
kubectl get events -n wisecow --field-selector reason=Renewed
```

### Automated Monitoring Script
```bash
#!/bin/bash
# monitor-certificates.sh

NAMESPACE="wisecow"
CERT_NAME="wisecow-tls"

# Check certificate status
kubectl get certificate $CERT_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[0].status}'

# Check expiry date
kubectl get certificate $CERT_NAME -n $NAMESPACE -o jsonpath='{.status.notAfter}'

# Check renewal status
kubectl get events -n $NAMESPACE --field-selector reason=Renewed
```

### Alerting Configuration
```yaml
# prometheus-rule.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: certificate-alerts
  namespace: wisecow
spec:
  groups:
  - name: certificate.rules
    rules:
    - alert: CertificateExpiringSoon
      expr: cert_manager_certificate_expiration_timestamp_seconds - time() < 7 * 24 * 3600
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Certificate expiring soon"
        description: "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} expires in less than 7 days"
```

---

**Secure TLS Setup Complete! 🔒**
