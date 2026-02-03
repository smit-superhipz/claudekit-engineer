# ClaudeKit Distribution System - Deployment Guide

## Quick Start (5 minutes)

### Prerequisites
- macOS or Linux system
- Docker and Docker Compose installed
- GitHub personal access token (for admin operations)
- Bash 3.2+ (comes with most systems)

### Setup Steps

```bash
# 1. Clone or navigate to project
cd /Volumes/Workplace/claudekit-engineer

# 2. Set GitHub token
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# 3. Generate releases
./scripts/download.sh

# 4. Start distribution server
cd scripts
docker-compose up -d

# 5. Verify server is running
curl http://localhost:4567/releases/manifest.json
```

Users can now install via:
```bash
BASE_URL=http://192.168.1.100:4567 bash <(curl -fsSL http://192.168.1.100:4567/install-claudekit.sh)
```

---

## Detailed Deployment Guide

## Part 1: Prerequisites & Environment Setup

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | macOS 10.13+ or Linux | macOS 11+ or Ubuntu 20+ |
| RAM | 512 MB | 2 GB |
| Disk | 1 GB free | 5 GB free (for releases) |
| Network | 10 Mbps | 100 Mbps |
| Bash | 3.2+ | 4.2+ |

### Required Software

**Install via Homebrew (macOS):**
```bash
brew install docker docker-compose curl
# Docker Desktop also available: brew install docker --cask
```

**Install via apt (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose curl
sudo usermod -aG docker $USER
```

**Verify installation:**
```bash
docker --version        # Docker version 20+
docker-compose --version # Docker Compose 1.29+
curl --version          # curl 7.0+
bash --version          # GNU bash 3.2+
```

### GitHub Setup

**1. Create Personal Access Token:**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token"
3. Select scopes: `public_repo` (minimum)
4. Copy token immediately (only shown once)

**2. Set environment variable:**
```bash
# Add to ~/.bashrc or ~/.zshrc for persistence
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# Or set for current session only
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx ./scripts/download.sh
```

**3. Verify token works:**
```bash
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user
# Should show your GitHub user information
```

---

## Part 2: Initial Setup

### Step 1: Navigate to Project Directory

```bash
cd /Volumes/Workplace/claudekit-engineer
```

### Step 2: Verify Project Structure

```bash
ls -la scripts/
# Expected output:
# -rwxr-xr-x download.sh
# -rw-r--r-- docker-compose.yml
# -rw-r--r-- settings.json
# -rwxr-xr-x install-claudekit.sh
# -rw-r--r-- trigger-server.py
# ...

ls -la
# Expected:
# install-claudekit-curl.sh
# install-claudekit-global.sh
# scripts/
# docs/
# README.md
```

### Step 3: Generate Initial Releases

Run the admin download script to fetch latest releases from GitHub:

```bash
# Ensure GITHUB_TOKEN is set
echo $GITHUB_TOKEN  # Should show your token

# Generate releases
./scripts/download.sh

# Expected output:
# ✓ GitHub token detected
# ✓ Dependencies OK (curl)
# ✓ Output directory: /path/to/scripts/releases
#
# Processing: claudekit-engineer
#   ✓ Found version: v2.0.0
#   ✓ Downloaded: claudekit-engineer-v2.0.0.zip
#
# Processing: claudekit-marketing
#   ✓ Found version: v1.5.0
#   ✓ Downloaded: claudekit-marketing-v1.5.0.zip
#
# ✓ Generated: manifest.json
```

**Verify releases were created:**
```bash
ls -lh scripts/releases/
# Expected:
# -rw-r--r-- claudekit-engineer-v2.0.0.zip (10M)
# -rw-r--r-- claudekit-marketing-v1.5.0.zip (8M)
# -rw-r--r-- manifest.json (200 bytes)
```

### Step 4: Validate Manifest

Check the generated manifest is valid JSON:

```bash
# macOS/Linux with jq
jq . scripts/releases/manifest.json

# Expected output:
# {
#   "products": [
#     {
#       "repo": "claudekit-engineer",
#       "version": "v2.0.0",
#       "file": "claudekit-engineer-v2.0.0.zip"
#     },
#     ...
#   ],
#   "updated": "2026-02-03T15:00:00Z"
# }
```

---

## Part 3: Docker Server Deployment

### Step 1: Start Docker Containers

```bash
cd scripts

# Start containers in detached mode
docker-compose up -d

# Expected output:
# Creating claudekit-releases ... done
# Creating claudekit-trigger ... done
```

### Step 2: Verify Containers are Running

```bash
# Check container status
docker-compose ps

# Expected output:
# NAME                    COMMAND                  SERVICE       STATUS
# claudekit-releases      nginx -g daemon off      claudekit-server    Up
# claudekit-trigger       python trigger-server.py trigger              Up

# Check logs
docker-compose logs -f --tail=20

# Expected: Both containers should show "up" status
```

### Step 3: Test HTTP Endpoints

**Test manifest endpoint (nginx):**
```bash
curl http://localhost:4567/releases/manifest.json

# Expected: Valid JSON manifest
```

**Test health endpoint (trigger):**
```bash
curl http://localhost:4568/health

# Expected output:
# {
#   "status": "ok"
# }
```

**Test trigger endpoint (trigger):**
```bash
curl http://localhost:4568/trigger-download

# Expected output:
# {
#   "success": true,
#   "timestamp": "2026-02-03T15:00:00.123456",
#   "stdout": "[download.sh output...]",
#   "stderr": ""
# }
```

### Step 4: Verify Static Files are Served

```bash
# List available files via nginx
curl -s http://localhost:4567/releases/ | grep -o 'href="[^"]*"'

# Or test direct download
curl -I http://localhost:4567/releases/claudekit-engineer-v2.0.0.zip
# Should return HTTP 200 OK
```

---

## Part 4: User Installation Testing

### Test 1: Basic Installation (HTTP Server)

**User machine (local test):**
```bash
# Test from a different directory
cd /tmp

# Run installer
BASE_URL=http://localhost:4567 bash <(curl -fsSL http://localhost:4567/install-claudekit.sh)

# Follow prompts:
# 1. Select product (1 or 2)
# 2. Select action (1 for install, 2 for download)
# 3. Confirm installation

# Verify installation
ls -la ~/.claude/
# Should show: agents/, skills/, workflows/, commands/, etc.
```

### Test 2: Download-Only Mode

```bash
cd /tmp/test-download

# Run installer in download-only mode
BASE_URL=http://localhost:4567 bash <(curl -fsSL http://localhost:4567/install-claudekit.sh)

# Select action: 2 (download only)

# Verify
ls -la ./.claude/
# Should have .claude/ in current directory
```

### Test 3: Backup Verification

```bash
# Create dummy installation
mkdir -p ~/.claude
echo "test content" > ~/.claude/test.txt

# Run installer again
BASE_URL=http://localhost:4567 bash <(curl -fsSL http://localhost:4567/install-claudekit.sh)

# Verify backup was created
ls -la ~/.claude-backup-*/
# Should contain: test.txt and other original files
```

### Test 4: Global Installation

```bash
./install-claudekit-global.sh

# Follow prompts to select which claudekit version to install

# Verify
ls -la ~/.claude/
```

---

## Part 5: Production Deployment

### Scenario 1: Internal Company Network

**Setup:**
1. Run on dedicated admin machine: `docker-compose up -d`
2. Find internal IP: `ifconfig | grep "inet "`
3. Share IP with team (e.g., `192.168.1.100`)
4. Users install: `BASE_URL=http://192.168.1.100:4567 bash <(...)`

**Persistence:**
```bash
# Make containers restart on boot
cd scripts
docker-compose up -d --restart unless-stopped

# Or update docker-compose.yml
# Add to services: restart_policy: unless-stopped
```

### Scenario 2: Cloud Deployment (AWS EC2)

**Setup on EC2 instance:**
```bash
# 1. SSH into EC2 instance
ssh -i key.pem ubuntu@instance-ip

# 2. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# 3. Clone/setup project
git clone <repo> claudekit-engineer
cd claudekit-engineer

# 4. Set token and generate releases
export GITHUB_TOKEN=ghp_xxxxx
./scripts/download.sh

# 5. Start containers
cd scripts
docker-compose up -d

# 6. Configure security group for port 4567
# AWS Console → Security Groups → Add Inbound Rule:
#   Type: HTTP, Port: 4567, Source: 0.0.0.0/0
```

**Access from users:**
```bash
# Get EC2 public IP from AWS console
BASE_URL=http://ec2-instance-ip:4567 bash <(curl -fsSL ...)
```

### Scenario 3: Docker Hub Push

**Build and push custom image:**
```bash
# Build Dockerfile from docker-compose
docker build -t mycompany/claudekit-server .

# Tag for registry
docker tag mycompany/claudekit-server mycompany/claudekit-server:latest

# Push to registry
docker push mycompany/claudekit-server:latest

# Pull on deployment machine
docker pull mycompany/claudekit-server:latest
docker run -p 4567:80 mycompany/claudekit-server
```

---

## Part 6: Maintenance & Operations

### Regular Tasks

**Weekly: Check for new releases**
```bash
cd /Volumes/Workplace/claudekit-engineer

export GITHUB_TOKEN=ghp_xxxxx
./scripts/download.sh --force  # Re-download even if exists

# This updates releases/ and manifest.json
# No server restart needed (nginx serves new files automatically)
```

**Monitor container health:**
```bash
# Check containers running
docker-compose ps

# View logs
docker-compose logs --tail=100

# Check resource usage
docker stats claudekit-releases claudekit-trigger
```

**Backup releases:**
```bash
# Backup release files
tar -czf releases-backup-$(date +%Y%m%d).tar.gz scripts/releases/

# Store in safe location
mv releases-backup-*.tar.gz /backup/location/
```

### Troubleshooting

#### Issue: Containers Won't Start

```bash
# Check error logs
docker-compose logs claudekit-releases
docker-compose logs claudekit-trigger

# Common issues:
# 1. Port already in use
lsof -i :4567  # Check port 4567
lsof -i :4568  # Check port 4568

# 2. Releases directory missing
mkdir -p scripts/releases

# 3. Permissions issue
sudo chown -R $USER:$USER scripts/

# Restart containers
docker-compose down
docker-compose up -d
```

#### Issue: Cannot Download from Server

```bash
# Check nginx is serving files
curl -v http://localhost:4567/releases/manifest.json

# If 404, verify:
ls -la scripts/releases/manifest.json

# Check nginx container logs
docker logs claudekit-releases

# Verify docker volume mount
docker-compose logs | grep "volume"
```

#### Issue: Trigger Server Not Responding

```bash
# Check Python process
docker logs claudekit-trigger

# Verify port 4568 is open
netstat -tuln | grep 4568

# Test trigger endpoint
curl -v http://localhost:4568/health

# Check GITHUB_TOKEN is set in container
docker-compose exec trigger env | grep GITHUB_TOKEN
```

#### Issue: Installation Fails with "Manifest Not Found"

```bash
# User's side:
# 1. Verify BASE_URL is correct
echo $BASE_URL

# 2. Test manifest download
curl -v $BASE_URL/releases/manifest.json

# 3. Check server is running on admin side
docker-compose ps

# 4. If server offline, restart
docker-compose up -d
```

### Updating ClaudeKit Versions

**When new releases are available:**

```bash
# 1. Run download script (admin)
export GITHUB_TOKEN=ghp_xxxxx
./scripts/download.sh

# 2. Verify new files
ls -lh scripts/releases/*.zip

# 3. Check manifest updated
cat scripts/releases/manifest.json | jq '.updated'

# 4. No server restart needed!
# nginx automatically serves new files

# 5. Notify users of available update
# (or schedule automatic download)
```

### Scheduled Updates (Cron)

**Setup automatic weekly updates:**

```bash
# Edit crontab
crontab -e

# Add line (updates every Sunday at 2 AM):
0 2 * * 0 export GITHUB_TOKEN=ghp_xxxxx && \
    /Volumes/Workplace/claudekit-engineer/scripts/download.sh >> \
    /var/log/claudekit-download.log 2>&1

# Verify cron job
crontab -l
```

---

## Part 7: Security Hardening

### 1. Restrict Network Access

**Firewall (macOS):**
```bash
# Allow only specific IPs to port 4567
sudo pfctl -ef /etc/pf.conf

# Or use AWS Security Groups:
# Inbound Rule: HTTP 4567 from 10.0.0.0/8 (internal only)
```

**Firewall (Linux):**
```bash
sudo ufw allow from 192.168.1.0/24 to any port 4567
sudo ufw allow from 192.168.1.0/24 to any port 4568
```

### 2. Limit Trigger Access

**Disable public trigger (if not needed):**

Edit docker-compose.yml:
```yaml
# Remove or comment out trigger service if only serving releases
services:
  claudekit-server:
    # ... keep nginx
  # trigger:   # Disable if not needed
  #   ...
```

### 3. HTTPS/TLS Setup (Production)

**Using nginx with Let's Encrypt:**

```bash
# Install certbot
brew install certbot

# Generate certificate
sudo certbot certonly --standalone -d claudekit.company.com

# Update docker-compose.yml to mount certificate
volumes:
  - /etc/letsencrypt/live/claudekit.company.com:/certs:ro

# Update nginx config to use HTTPS
listen 443 ssl;
ssl_certificate /certs/fullchain.pem;
ssl_certificate_key /certs/privkey.pem;
```

### 4. Environment Variable Security

**Do NOT commit tokens to git:**
```bash
# .gitignore
.env
.env.local
scripts/.env
*.token
```

**Use environment files:**
```bash
# Create scripts/.env (git-ignored)
GITHUB_TOKEN=ghp_xxxxx

# Source before running
set -a
source scripts/.env
set +a
./scripts/download.sh
```

### 5. Access Logging

**Enable nginx access logs:**

Update docker-compose.yml:
```yaml
claudekit-server:
  volumes:
    - ./logs:/var/log/nginx
    - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

Create nginx.conf with logging:
```nginx
access_log /var/log/nginx/access.log;
error_log /var/log/nginx/error.log;
```

View logs:
```bash
tail -f scripts/logs/access.log
```

---

## Part 8: Monitoring & Alerting

### Basic Monitoring Script

```bash
#!/bin/bash
# check-deployment.sh

check_server() {
    if ! curl -s http://localhost:4567/releases/manifest.json > /dev/null; then
        echo "ERROR: nginx server unreachable"
        return 1
    fi
}

check_trigger() {
    if ! curl -s http://localhost:4568/health > /dev/null; then
        echo "ERROR: trigger server unreachable"
        return 1
    fi
}

check_disk() {
    usage=$(df scripts/releases | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$usage" -gt 80 ]; then
        echo "WARNING: Disk usage $usage% (clean old releases)"
    fi
}

check_containers() {
    if ! docker-compose ps | grep "Up" > /dev/null; then
        echo "ERROR: Containers not running"
        docker-compose up -d
    fi
}

# Run checks
check_containers && check_server && check_trigger && check_disk
echo "✓ All systems operational"
```

Run via cron:
```bash
*/15 * * * * /Volumes/Workplace/claudekit-engineer/check-deployment.sh 2>&1
```

---

## Part 9: Disaster Recovery

### Backup & Restore

**Backup releases:**
```bash
# Create backup
tar -czf claudekit-backup-$(date +%Y%m%d-%H%M%S).tar.gz \
    scripts/releases/ \
    scripts/docker-compose.yml

# Store offsite
aws s3 cp claudekit-backup-*.tar.gz s3://backup-bucket/
```

**Restore from backup:**
```bash
# Download backup
aws s3 cp s3://backup-bucket/claudekit-backup-TIMESTAMP.tar.gz .

# Extract
tar -xzf claudekit-backup-TIMESTAMP.tar.gz

# Restart server
docker-compose up -d
```

### Container Rollback

**Keep version history:**
```bash
# Tag docker images with date
docker tag nginx:alpine claudekit-releases:2026-02-03
docker tag python:3.11 claudekit-trigger:2026-02-03

# Rollback if needed
docker-compose down
docker-compose up -d  # Uses latest tag, or update yml
```

---

## Checklist

### Pre-Deployment
- [ ] GitHub token created and tested
- [ ] Docker & Docker Compose installed
- [ ] Project directory structure verified
- [ ] Adequate disk space (5GB+ recommended)

### Initial Deployment
- [ ] Releases generated via download.sh
- [ ] Manifest.json created and valid
- [ ] Docker containers start successfully
- [ ] Health endpoints respond (localhost:4567, 4568)
- [ ] Static files served correctly

### Post-Deployment
- [ ] User installation tested (all 3 methods)
- [ ] Backups created
- [ ] Monitoring script deployed
- [ ] Cron job for weekly updates configured
- [ ] Security hardening applied
- [ ] Documentation reviewed

### Ongoing
- [ ] Weekly release checks
- [ ] Monthly backup verification
- [ ] Container health monitoring
- [ ] Log review for errors
- [ ] User feedback monitoring

---

## Related Documentation

- [README.md](../README.md) - Quick start guide
- [Project Overview & PDR](./project-overview-pdr.md) - Requirements
- [System Architecture](./system-architecture.md) - Technical design
- [Code Standards](./code-standards.md) - Development guidelines
- [Codebase Summary](./codebase-summary.md) - File descriptions
