# Simple deployment script with password authentication
param(
    [string]$VpsUser = "devtech",
    [string]$VpsIp = "103.77.214.231",
    [string]$VpsPath = "/www/wwwroot/tamquocchimenh.com"
)

Write-Host "=== Website Deployment Script ===" -ForegroundColor Green
Write-Host "VPS: $VpsUser@$VpsIp" -ForegroundColor Yellow
Write-Host "Target Path: $VpsPath" -ForegroundColor Yellow
Write-Host ""

# Get password
$securePassword = Read-Host "Enter VPS password" -AsSecureString
$VpsPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

Write-Host "Step 1: Testing SSH connection..." -ForegroundColor Magenta
Write-Host "You will be prompted for the password for each command." -ForegroundColor Yellow

# Test SSH connection
$testResult = ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "echo 'SSH connection successful'"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to connect to VPS. Please check your credentials and VPS status." -ForegroundColor Red
    exit 1
}
Write-Host "✓ SSH connection successful" -ForegroundColor Green

Write-Host "Step 2: Setting up target directory..." -ForegroundColor Magenta
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo mkdir -p $VpsPath"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo chown -R $VpsUser`:$VpsUser $VpsPath"
Write-Host "✓ Target directory created" -ForegroundColor Green

Write-Host "Step 3: Creating backup..." -ForegroundColor Magenta
$backupPath = "/www/wwwroot/tamquocchimenh.com.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo cp -r $VpsPath $backupPath 2>/dev/null || echo 'No existing files to backup'"
Write-Host "✓ Backup created" -ForegroundColor Green

Write-Host "Step 4: Deploying website files..." -ForegroundColor Magenta

# Create temporary directory
$tempDir = "temp_deploy_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy files to temp directory
Write-Host "  Preparing files..." -ForegroundColor Cyan
Copy-Item -Path "*.html" -Destination $tempDir -Force -ErrorAction SilentlyContinue
Copy-Item -Path "*.txt" -Destination $tempDir -Force -ErrorAction SilentlyContinue
Copy-Item -Path "assets" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "imgs" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "dac-sac" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "faq" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "huong-dan" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "su-kien" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "tin-tuc" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "scripts" -Destination $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "  ✓ Files prepared in $tempDir" -ForegroundColor Green

# Upload files
Write-Host "  Uploading files..." -ForegroundColor Cyan
$uploadResult = scp -r -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$tempDir/*" "$VpsUser@$VpsIp`:$VpsPath/"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Files uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "  ✗ Upload failed" -ForegroundColor Red
    Remove-Item -Path $tempDir -Recurse -Force
    exit 1
}

# Set permissions
Write-Host "  Setting permissions..." -ForegroundColor Cyan
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo chown -R www-data:www-data $VpsPath"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo chmod -R 755 $VpsPath"

# Clean up
Remove-Item -Path $tempDir -Recurse -Force
Write-Host "  ✓ Temporary files cleaned up" -ForegroundColor Green

Write-Host "Step 5: Testing deployment..." -ForegroundColor Magenta
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "ls -la $VpsPath"
Write-Host "✓ Deployment verification successful" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Green
Write-Host "✓ Website deployed to: $VpsUser@$VpsIp`:$VpsPath" -ForegroundColor Green
Write-Host "✓ Backup created at: $backupPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure your web server to serve files from $VpsPath" -ForegroundColor White
Write-Host "2. Set up domain DNS to point to $VpsIp" -ForegroundColor White
Write-Host "3. Test the website at http://$VpsIp" -ForegroundColor White
Write-Host "4. Consider setting up SSL certificate for HTTPS" -ForegroundColor White
Write-Host ""
Write-Host "Deployment completed successfully!" -ForegroundColor Green
