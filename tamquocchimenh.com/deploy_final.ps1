# Final deployment script with better permission handling
param(
    [string]$VpsUser = "devtech",
    [string]$VpsIp = "103.77.214.231",
    [string]$VpsPath = "/www/wwwroot/tamquocchimenh.com"
)

Write-Host "=== Website Deployment Script ===" -ForegroundColor Green
Write-Host "VPS: $VpsUser@$VpsIp" -ForegroundColor Yellow
Write-Host "Target Path: $VpsPath" -ForegroundColor Yellow
Write-Host ""

Write-Host "Step 1: Testing SSH connection..." -ForegroundColor Magenta
Write-Host "You will be prompted for the password for each command." -ForegroundColor Yellow

# Test SSH connection
$testResult = ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "echo 'SSH connection successful'"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to connect to VPS. Please check your credentials and VPS status." -ForegroundColor Red
    exit 1
}
Write-Host "SSH connection successful" -ForegroundColor Green

Write-Host "Step 2: Setting up target directory..." -ForegroundColor Magenta
# Try to create directory in user's home first, then move it
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "mkdir -p ~/temp_website"
Write-Host "Created temporary directory in home folder" -ForegroundColor Green

Write-Host "Step 3: Deploying website files..." -ForegroundColor Magenta

# Create temporary directory locally
$tempDir = "temp_deploy_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy files to temp directory
Write-Host "Preparing files..." -ForegroundColor Cyan
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

Write-Host "Files prepared in $tempDir" -ForegroundColor Green

# Upload files to user's home directory first
Write-Host "Uploading files to temporary location..." -ForegroundColor Cyan
$uploadResult = scp -r -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$tempDir/*" "$VpsUser@$VpsIp`:~/temp_website/"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Files uploaded successfully to temporary location" -ForegroundColor Green
} else {
    Write-Host "Upload failed" -ForegroundColor Red
    Remove-Item -Path $tempDir -Recurse -Force
    exit 1
}

# Clean up local temp directory
Remove-Item -Path $tempDir -Recurse -Force
Write-Host "Local temporary files cleaned up" -ForegroundColor Green

Write-Host "Step 4: Moving files to final location..." -ForegroundColor Magenta
Write-Host "Note: You may need to run these commands manually on the VPS:" -ForegroundColor Yellow
Write-Host "1. sudo mkdir -p $VpsPath" -ForegroundColor White
Write-Host "2. sudo cp -r ~/temp_website/* $VpsPath/" -ForegroundColor White
Write-Host "3. sudo chown -R www-data:www-data $VpsPath" -ForegroundColor White
Write-Host "4. sudo chmod -R 755 $VpsPath" -ForegroundColor White
Write-Host "5. rm -rf ~/temp_website" -ForegroundColor White

# Try to move files with sudo -i (interactive root shell)
Write-Host "Attempting to move files to final location with root privileges..." -ForegroundColor Cyan
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo -i mkdir -p $VpsPath"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo -i cp -r ~/temp_website/* $VpsPath/"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo -i chown -R www-data:www-data $VpsPath"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo -i chmod -R 755 $VpsPath"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "rm -rf ~/temp_website"

Write-Host "Step 5: Testing deployment..." -ForegroundColor Magenta
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "ls -la $VpsPath"
Write-Host "Deployment verification completed" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Green
Write-Host "Website files uploaded to: $VpsUser@$VpsIp`:$VpsPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Verify files are in the correct location: $VpsPath" -ForegroundColor White
Write-Host "2. Configure your web server to serve files from $VpsPath" -ForegroundColor White
Write-Host "3. Set up domain DNS to point to $VpsIp" -ForegroundColor White
Write-Host "4. Test the website at http://$VpsIp" -ForegroundColor White
Write-Host "5. Consider setting up SSL certificate for HTTPS" -ForegroundColor White
Write-Host ""
Write-Host "Deployment completed!" -ForegroundColor Green
