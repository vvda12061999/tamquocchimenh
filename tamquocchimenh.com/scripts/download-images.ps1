$ErrorActionPreference = "Stop"

# Configuration
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ImagesDir = Join-Path $ProjectRoot "imgs"
if (-not (Test-Path $ImagesDir)) { New-Item -ItemType Directory -Path $ImagesDir | Out-Null }

# Helper: compute filesystem-safe filename with short hash
function Get-SafeFileNameFromUrl {
	param([string]$Url)
	$uri = [System.Uri]$Url
	$path = [System.Uri]::UnescapeDataString($uri.AbsolutePath)
	$leaf = [System.IO.Path]::GetFileName($path)
	if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = "image" }
	$root = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
	$ext = [System.IO.Path]::GetExtension($leaf)
	if ([string]::IsNullOrWhiteSpace($ext)) { $ext = ".img" }
	# Clean invalid chars
	$cleanRoot = ($root -replace "[^A-Za-z0-9_.-]","-")
	if ($cleanRoot.Length -gt 80) { $cleanRoot = $cleanRoot.Substring(0,80) }
	# Hash suffix for uniqueness
	$sha256 = [System.Security.Cryptography.SHA256]::Create()
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($Url)
	$hash = ($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ''
	$suffix = $hash.Substring(0,10)
	return "$cleanRoot-$suffix$ext"
}

# Helper: download file if not exists
function Save-ImageIfNeeded {
	param([string]$Url)
	$filename = Get-SafeFileNameFromUrl -Url $Url
	$targetPath = Join-Path $ImagesDir $filename
	if (Test-Path $targetPath) {
		$info = Get-Item $targetPath
		if ($info.Length -gt 0) { return $filename }
	}
	try {
		$progressPreference = 'SilentlyContinue'
		Invoke-WebRequest -Uri $Url -OutFile $targetPath -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edge/127' }
		return $filename
	} catch {
		Write-Warning "Failed to download $Url : $($_.Exception.Message)"
	}
}

# Collect URLs from HTML content
function Get-ExternalImageUrlsFromText {
	param([string]$Text)
	$urls = New-Object System.Collections.Generic.HashSet[string]
	$imgSrcPattern = '<img[^>]*?\ssrc\s*=\s*"(https?://[^"]+)"'
	$linkIconPattern = '<link[^>]*?\srel\s*=\s*"([^"]*)"[^>]*?\shref\s*=\s*"(https?://[^"]+)"'
	$metaImagePattern = '<meta[^>]*?\s(?:property|name)\s*=\s*"(og:image|twitter:image|og:image:secure_url)"[^>]*?\scontent\s*=\s*"(https?://[^"]+)"'

	[regex]::Matches($Text, $imgSrcPattern, 'IgnoreCase') | ForEach-Object {
		$urls.Add($_.Groups[1].Value) | Out-Null
	}
	[regex]::Matches($Text, $linkIconPattern, 'IgnoreCase') | ForEach-Object {
		$rel = $_.Groups[1].Value.ToLower()
		$u = $_.Groups[2].Value
		if ($rel -match 'icon') { $urls.Add($u) | Out-Null }
	}
	[regex]::Matches($Text, $metaImagePattern, 'IgnoreCase') | ForEach-Object {
		$urls.Add($_.Groups[2].Value) | Out-Null
	}
	return $urls
}

$files = Get-ChildItem -Path $ProjectRoot -Recurse -File -Include *.html, *.htm | Where-Object { $_.FullName -notmatch "\\imgs\\" }
$all = New-Object System.Collections.Generic.HashSet[string]

foreach ($f in $files) {
	Write-Host "Scanning $($f.FullName)"
	$text = Get-Content -Path $f.FullName -Raw -Encoding UTF8
	(Get-ExternalImageUrlsFromText -Text $text) | ForEach-Object { $all.Add($_) | Out-Null }
}

Write-Host "Found $($all.Count) external image URLs. Starting downloads..."
$downloaded = 0
foreach ($u in $all) {
	$fn = Save-ImageIfNeeded -Url $u
	if ($fn) { $downloaded++ }
}
Write-Host "Downloaded $downloaded files into $ImagesDir"


