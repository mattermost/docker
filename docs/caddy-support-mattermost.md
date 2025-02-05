
# Configuring Caddy with Mattermost - Automated TLS

## Why Caddy for TLS Management?

1. **Zero-configuration HTTPS**: Unlike Nginx which requires manual Let's Encrypt certificate setup, Caddy automatically:
   - Obtains certificates
   - Renews before expiration
   - Updates certificates in real-time
   - Handles OCSP stapling

2. **No Additional Containers**: Unlike the Nginx setup which needs:
   - Separate certbot container
   - Manual renewal scripts
   - Volume mounts for certificates
   - Systemd timers for renewals

# Configuring Caddy with Mattermost

## Setting up Caddy as reverse proxy

**NOTE:** Commands with a **$** prefix denote those executed as user, **#** as root.

This guide explains how to configure Caddy as a reverse proxy for Mattermost, with automatic HTTPS certificate management.

### 1. Create Caddy configuration directory

```bash
$ mkdir -p ./caddy
$ touch ./caddy/Caddyfile
```

### 2. Basic Caddyfile configuration

Create 

Caddyfile

 with:

```caddyfile
your-domain.com {
    reverse_proxy mattermost:8065
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
}
```

### 3. Start Mattermost with Caddy

```bash
$ docker-compose -f docker-compose.yml -f docker-compose.caddy.yml up -d
```

### 4. Verify Configuration

```bash
$ docker logs caddy-mattermost
```

### 5. Certificate Management

Caddy automatically handles SSL/TLS certificates through Let's Encrypt. Requirements:

- DNS A/CNAME records pointing to your server
- Ports 80/443 accessible
- Valid domain name

### 6. Environment Variables

Create `.env` file with:

```plaintext
CADDY_CONFIG_PATH=./caddy/Caddyfile
HTTPS_PORT=443
HTTP_PORT=80
RESTART_POLICY=unless-stopped
CADDY_IMAGE_TAG=2.7.4
```

### 7.Ensure A/CNAME records point to your server

```bash
dig +short your-domain.com
```

### 8. Verify Certificate

```bash
curl -vI https://your-domain.com 2>&1 | grep "SSL certificate"
```

These configurations provide automatic HTTPS, modern security headers, and reverse proxy functionality for Mattermost.





## Setup Guide

### 1. Configure DNS

```bash
$ # Ensure A/CNAME records point to your server
$ dig +short your-domain.com
```

### 2. Basic Caddyfile

```caddyfile
your-domain.com {
    reverse_proxy mattermost:8065
    # TLS configuration is automatic!
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }
}
```

### 3. Start Services

```bash
$ docker-compose -f docker-compose.yml -f docker-compose.caddy.yml up -d
```

### 4. Verify Certificate

```bash
$ curl -vI https://your-domain.com 2>&1 | grep "SSL certificate"
```

## Key Benefits

1. **Automatic Management**
   - No manual certificate renewal
   - No certbot configuration
   - No renewal scripts

2. **Security**
   - Modern TLS defaults
   - OCSP stapling enabled
   - HTTP/2 support
   - Automatic redirects

3. **High Availability**
   - Zero-downtime renewals
   - Certificate rotation
   - Graceful reloads

This approach significantly simplifies TLS management compared to manual Nginx+certbot setup.