#!/bin/bash

echo "🔧 FIXING NGINX SSL CONFIGURATION"
echo "================================="

# Backup current nginx configuration
echo "💾 Backing up current nginx configuration..."
cp -r /etc/nginx /etc/nginx.backup.$(date +%Y%m%d_%H%M%S)

# Fix the SSL directive issue
echo "🔧 Fixing SSL directive in nginx configuration..."

# Find and fix ssl_private_key directive (should be ssl_certificate_key)
find /etc/nginx -name "*.conf" -o -name "*" | xargs grep -l "ssl_private_key" | while read file; do
    echo "🔧 Fixing SSL directive in: $file"
    sed -i 's/ssl_private_key/ssl_certificate_key/g' "$file"
done

# Also check sites-enabled and sites-available
for dir in /etc/nginx/sites-enabled /etc/nginx/sites-available; do
    if [ -d "$dir" ]; then
        find "$dir" -type f | xargs grep -l "ssl_private_key" 2>/dev/null | while read file; do
            echo "🔧 Fixing SSL directive in: $file"
            sed -i 's/ssl_private_key/ssl_certificate_key/g' "$file"
        done
    fi
done

# Test nginx configuration
echo "🧪 Testing nginx configuration..."
if nginx -t; then
    echo "✅ Nginx configuration is valid!"
    
    echo "🔄 Reloading nginx..."
    systemctl reload nginx
    
    echo "📊 Nginx status:"
    systemctl status nginx --no-pager -l
    
    echo "✅ Nginx SSL configuration fixed successfully!"
else
    echo "❌ Nginx configuration still has errors."
    echo "📋 Showing nginx error details:"
    nginx -t
    
    echo "🔍 Checking for common SSL issues..."
    
    # Check for missing SSL certificates
    grep -r "ssl_certificate" /etc/nginx/ | grep -v "#" | while read line; do
        cert_file=$(echo "$line" | awk '{print $NF}' | tr -d ';')
        if [ ! -f "$cert_file" ]; then
            echo "❌ Missing SSL certificate: $cert_file"
        fi
    done
    
    # Check for missing SSL keys
    grep -r "ssl_certificate_key" /etc/nginx/ | grep -v "#" | while read line; do
        key_file=$(echo "$line" | awk '{print $NF}' | tr -d ';')
        if [ ! -f "$key_file" ]; then
            echo "❌ Missing SSL key: $key_file"
        fi
    done
    
    echo "💡 Consider disabling SSL temporarily if certificates are missing:"
    echo "   - Comment out SSL directives in nginx config"
    echo "   - Use HTTP only until SSL certificates are restored"
fi

echo "🔍 Current nginx configuration files with SSL:"
find /etc/nginx -name "*.conf" -o -name "*" | xargs grep -l "ssl_" 2>/dev/null | head -10
