$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ImagesDir = Join-Path $ProjectRoot "imgs"

if (-not (Test-Path $ImagesDir)) { throw "imgs directory not found at $ImagesDir" }

function Get-ExistingImageMap {
	# Map of key (basename without trailing -hash, plus ext) -> full filename(s)
	$map = @{}
	Get-ChildItem -Path $ImagesDir -File | ForEach-Object {
		$name = $_.Name
		$ext = [System.IO.Path]::GetExtension($name)
		$stem = [System.IO.Path]::GetFileNameWithoutExtension($name)
		# split at last '-' to drop hash segment if present
		$idx = $stem.LastIndexOf('-')
		$keyStem = if ($idx -gt 0) { $stem.Substring(0, $idx) } else { $stem }
		$key = "$keyStem$ext".ToLower()
		if (-not $map.ContainsKey($key)) { $map[$key] = New-Object System.Collections.Generic.List[string] }
		$map[$key].Add($name)
	}
	return $map
}

function Try-ResolveLocalName {
	param([string]$LocalPath, [hashtable]$Map)
	# LocalPath like imgs/foo-bar-<hash>.png
	$leaf = [System.IO.Path]::GetFileName($LocalPath)
	$ext = [System.IO.Path]::GetExtension($leaf)
	$stem = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
	$idx = $stem.LastIndexOf('-')
	$keyStem = if ($idx -gt 0) { $stem.Substring(0, $idx) } else { $stem }
	$key = "$keyStem$ext".ToLower()
	if ($Map.ContainsKey($key)) {
		# Prefer exact same stem-length candidate if present
		$cands = $Map[$key]
		if ($cands.Count -eq 1) { return $cands[0] }
		# Pick the one whose base (before last -) equals keyStem
		foreach ($c in $cands) {
			$cs = [System.IO.Path]::GetFileNameWithoutExtension($c)
			$ci = $cs.LastIndexOf('-')
			$cb = if ($ci -gt 0) { $cs.Substring(0,$ci) } else { $cs }
			if ($cb -eq $keyStem) { return $c }
		}
		# fallback first
		return $cands[0]
	}
	return $null
}

function Fix-File {
	param([string]$FilePath, [hashtable]$Map)
	$original = Get-Content -Path $FilePath -Raw -Encoding UTF8
	$changed = $false

	# Pattern to capture imgs references in src, href, content
	$attrPatterns = @(
		'(src\s*=\s*")imgs/([^"]+)(")',
		'(href\s*=\s*")imgs/([^"]+)(")',
		'(content\s*=\s*")imgs/([^"]+)(")'
	)

	foreach ($pat in $attrPatterns) {
		$original = [regex]::Replace($original, $pat, {
			param($m)
			$prefix = $m.Groups[1].Value
			$name = $m.Groups[2].Value
			$suffix = $m.Groups[3].Value
			$full = Join-Path $ImagesDir $name
			if (Test-Path $full) { return $m.Value }
			$resolved = Try-ResolveLocalName -LocalPath ("imgs/" + $name) -Map $Map
			if ($resolved) { return $prefix + "imgs/" + $resolved + $suffix }
			return $m.Value
		}, 'IgnoreCase')
	}

	[System.IO.File]::WriteAllText($FilePath, $original, (New-Object System.Text.UTF8Encoding($false)))
}

$map = Get-ExistingImageMap

$files = Get-ChildItem -Path $ProjectRoot -Recurse -File -Include *.html, *.htm | Where-Object { $_.FullName -notmatch "\\imgs\\" }

$count = 0
foreach ($f in $files) {
	Write-Host "Fixing" $f.FullName
	Fix-File -FilePath $f.FullName -Map $map
	$count++
}

Write-Host "Attempted to fix image references in $count files using imgs directory index."


