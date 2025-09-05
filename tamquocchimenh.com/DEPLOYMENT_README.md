# Website Deployment Guide

This guide explains how to deploy the tamquocchimenh.com website to your VPS.

## Prerequisites

### 1. SSH Access
- Ensure you have SSH access to your VPS
- Your VPS should be running and accessible at `103.77.214.231`
- Username: `devtech`

### 2. Required Tools
- **PowerShell** (Windows) or **Bash** (Linux/Mac)
- **OpenSSH** client (usually included with Git for Windows)
- **SCP** for file transfer

### 3. SSH Key Setup
Generate an SSH key pair if you don't have one:
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

## Deployment Scripts

### PowerShell Script (Windows)
```powershell
.\deploy_to_vps.ps1
```

### Bash Script (Linux/Mac)
```bash
chmod +x deploy_to_vps.sh
./deploy_to_vps.sh
```

## Script Options

### PowerShell Options
```powershell
# Basic deployment
.\deploy_to_vps.ps1

# Skip SSH key setup
.\deploy_to_vps.ps1 -SkipSshKey

# Dry run (show what would be done)
.\deploy_to_vps.ps1 -DryRun

# Custom parameters
.\deploy_to_vps.ps1 -VpsUser "customuser" -VpsIp "192.168.1.100"
```

### Bash Options
```bash
# Basic deployment
./deploy_to_vps.sh

# Skip SSH key setup
./deploy_to_vps.sh --skip-ssh-key

# Dry run (show what would be done)
./deploy_to_vps.sh --dry-run

# Show help
./deploy_to_vps.sh --help
```

## What the Script Does

1. **Tests SSH Connection** - Verifies connectivity to the VPS
2. **Adds SSH Key** - Adds your public key to `~/.ssh/authorized_keys`
3. **Creates Target Directory** - Sets up `/www/wwwroot/tamquocchimenh.com`
4. **Creates Backup** - Backs up existing files (if any)
5. **Deploys Files** - Uploads all website files to the VPS
6. **Sets Permissions** - Configures proper file permissions for web server
7. **Verifies Deployment** - Confirms files were uploaded successfully

## Post-Deployment Configuration

### 1. Web Server Setup
Configure your web server (Apache/Nginx) to serve files from `/www/wwwroot/tamquocchimenh.com`

#### Nginx Configuration Example
```nginx
server {
    listen 80;
    server_name tamquocchimenh.com www.tamquocchimenh.com;
    root /www/wwwroot/tamquocchimenh.com;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

#### Apache Configuration Example
```apache
<VirtualHost *:80>
    ServerName tamquocchimenh.com
    ServerAlias www.tamquocchimenh.com
    DocumentRoot /www/wwwroot/tamquocchimenh.com
    
    <Directory /www/wwwroot/tamquocchimenh.com>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

### 2. DNS Configuration
Point your domain to the VPS IP: `103.77.214.231`

### 3. SSL Certificate (Recommended)
Set up SSL certificate for HTTPS:
```bash
# Using Let's Encrypt (Certbot)
sudo certbot --nginx -d tamquocchimenh.com -d www.tamquocchimenh.com
```

## File Structure

The deployment includes:
- `index.html` - Main homepage
- `assets/` - CSS, JS, images, videos, APK files
- `imgs/` - Additional images
- `dac-sac/` - Feature pages
- `faq/` - FAQ pages
- `huong-dan/` - Guide pages
- `su-kien/` - Event pages
- `tin-tuc/` - News pages
- `scripts/` - Utility scripts

## Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connection manually
ssh devtech@103.77.214.231

# Check SSH key
ssh-add -l

# Generate new SSH key
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

### Permission Issues
```bash
# Fix file permissions on VPS
sudo chown -R www-data:www-data /www/wwwroot/tamquocchimenh.com
sudo chmod -R 755 /www/wwwroot/tamquocchimenh.com
```

### Web Server Issues
```bash
# Check web server status
sudo systemctl status nginx
sudo systemctl status apache2

# Restart web server
sudo systemctl restart nginx
sudo systemctl restart apache2
```

## Security Considerations

1. **SSH Key Security** - Keep your private key secure
2. **File Permissions** - Ensure proper permissions are set
3. **Firewall** - Configure firewall to allow HTTP/HTTPS traffic
4. **SSL Certificate** - Use HTTPS for production
5. **Regular Backups** - The script creates backups, but consider additional backup strategies

## Support

If you encounter issues:
1. Check the script output for error messages
2. Verify VPS connectivity and SSH access
3. Ensure web server is properly configured
4. Check file permissions and ownership

## Configuration File

The `deploy_config.json` file contains deployment settings that can be modified as needed.

---

**Note**: This deployment script is designed for the tamquocchimenh.com website. Modify the configuration as needed for your specific setup.
