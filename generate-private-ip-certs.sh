#!/bin/bash

# Generate self-signed certificates for private IP TLS testing
# This script creates certificates for 192.168.0.114

set -e

CERT_DIR="certs"
PRIVATE_IP="192.168.0.114"
CERT_NAME="wisecow-private-ip"

echo "🔐 Generating self-signed certificates for private IP TLS testing..."

# Create certs directory
mkdir -p $CERT_DIR

# Generate private key
echo "📝 Generating private key..."
openssl genrsa -out $CERT_DIR/$CERT_NAME.key 2048

# Generate certificate signing request with private IP
echo "📝 Generating certificate signing request..."
openssl req -new -key $CERT_DIR/$CERT_NAME.key -out $CERT_DIR/$CERT_NAME.csr -subj "/C=US/ST=Local/L=Local/O=Wisecow/OU=Dev/CN=$PRIVATE_IP"

# Generate self-signed certificate with private IP in SAN
echo "📝 Generating self-signed certificate with private IP..."
openssl x509 -req -days 365 -in $CERT_DIR/$CERT_NAME.csr -signkey $CERT_DIR/$CERT_NAME.key -out $CERT_DIR/$CERT_NAME.crt -extensions v3_req -extfile <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Local
L = Local
O = Wisecow
OU = Dev
CN = $PRIVATE_IP

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = $PRIVATE_IP
DNS.1 = $PRIVATE_IP
EOF
)

# Convert to base64 for Kubernetes
echo "📝 Converting certificates to base64 for Kubernetes..."
CERT_B64=$(base64 -i $CERT_DIR/$CERT_NAME.crt | tr -d '\n')
KEY_B64=$(base64 -i $CERT_DIR/$CERT_NAME.key | tr -d '\n')

# Create Kubernetes TLS secret for private IP
echo "📝 Creating Kubernetes TLS secret for private IP..."
cat > k8s/tls-secret-private-ip.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: wisecow-tls-private
  namespace: wisecow
type: kubernetes.io/tls
data:
  tls.crt: $CERT_B64
  tls.key: $KEY_B64
EOF

echo "✅ Certificates generated successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Deploy the TLS secret:"
echo "   kubectl apply -f k8s/tls-secret-private-ip.yaml"
echo ""
echo "2. Deploy the private IP ingress:"
echo "   kubectl apply -f k8s/ingress-private-ip.yaml"
echo ""
echo "3. Test HTTPS access:"
echo "   curl -k https://$PRIVATE_IP"
echo ""
echo "🔍 Certificate files created:"
echo "   - $CERT_DIR/$CERT_NAME.crt (certificate)"
echo "   - $CERT_DIR/$CERT_NAME.key (private key)"
echo "   - k8s/tls-secret-private-ip.yaml (Kubernetes secret)"
