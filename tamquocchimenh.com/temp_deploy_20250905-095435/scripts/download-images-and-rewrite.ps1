$ErrorActionPreference = "Stop"

# Configuration
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ImagesDir = Join-Path $ProjectRoot "imgs"
if (-not (Test-Path $ImagesDir)) { New-Item -ItemType Directory -Path $ImagesDir | Out-Null }

$OldDomain = "chienloantamquoc.vn"
$NewDomain = "tamquocchimenh.com"

# Helper: compute filesystem-safe filename with short hash
function Get-SafeFileNameFromUrl {
	param([string]$Url)
	$uri = [System.Uri]$Url
	$path = [System.Web.HttpUtility]::UrlDecode($uri.AbsolutePath)
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
		throw
	}
}

function Replace-DomainReferences {
	param([string]$Text)
	$Text = $Text -replace [Regex]::Escape("https://" + $OldDomain), ("https://" + $NewDomain)
	$Text = $Text -replace [Regex]::Escape("http://" + $OldDomain), ("https://" + $NewDomain)
	$Text = $Text -replace $OldDomain, $NewDomain
	return $Text
}

function Rewrite-ImagesToLocal {
	param([string]$Text)
	# Patterns
	$imgSrcPattern = '<img[^>]*?\ssrc\s*=\s*"(https?://[^"]+)"'
	$linkIconPattern = '<link[^>]*?\srel\s*=\s*"([^"]*)"[^>]*?\shref\s*=\s*"(https?://[^"]+)"'
	$metaImagePattern = '<meta[^>]*?\s(?:property|name)\s*=\s*"(og:image|twitter:image|og:image:secure_url)"[^>]*?\scontent\s*=\s*"(https?://[^"]+)"'

	# Collect URLs to download and map to local
	$urlToLocal = @{}

	# img src
	[regex]::Matches($Text, $imgSrcPattern, 'IgnoreCase') | ForEach-Object {
		$u = $_.Groups[1].Value
		if (-not $urlToLocal.ContainsKey($u)) {
			try { $local = Save-ImageIfNeeded -Url $u; $urlToLocal[$u] = "imgs/$local" } catch { }
		}
	}
	# link rel icon
	[regex]::Matches($Text, $linkIconPattern, 'IgnoreCase') | ForEach-Object {
		$rel = $_.Groups[1].Value.ToLower()
		$u = $_.Groups[2].Value
		if ($rel -match 'icon' -and $u) {
			if (-not $urlToLocal.ContainsKey($u)) {
				try { $local = Save-ImageIfNeeded -Url $u; $urlToLocal[$u] = "imgs/$local" } catch { }
			}
		}
	}
	# meta og:image
	[regex]::Matches($Text, $metaImagePattern, 'IgnoreCase') | ForEach-Object {
		$u = $_.Groups[2].Value
		if (-not $urlToLocal.ContainsKey($u)) {
			try { $local = Save-ImageIfNeeded -Url $u; $urlToLocal[$u] = "imgs/$local" } catch { }
		}
	}

	# Replace occurrences only in attribute values (src|href|content) that match exact URLs
	foreach ($pair in $urlToLocal.GetEnumerator()) {
		$origEsc = [regex]::Escape($pair.Key)
		$patternSrc = '(src\s*=\s*")' + $origEsc + '(")'
		$patternHref = '(href\s*=\s*")' + $origEsc + '(")'
		$patternContent = '(content\s*=\s*")' + $origEsc + '(")'

		$Text = [regex]::Replace($Text, $patternSrc, { param($m) $m.Groups[1].Value + $pair.Value + $m.Groups[2].Value }, 'IgnoreCase')
		$Text = [regex]::Replace($Text, $patternHref, { param($m) $m.Groups[1].Value + $pair.Value + $m.Groups[2].Value }, 'IgnoreCase')
		$Text = [regex]::Replace($Text, $patternContent, { param($m) $m.Groups[1].Value + $pair.Value + $m.Groups[2].Value }, 'IgnoreCase')
	}

	return $Text
}

function Process-HtmlFile {
	param([string]$FilePath)
	Write-Host "Processing $FilePath"
	$original = Get-Content -Path $FilePath -Raw -Encoding UTF8

	# 1) First, rewrite images to local using original content
	$withLocalImages = Rewrite-ImagesToLocal -Text $original
	
	# 2) Then, update domain references on the resulting content
	$final = Replace-DomainReferences -Text $withLocalImages

	# Write back
	[System.IO.File]::WriteAllText($FilePath, $final, (New-Object System.Text.UTF8Encoding($false)))
}

# Iterate all HTML files
$files = Get-ChildItem -Path $ProjectRoot -Recurse -File -Include *.html, *.htm | Where-Object { $_.FullName -notmatch "\\imgs\\" }

$processed = 0
foreach ($f in $files) {
	try { Process-HtmlFile -FilePath $f.FullName; $processed++ } catch { Write-Warning "Failed to process $($f.FullName): $($_.Exception.Message)" }
}

Write-Host "Processed $processed HTML files. Images saved to $ImagesDir"
