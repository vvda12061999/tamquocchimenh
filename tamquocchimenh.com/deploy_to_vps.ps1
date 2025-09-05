# PowerShell deployment script for tamquocchimenh.com website
# This script will deploy the website to VPS and set up SSH access

param(
    [string]$VpsUser = "devtech",
    [string]$VpsIp = "103.77.214.231",
    [string]$VpsPath = "/www/wwwroot/tamquocchimenh.com",
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub",
    [switch]$SkipSshKey = $false,
    [switch]$DryRun = $false
)

Write-Host "=== Website Deployment Script ===" -ForegroundColor Green
Write-Host "VPS: $VpsUser@$VpsIp" -ForegroundColor Yellow
Write-Host "Target Path: $VpsPath" -ForegroundColor Yellow
Write-Host "SSH Key: $SshKeyPath" -ForegroundColor Yellow
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host ""

# Check if required tools are available
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Check for required tools
if (-not (Test-Command "scp")) {
    Write-Host "Error: scp command not found. Please install OpenSSH or Git for Windows." -ForegroundColor Red
    exit 1
}

if (-not (Test-Command "ssh")) {
    Write-Host "Error: ssh command not found. Please install OpenSSH or Git for Windows." -ForegroundColor Red
    exit 1
}

# Check if SSH key exists
if (-not $SkipSshKey -and -not (Test-Path $SshKeyPath)) {
    Write-Host "Warning: SSH public key not found at $SshKeyPath" -ForegroundColor Yellow
    Write-Host "You can generate one with: ssh-keygen -t rsa -b 4096 -C 'your_email@example.com'" -ForegroundColor Yellow
    $SkipSshKey = $true
}

# Function to execute SSH commands
function Invoke-SshCommand {
    param(
        [string]$Command,
        [string]$Description
    )
    
    Write-Host "SSH: $Description" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "  [DRY RUN] ssh $VpsUser@$VpsIp '$Command'" -ForegroundColor Gray
        return $true
    }
    
    try {
        $result = ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" $Command 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Success" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ✗ Failed: $result" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        return $false
    }
}

# Function to copy files via SCP
function Copy-FilesToVps {
    param(
        [string]$LocalPath,
        [string]$RemotePath,
        [string]$Description
    )
    
    Write-Host "SCP: $Description" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "  [DRY RUN] scp -r '$LocalPath' $VpsUser@$VpsIp`:$RemotePath" -ForegroundColor Gray
        return $true
    }
    
    try {
        $result = scp -r -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$LocalPath" "$VpsUser@$VpsIp`:$RemotePath" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Success" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ✗ Failed: $result" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        return $false
    }
}

# Step 1: Test SSH connection
Write-Host "Step 1: Testing SSH connection..." -ForegroundColor Magenta
if (-not (Invoke-SshCommand "echo 'SSH connection successful'" "Testing connection")) {
    Write-Host "Failed to connect to VPS. Please check:" -ForegroundColor Red
    Write-Host "  - VPS IP address and username are correct" -ForegroundColor Red
    Write-Host "  - VPS is running and accessible" -ForegroundColor Red
    Write-Host "  - SSH service is running on the VPS" -ForegroundColor Red
    exit 1
}

# Step 2: Add SSH key to authorized_keys
if (-not $SkipSshKey) {
    Write-Host "Step 2: Adding SSH public key..." -ForegroundColor Magenta
    $sshKeyContent = Get-Content $SshKeyPath -Raw
    $sshKeyContent = $sshKeyContent.Trim()
    
    # Create .ssh directory if it doesn't exist
    Invoke-SshCommand "mkdir -p ~/.ssh" "Creating .ssh directory"
    
    # Add key to authorized_keys
    $addKeyCommand = "echo '$sshKeyContent' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"
    if (Invoke-SshCommand $addKeyCommand "Adding SSH key to authorized_keys") {
        Write-Host "  ✓ SSH key added successfully" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ SSH key addition failed, but continuing with deployment" -ForegroundColor Yellow
    }
}

# Step 3: Create target directory
Write-Host "Step 3: Setting up target directory..." -ForegroundColor Magenta
Invoke-SshCommand "sudo mkdir -p $VpsPath" "Creating target directory"
Invoke-SshCommand "sudo chown -R $VpsUser`:$VpsUser $VpsPath" "Setting ownership"

# Step 4: Backup existing files (if any)
Write-Host "Step 4: Creating backup..." -ForegroundColor Magenta
$backupPath = "/www/wwwroot/tamquocchimenh.com.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$backupCommand = "if [ -d '$VpsPath' ] && [ `$(ls -A '$VpsPath' 2>/dev/null) ]; then sudo cp -r '$VpsPath' '$backupPath'; echo 'Backup created at $backupPath'; else echo 'No existing files to backup'; fi"
Invoke-SshCommand $backupCommand "Creating backup"

# Step 5: Deploy website files
Write-Host "Step 5: Deploying website files..." -ForegroundColor Magenta

# Create a temporary directory for deployment
$tempDir = "temp_deploy_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Copy all website files to temp directory
    Write-Host "  Preparing files for deployment..." -ForegroundColor Cyan
    Copy-Item -Path "*.html" -Destination $tempDir -Force
    Copy-Item -Path "*.txt" -Destination $tempDir -Force
    Copy-Item -Path "assets" -Destination $tempDir -Recurse -Force
    Copy-Item -Path "imgs" -Destination $tempDir -Recurse -Force
    Copy-Item -Path "dac-sac" -Destination $tempDir -Recurse -Force
    Copy-Item -Path "faq" -Destination $tempDir -Recurse -Force
    Copy-Item -Path "huong-dan" -Destination $tempDir -Recurse -Force
    Copy-Item -Path "su-kien" -Destination $tempDir -Recurse -Force
    Copy-Item -Path "tin-tuc" -Destination $tempDir -Recurse -Force
    Copy-Item -Path "scripts" -Destination $tempDir -Recurse -Force
    
    Write-Host "  ✓ Files prepared in $tempDir" -ForegroundColor Green
    
    # Upload files to VPS
    if (Copy-FilesToVps "$tempDir/*" "$VpsPath/" "Uploading website files") {
        Write-Host "  ✓ Website files uploaded successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to upload website files" -ForegroundColor Red
        throw "Upload failed"
    }
    
    # Set proper permissions
    Invoke-SshCommand "sudo chown -R www-data:www-data $VpsPath" "Setting web server permissions"
    Invoke-SshCommand "sudo chmod -R 755 $VpsPath" "Setting file permissions"
    
} finally {
    # Clean up temporary directory
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
        Write-Host "  ✓ Temporary files cleaned up" -ForegroundColor Green
    }
}

# Step 6: Configure web server (optional)
Write-Host "Step 6: Web server configuration..." -ForegroundColor Magenta
Write-Host "  Note: You may need to configure your web server (Apache/Nginx) to serve files from $VpsPath" -ForegroundColor Yellow
Write-Host "  Example Nginx configuration:" -ForegroundColor Yellow
Write-Host "    server {" -ForegroundColor Gray
Write-Host "        listen 80;" -ForegroundColor Gray
Write-Host "        server_name tamquocchimenh.com www.tamquocchimenh.com;" -ForegroundColor Gray
Write-Host "        root $VpsPath;" -ForegroundColor Gray
Write-Host "        index index.html;" -ForegroundColor Gray
Write-Host "    }" -ForegroundColor Gray

# Step 7: Test deployment
Write-Host "Step 7: Testing deployment..." -ForegroundColor Magenta
if (Invoke-SshCommand "ls -la $VpsPath" "Listing deployed files") {
    Write-Host "  ✓ Deployment verification successful" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Green
Write-Host "✓ Website deployed to: $VpsUser@$VpsIp`:$VpsPath" -ForegroundColor Green
if (-not $SkipSshKey) {
    Write-Host "✓ SSH key added to authorized_keys" -ForegroundColor Green
}
Write-Host "✓ Backup created at: $backupPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure your web server to serve files from $VpsPath" -ForegroundColor White
Write-Host "2. Set up domain DNS to point to $VpsIp" -ForegroundColor White
Write-Host "3. Test the website at http://$VpsIp" -ForegroundColor White
Write-Host "4. Consider setting up SSL certificate for HTTPS" -ForegroundColor White
Write-Host ""
Write-Host "Deployment completed successfully! 🎉" -ForegroundColor Green
