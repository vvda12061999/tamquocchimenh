$ErrorActionPreference = "Stop"

# Configuration
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ImagesDir = Join-Path $ProjectRoot "imgs"
if (-not (Test-Path $ImagesDir)) { New-Item -ItemType Directory -Path $ImagesDir | Out-Null }

$OldDomain = "chienloantamquoc.vn"
$NewDomain = "tamquocchimenh.com"

# Helper: normalize URL host to the old domain so hashes/filenames match previously downloaded files
function Normalize-UrlForLocalLookup {
	param([string]$Url)
	try {
		$uri = [System.Uri]$Url
		if ($uri.Host -like "*tamquocchimenh.com") {
			$builder = New-Object System.UriBuilder $uri
			$builder.Host = $OldDomain
			return $builder.Uri.AbsoluteUri
		}
		return $Url
	} catch { return $Url }
}

# Helper: compute filesystem-safe filename with short hash (must mirror download-images.ps1)
function Get-SafeFileNameFromUrl {
	param([string]$Url)
	$uri = [System.Uri]$Url
	$path = [System.Uri]::UnescapeDataString($uri.AbsolutePath)
	$leaf = [System.IO.Path]::GetFileName($path)
	if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = "image" }
	$root = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
	$ext = [System.IO.Path]::GetExtension($leaf)
	if ([string]::IsNullOrWhiteSpace($ext)) { $ext = ".img" }
	$cleanRoot = ($root -replace "[^A-Za-z0-9_.-]","-")
	if ($cleanRoot.Length -gt 80) { $cleanRoot = $cleanRoot.Substring(0,80) }
	$sha256 = [System.Security.Cryptography.SHA256]::Create()
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($Url)
	$hash = ($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ''
	$suffix = $hash.Substring(0,10)
	return "$cleanRoot-$suffix$ext"
}

function Rewrite-ImagesToLocalPaths {
	param([string]$Text)
	# Patterns to find external image-like URLs
	$imgSrcPattern = '<img[^>]*?\ssrc\s*=\s*"(https?://[^"]+)"'
	$linkIconPattern = '<link[^>]*?\srel\s*=\s*"([^"]*)"[^>]*?\shref\s*=\s*"(https?://[^"]+)"'
	$metaImagePattern = '<meta[^>]*?\s(?:property|name)\s*=\s*"(og:image|twitter:image|og:image:secure_url)"[^>]*?\scontent\s*=\s*"(https?://[^"]+)"'

	# Map of original URL -> local replacement
	$urlToLocal = @{}

	[regex]::Matches($Text, $imgSrcPattern, 'IgnoreCase') | ForEach-Object {
		$u = $_.Groups[1].Value
		$norm = Normalize-UrlForLocalLookup -Url $u
		$localName = Get-SafeFileNameFromUrl -Url $norm
		$urlToLocal[$u] = "imgs/$localName"
	}

	[regex]::Matches($Text, $linkIconPattern, 'IgnoreCase') | ForEach-Object {
		$rel = $_.Groups[1].Value.ToLower()
		$u = $_.Groups[2].Value
		if ($rel -match 'icon') {
			$norm = Normalize-UrlForLocalLookup -Url $u
			$localName = Get-SafeFileNameFromUrl -Url $norm
			$urlToLocal[$u] = "imgs/$localName"
		}
	}

	[regex]::Matches($Text, $metaImagePattern, 'IgnoreCase') | ForEach-Object {
		$u = $_.Groups[2].Value
		$norm = Normalize-UrlForLocalLookup -Url $u
		$localName = Get-SafeFileNameFromUrl -Url $norm
		$urlToLocal[$u] = "imgs/$localName"
	}

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
	Write-Host "Rewriting $FilePath"
	$original = Get-Content -Path $FilePath -Raw -Encoding UTF8
	$rewritten = Rewrite-ImagesToLocalPaths -Text $original
	[System.IO.File]::WriteAllText($FilePath, $rewritten, (New-Object System.Text.UTF8Encoding($false)))
}

$files = Get-ChildItem -Path $ProjectRoot -Recurse -File -Include *.html, *.htm | Where-Object { $_.FullName -notmatch "\\imgs\\" }

$processed = 0
foreach ($f in $files) {
	try { Process-HtmlFile -FilePath $f.FullName; $processed++ } catch { Write-Warning "Failed to rewrite $($f.FullName): $($_.Exception.Message)" }
}

Write-Host "Rewrote image references in $processed HTML files to local imgs paths."


