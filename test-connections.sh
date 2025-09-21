#!/bin/bash

echo "🔍 Testing Wisecow Application Connections..."
echo "=============================================="

# Test HTTP
echo "🌐 Testing HTTP (Port 4499)..."
if curl -s --connect-timeout 5 http://192.168.0.114:4499 > /dev/null; then
    echo "✅ HTTP is working!"
    echo "   URL: http://192.168.0.114:4499"
else
    echo "❌ HTTP is not working"
fi

echo ""

# Test HTTPS
echo "🔒 Testing HTTPS (Port 8443)..."
if curl -s -k --connect-timeout 5 https://192.168.0.114:8443 > /dev/null; then
    echo "✅ HTTPS is working!"
    echo "   URL: https://192.168.0.114:8443"
else
    echo "❌ HTTPS is not working"
fi

echo ""
echo "🌐 Browser Test URLs:"
echo "   HTTP:  http://192.168.0.114:4499"
echo "   HTTPS: https://192.168.0.114:8443"
echo ""
echo "📱 Network Access:"
echo "   These URLs work from any device on your network (192.168.0.x)"
echo ""
echo "🔧 If browser doesn't work:"
echo "   1. Try refreshing the page"
echo "   2. Clear browser cache"
echo "   3. Try incognito/private mode"
echo "   4. For HTTPS: Accept the certificate warning"
