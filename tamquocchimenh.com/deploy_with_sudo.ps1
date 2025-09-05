# Deployment script with proper sudo handling
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
# Create temporary directory in user's home
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

Write-Host "Step 4: Moving files to final location with root privileges..." -ForegroundColor Magenta

# Create a script to run all sudo commands in one session
$sudoScript = @"
#!/bin/bash
mkdir -p $VpsPath
cp -r ~/temp_website/* $VpsPath/
chown -R www-data:www-data $VpsPath
chmod -R 755 $VpsPath
rm -rf ~/temp_website
echo "Files moved successfully to $VpsPath"
"@

# Write the script to a temporary file
$sudoScript | Out-File -FilePath "temp_sudo_script.sh" -Encoding UTF8

# Upload the script to the VPS
scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "temp_sudo_script.sh" "$VpsUser@$VpsIp`:~/"

# Make the script executable and run it with sudo
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "chmod +x ~/temp_sudo_script.sh"
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "sudo ~/temp_sudo_script.sh"

# Clean up the script file
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "rm ~/temp_sudo_script.sh"
Remove-Item "temp_sudo_script.sh" -Force

Write-Host "Step 5: Testing deployment..." -ForegroundColor Magenta
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" "ls -la $VpsPath"
Write-Host "Deployment verification completed" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Green
Write-Host "Website files deployed to: $VpsUser@$VpsIp`:$VpsPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Verify files are in the correct location: $VpsPath" -ForegroundColor White
Write-Host "2. Configure your web server to serve files from $VpsPath" -ForegroundColor White
Write-Host "3. Set up domain DNS to point to $VpsIp" -ForegroundColor White
Write-Host "4. Test the website at http://$VpsIp" -ForegroundColor White
Write-Host "5. Consider setting up SSL certificate for HTTPS" -ForegroundColor White
Write-Host ""
Write-Host "Deployment completed!" -ForegroundColor Green
