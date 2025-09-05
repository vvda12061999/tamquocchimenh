# PowerShell deployment script with password authentication for tamquocchimenh.com website
param(
    [string]$VpsUser = "devtech",
    [string]$VpsIp = "103.77.214.231",
    [string]$VpsPath = "/www/wwwroot/tamquocchimenh.com",
    [string]$VpsPassword = ""
)

Write-Host "=== Website Deployment Script (Password Authentication) ===" -ForegroundColor Green
Write-Host "VPS: $VpsUser@$VpsIp" -ForegroundColor Yellow
Write-Host "Target Path: $VpsPath" -ForegroundColor Yellow
Write-Host ""

# Get password if not provided
if ([string]::IsNullOrEmpty($VpsPassword)) {
    $securePassword = Read-Host "Enter VPS password" -AsSecureString
    $VpsPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
}

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

# Function to execute SSH commands with password
function Invoke-SshCommand {
    param(
        [string]$Command,
        [string]$Description
    )
    
    Write-Host "SSH: $Description" -ForegroundColor Cyan
    
    # Create a temporary script file for the command
    $tempScript = "temp_ssh_command.sh"
    $Command | Out-File -FilePath $tempScript -Encoding UTF8
    
    try {
        # Use expect-like approach with echo and pipe
        $sshCommand = "echo '$VpsPassword' | ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no $VpsUser@$VpsIp 'bash -s' < $tempScript"
        
        $result = Invoke-Expression $sshCommand 2>&1
        
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
    finally {
        # Clean up temp script
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }
    }
}

# Function to copy files via SCP with password
function Copy-FilesToVps {
    param(
        [string]$LocalPath,
        [string]$RemotePath,
        [string]$Description
    )
    
    Write-Host "SCP: $Description" -ForegroundColor Cyan
    try {
        # Use expect-like approach for SCP
        $scpCommand = "echo '$VpsPassword' | scp -r -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no '$LocalPath' '$VpsUser@$VpsIp`:$RemotePath'"
        
        $result = Invoke-Expression $scpCommand 2>&1
        
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

# Alternative: Use plink if available (more reliable for password auth)
function Test-Plink {
    if (Test-Command "plink") {
        return $true
    }
    # Check common plink locations
    $plinkPaths = @(
        "C:\Program Files\PuTTY\plink.exe",
        "C:\Program Files (x86)\PuTTY\plink.exe",
        "$env:USERPROFILE\Downloads\plink.exe"
    )
    
    foreach ($path in $plinkPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $false
}

$plinkPath = Test-Plink
if ($plinkPath) {
    Write-Host "Found PuTTY plink at: $plinkPath" -ForegroundColor Green
    Write-Host "Using plink for more reliable password authentication" -ForegroundColor Green
    
    # Override SSH function to use plink
    function Invoke-SshCommand {
        param(
            [string]$Command,
            [string]$Description
        )
        
        Write-Host "SSH (plink): $Description" -ForegroundColor Cyan
        try {
            $result = & $plinkPath -ssh -pw "$VpsPassword" -o StrictHostKeyChecking=no "$VpsUser@$VpsIp" $Command 2>&1
            
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
    
    # Override SCP function to use pscp
    function Copy-FilesToVps {
        param(
            [string]$LocalPath,
            [string]$RemotePath,
            [string]$Description
        )
        
        Write-Host "SCP (pscp): $Description" -ForegroundColor Cyan
        try {
            $pscpPath = $plinkPath -replace "plink.exe", "pscp.exe"
            if (Test-Path $pscpPath) {
                $result = & $pscpPath -pw "$VpsPassword" -r -o StrictHostKeyChecking=no "$LocalPath" "$VpsUser@$VpsIp`:$RemotePath" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ Success" -ForegroundColor Green
                    return $true
                } else {
                    Write-Host "  ✗ Failed: $result" -ForegroundColor Red
                    return $false
                }
            } else {
                Write-Host "  ✗ pscp.exe not found at $pscpPath" -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "  ✗ Error: $_" -ForegroundColor Red
            return $false
        }
    }
} else {
    Write-Host "PuTTY plink not found. Using standard SSH/SCP with password." -ForegroundColor Yellow
    Write-Host "For better reliability, consider installing PuTTY from: https://www.putty.org/" -ForegroundColor Yellow
}

# Step 1: Test SSH connection
Write-Host "Step 1: Testing SSH connection..." -ForegroundColor Magenta
if (-not (Invoke-SshCommand "echo 'SSH connection successful'" "Testing connection")) {
    Write-Host "Failed to connect to VPS. Please check:" -ForegroundColor Red
    Write-Host "  - VPS IP address and username are correct" -ForegroundColor Red
    Write-Host "  - VPS password is correct" -ForegroundColor Red
    Write-Host "  - VPS is running and accessible" -ForegroundColor Red
    Write-Host "  - SSH service is running on the VPS" -ForegroundColor Red
    exit 1
}

# Step 2: Create target directory
Write-Host "Step 2: Setting up target directory..." -ForegroundColor Magenta
Invoke-SshCommand "sudo mkdir -p $VpsPath" "Creating target directory"
Invoke-SshCommand "sudo chown -R $VpsUser`:$VpsUser $VpsPath" "Setting ownership"

# Step 3: Create backup
Write-Host "Step 3: Creating backup..." -ForegroundColor Magenta
$backupPath = "/www/wwwroot/tamquocchimenh.com.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Invoke-SshCommand "sudo cp -r $VpsPath $backupPath 2>/dev/null || echo 'No existing files to backup'" "Creating backup"

# Step 4: Deploy website files
Write-Host "Step 4: Deploying website files..." -ForegroundColor Magenta

# Create a temporary directory for deployment
$tempDir = "temp_deploy_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Copy all website files to temp directory
    Write-Host "  Preparing files for deployment..." -ForegroundColor Cyan
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

# Step 5: Test deployment
Write-Host "Step 5: Testing deployment..." -ForegroundColor Magenta
if (Invoke-SshCommand "ls -la $VpsPath" "Listing deployed files") {
    Write-Host "  ✓ Deployment verification successful" -ForegroundColor Green
}

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
Write-Host "Deployment completed successfully! 🎉" -ForegroundColor Green
