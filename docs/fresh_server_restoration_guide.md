# 🚀 FRESH SERVER RESTORATION GUIDE

## Complete command sequence for restoring your server from scratch

### 📋 **PREREQUISITES**
- Fresh Ubuntu 22.04 server installation
- Root or sudo access
- Internet connectivity
- Domain: n8n.websolutionsserver.net pointing to server IP

---

## 🔧 **STEP 1: BASIC SYSTEM SETUP**

```bash
# Update system
apt update && apt upgrade -y

# Install essential packages
apt install -y curl wget git unzip zip htop nano vim net-tools

# Set timezone (optional)
timedatectl set-timezone UTC
```

---

## 📦 **STEP 2: INSTALL NODE.JS AND NPM**

```bash
# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Verify installation
node --version
npm --version
```

---

## 🌐 **STEP 3: INSTALL NGINX**

```bash
# Install nginx
apt install -y nginx

# Enable and start nginx
systemctl enable nginx
systemctl start nginx

# Check status
systemctl status nginx
```

---

## 🔧 **STEP 4: INSTALL N8N**

```bash
# Install n8n globally
npm install -g n8n

# Verify installation
n8n --version
```

---

## 📦 **STEP 5: INSTALL PM2 (PROCESS MANAGER)**

```bash
# Install PM2
npm install -g pm2

# Verify installation
pm2 --version
```

---

## 🗄️ **STEP 6: INSTALL POSTGRESQL (OPTIONAL)**

```bash
# Install PostgreSQL
apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Create n8n database (optional)
sudo -u postgres createdb n8n
```

---

## 🎧 **STEP 7: INSTALL AUDIOBOOK PROCESSING TOOLS**

```bash
# Install FFmpeg for audio processing
apt install -y ffmpeg

# Install ImageMagick for image processing
apt install -y imagemagick

# Install Tesseract OCR with Ukrainian and Russian support
apt install -y tesseract-ocr tesseract-ocr-ukr tesseract-ocr-rus

# Install Python packages for audiobook processing
pip3 install pydub mutagen openai requests beautifulsoup4 lxml
```

---

## 📥 **STEP 8: DOWNLOAD RESTORATION SCRIPT**

```bash
# Download the comprehensive restoration script
wget -O restore_from_github.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/fresh_server_complete_setup.sh

# Make it executable
chmod +x restore_from_github.sh
```

---

## 🔄 **STEP 9: RUN RESTORATION SCRIPT**

```bash
# Run the restoration script
sudo ./restore_from_github.sh
```

**This script will:**
- Download all your backed-up configurations from GitHub
- Restore n8n workflows and settings
- Configure nginx for public domain access
- Set up systemd services
- Configure firewall rules

---

## 🌐 **STEP 10: CONFIGURE N8N FOR PUBLIC DOMAIN**

```bash
# Download and run the public domain configurator
wget -O configure_public_domain.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/n8n_public_domain_configurator.sh

chmod +x configure_public_domain.sh
sudo ./configure_public_domain.sh
```

---

## 🔧 **STEP 11: SET UP AUTOMATED MAINTENANCE**

```bash
# Download and set up cron jobs for backups and cleanup
wget -O setup_cron.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/fix_cron_jobs.sh

chmod +x setup_cron.sh
sudo ./setup_cron.sh
```

---

## 🔥 **STEP 12: CONFIGURE FIREWALL**

```bash
# Install and configure UFW firewall
apt install -y ufw

# Allow SSH
ufw allow 22/tcp

# Allow HTTP
ufw allow 80/tcp

# Allow HTTPS (if you plan to use SSL)
ufw allow 443/tcp

# Enable firewall
ufw --force enable

# Check status
ufw status
```

---

## ✅ **STEP 13: VERIFY INSTALLATION**

```bash
# Check all services
systemctl status nginx n8n

# Test n8n access
curl -I http://127.0.0.1:5678

# Check PM2 processes
pm2 status

# Test public domain access (replace with your actual domain)
curl -I http://n8n.websolutionsserver.net
```

---

## 🎯 **ALTERNATIVE: ONE-COMMAND RESTORATION**

If you want to run everything in one command after fresh installation:

```bash
# Complete restoration in one command
curl -fsSL https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/one_command_restore.sh | sudo bash
```

---

## 📊 **EXPECTED RESULTS**

After completing all steps:

✅ **n8n accessible at:** `http://n8n.websolutionsserver.net`  
✅ **Login credentials:** `admin` / `n8n_1752790771`  
✅ **All workflows restored** from GitHub backup  
✅ **Webhook URLs using public domain**  
✅ **Automated backups scheduled**  
✅ **System cleanup scheduled**  
✅ **Firewall properly configured**  

---

## 🔧 **TROUBLESHOOTING**

If any step fails:

```bash
# Check service logs
journalctl -u nginx -f
journalctl -u n8n -f

# Check PM2 logs
pm2 logs

# Test connectivity
ping google.com
curl -I http://127.0.0.1

# Check firewall
ufw status verbose

# Check DNS resolution
nslookup n8n.websolutionsserver.net
```

---

## 📞 **SUPPORT COMMANDS**

```bash
# Download emergency recovery script
wget -O emergency_recovery.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/emergency_vnc_recovery.sh

# Download system diagnostics
wget -O diagnostics.sh https://raw.githubusercontent.com/vitalykirkpatrick/server-recovery-toolkit/main/scripts/smart_system_diagnostics_and_restore.sh
```

---

## 🎊 **FINAL VERIFICATION**

1. **Access n8n:** Open `http://n8n.websolutionsserver.net` in browser
2. **Login:** Use `admin` / `n8n_1752790771`
3. **Check workflows:** Verify all workflows are restored
4. **Test webhooks:** Check that webhook URLs use public domain
5. **Verify automation:** Confirm backup and cleanup scripts are scheduled

---

**🎉 Your server should now be fully restored and accessible via public domain!**

