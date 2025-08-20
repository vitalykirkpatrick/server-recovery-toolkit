# 🔄 SERVER RESTORATION GUIDE

## 📋 OVERVIEW

This guide provides step-by-step instructions for restoring your n8n server from backups when the server is completely wiped out. The restoration process supports both **minimal backups** (stored in Google Drive) and **full backups** (stored in GitHub).

## 🎯 BACKUP TYPES

### 📦 **Minimal Backup** (Google Drive)
**What it includes:**
- `/etc/nginx` - Nginx configuration
- `/etc/netplan` - Network configuration  
- `/root/.n8n` - n8n workflows and settings
- `/root/.env` - Environment variables
- `manual-packages.txt` - List of manually installed packages

**Storage:** Google Drive folder ID: `1-MX-npKbEj6lsEXjzoRbLmlPUu8O--kI`

### 💽 **Full Backup** (GitHub)
**What it includes:**
- `/etc/nginx` - Nginx configuration
- `/etc/systemd/system` - System services
- `/root/.n8n` - n8n workflows and settings
- `/var/lib/docker` - Docker data (if present)
- All configurations and data

**Storage:** GitHub repository with Git LFS support

## 🚨 EMERGENCY RESTORATION PROCEDURE

### **STEP 1: Access VNC Console**

1. **Log into your hosting provider's control panel**
2. **Access VNC console** (usually under "Console" or "Remote Access")
3. **Boot into recovery mode** or fresh Ubuntu installation
4. **Log in as root** or use `sudo su -` to become root

### **STEP 2: Download Restoration Script**

```bash
# Download the restoration script
wget -O restore.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/server_restore_script.sh

# Make it executable
chmod +x restore.sh

# Run the script
sudo ./restore.sh
```

### **STEP 3: Choose Restoration Type**

The script will show an interactive menu:

```
============================================
🔄 SERVER RESTORATION SCRIPT
============================================
1. Restore from Minimal Backup (Google Drive)
2. Restore from Full Backup (GitHub)
3. List Available Backups
4. Setup Credentials Only
5. Install Base Packages Only
6. Exit
============================================
```

## 🔑 CREDENTIALS REQUIRED

### **For Google Drive (Minimal Backups):**
- **Google Client ID**
- **Google Client Secret** 
- **Google Refresh Token**

### **For GitHub (Full Backups):**
- **GitHub Personal Access Token**
- **GitHub Repository** (format: `owner/repo`)
- **GitHub Branch** (usually `main`)

## 📋 DETAILED RESTORATION STEPS

### **OPTION 1: Minimal Backup Restoration**

1. **Select option 1** from the menu
2. **Provide Google Drive credentials** when prompted
3. **Choose backup from list** of available backups
4. **Wait for restoration** to complete

**What happens:**
- ✅ Downloads backup from Google Drive
- ✅ Installs base packages (nginx, postgresql, n8n, etc.)
- ✅ Restores configurations (`/etc/nginx`, `/etc/netplan`, `/root/.n8n`)
- ✅ Reinstalls manually installed packages
- ✅ Configures and starts services
- ✅ Sets up firewall and security

### **OPTION 2: Full Backup Restoration**

1. **Select option 2** from the menu
2. **Provide GitHub credentials** when prompted
3. **Choose backup from list** of available backups
4. **Wait for restoration** to complete

**What happens:**
- ✅ Downloads backup from GitHub
- ✅ Installs base packages
- ✅ Restores all configurations and data
- ✅ Restores systemd services
- ✅ Restores Docker data (if present)
- ✅ Configures and starts all services

## 🔧 MANUAL RESTORATION (If Script Fails)

### **Download Backup Manually**

#### **From Google Drive:**
```bash
# Get access token (replace with your credentials)
TOKEN_RESPONSE=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d client_id="YOUR_CLIENT_ID" \
  -d client_secret="YOUR_CLIENT_SECRET" \
  -d refresh_token="YOUR_REFRESH_TOKEN" \
  -d grant_type=refresh_token)

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r .access_token)

# Download backup (replace FILE_ID with actual file ID)
curl -L -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://www.googleapis.com/drive/v3/files/FILE_ID?alt=media" \
  -o backup.tar.gz
```

#### **From GitHub:**
```bash
# Download backup (replace with your repo and token)
curl -L -H "Authorization: token YOUR_GITHUB_TOKEN" \
  "https://api.github.com/repos/YOUR_REPO/contents/backup_file.tar.gz" \
  -o backup.tar.gz
```

### **Extract and Restore**

```bash
# Extract backup
tar -xzf backup.tar.gz -C /

# Install packages (for minimal backup)
if [ -f /root/manual-packages.txt ]; then
  while read package; do
    apt-get install -y "$package"
  done < /root/manual-packages.txt
fi

# Reload services
systemctl daemon-reload
systemctl restart nginx
systemctl restart postgresql
systemctl restart n8n
```

## 🛠️ POST-RESTORATION TASKS

### **1. Verify Services**
```bash
# Check service status
systemctl status nginx
systemctl status postgresql  
systemctl status n8n

# Check listening ports
netstat -tlnp | grep -E ":(22|80|443|5678|5432)"
```

### **2. Test Web Access**
- **n8n Interface:** `https://your-domain.com` or `http://your-ip:5678`
- **Login:** admin / n8n_1752790771 (or your configured credentials)

### **3. Update DNS (if needed)**
- **Point your domain** to the new server IP
- **Update Cloudflare** DNS records if using Cloudflare

### **4. Restore SSL Certificates**
```bash
# If using Let's Encrypt
certbot --nginx -d your-domain.com

# Test SSL renewal
certbot renew --dry-run
```

### **5. Update Firewall**
```bash
# Enable firewall
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# Check status
ufw status
```

## 🔍 TROUBLESHOOTING

### **Common Issues:**

#### **1. "No backups found"**
- ✅ Check credentials are correct
- ✅ Verify backup folder/repository exists
- ✅ Ensure backups were actually created

#### **2. "Package installation failed"**
- ✅ Update package lists: `apt-get update`
- ✅ Fix broken packages: `apt-get -f install`
- ✅ Skip failed packages and continue

#### **3. "Service failed to start"**
- ✅ Check service logs: `journalctl -u service-name`
- ✅ Verify configuration files
- ✅ Check port conflicts

#### **4. "n8n not accessible"**
- ✅ Check if n8n service is running: `systemctl status n8n`
- ✅ Verify port 5678 is open: `netstat -tlnp | grep 5678`
- ✅ Check nginx proxy configuration

### **Emergency Commands:**

```bash
# Force restart all services
systemctl daemon-reload
systemctl restart nginx postgresql redis-server n8n

# Check system resources
df -h          # Disk usage
free -h        # Memory usage
top            # Running processes

# Network diagnostics
ip addr show   # Network interfaces
ping 8.8.8.8   # Internet connectivity
```

## 📊 RESTORATION VERIFICATION CHECKLIST

After restoration, verify these items:

- [ ] **SSH Access:** Can connect via SSH
- [ ] **Web Server:** Nginx is running and accessible
- [ ] **Database:** PostgreSQL is running
- [ ] **n8n Service:** n8n is running on port 5678
- [ ] **n8n Web Interface:** Can access n8n login page
- [ ] **Workflows:** n8n workflows are restored
- [ ] **SSL Certificates:** HTTPS is working (if applicable)
- [ ] **Firewall:** UFW is enabled with correct rules
- [ ] **DNS:** Domain points to correct IP
- [ ] **Backups:** Backup scripts are functional

## 🎯 PREVENTION TIPS

### **Regular Backup Testing:**
- **Test restoration** on a separate server monthly
- **Verify backup integrity** regularly
- **Update credentials** before they expire

### **Documentation:**
- **Keep credentials** in a secure password manager
- **Document any custom configurations** not in backups
- **Maintain server inventory** of installed software

### **Monitoring:**
- **Set up backup monitoring** to alert on failures
- **Monitor disk space** to prevent backup storage issues
- **Test backup downloads** periodically

## 🆘 EMERGENCY CONTACTS

**If restoration fails completely:**

1. **Contact hosting provider** for server rebuild
2. **Use backup verification** to confirm data integrity
3. **Consider professional recovery services** for critical data
4. **Document lessons learned** for future improvements

## 📞 SUPPORT RESOURCES

- **Hosting Provider Support:** For server access issues
- **GitHub Support:** For repository access problems  
- **Google Drive Support:** For storage access issues
- **n8n Community:** For workflow restoration help

---

**Remember:** This restoration process will completely rebuild your server. Ensure you have all necessary credentials and access before starting the restoration process.

