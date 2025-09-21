#!/bin/bash

# Generate a certificate that Safari will accept more easily
# This creates a certificate with proper extensions for Safari

set -e

CERT_DIR="certs"
PRIVATE_IP="192.168.0.114"
CERT_NAME="wisecow-safari"

echo "🔐 Generating Safari-compatible certificate..."

# Create certs directory
mkdir -p $CERT_DIR

# Generate private key
echo "📝 Generating private key..."
openssl genrsa -out $CERT_DIR/$CERT_NAME.key 2048

# Create a config file for the certificate
cat > $CERT_DIR/cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = Wisecow Development
OU = IT Department
CN = $PRIVATE_IP

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
basicConstraints = CA:FALSE

[alt_names]
IP.1 = $PRIVATE_IP
DNS.1 = $PRIVATE_IP
DNS.2 = localhost
EOF

# Generate certificate signing request
echo "📝 Generating certificate signing request..."
openssl req -new -key $CERT_DIR/$CERT_NAME.key -out $CERT_DIR/$CERT_NAME.csr -config $CERT_DIR/cert.conf

# Generate self-signed certificate with proper extensions
echo "📝 Generating Safari-compatible certificate..."
openssl x509 -req -days 365 -in $CERT_DIR/$CERT_NAME.csr -signkey $CERT_DIR/$CERT_NAME.key -out $CERT_DIR/$CERT_NAME.crt -extensions v3_req -extfile $CERT_DIR/cert.conf

# Convert to base64 for Kubernetes
echo "📝 Converting certificates to base64 for Kubernetes..."
CERT_B64=$(base64 -i $CERT_DIR/$CERT_NAME.crt | tr -d '\n')
KEY_B64=$(base64 -i $CERT_DIR/$CERT_NAME.key | tr -d '\n')

# Create Kubernetes TLS secret
echo "📝 Creating Kubernetes TLS secret..."
cat > k8s/tls-secret-safari.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: wisecow-tls-safari
  namespace: wisecow
type: kubernetes.io/tls
data:
  tls.crt: $CERT_B64
  tls.key: $KEY_B64
EOF

echo "✅ Safari-compatible certificate generated!"
echo ""
echo "📋 Next steps:"
echo "1. Deploy the new certificate:"
echo "   kubectl apply -f k8s/tls-secret-safari.yaml"
echo ""
echo "2. Update the nginx proxy to use the new certificate:"
echo "   kubectl patch deployment nginx-tls-proxy -n wisecow -p '{\"spec\":{\"template\":{\"spec\":{\"volumes\":[{\"name\":\"tls-certs\",\"secret\":{\"secretName\":\"wisecow-tls-safari\"}}]}}}}'"
echo ""
echo "3. Test in Safari:"
echo "   https://$PRIVATE_IP:8443"
