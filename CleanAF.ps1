<# 
CleanAF — Desktop Cleaner & Organizer (by Zemmouri Digital Productions (CleanAF Edition))
Single-file PowerShell app.
- Leaves system/hidden icons (Recycle Bin, This PC) in place
- Keeps THIS script/app on the Desktop (won't move itself)
- Moves everything else into "Current Desktop" and sorts by type
#>

$ErrorActionPreference = "Stop"

# ----- Branding / Config -----
$BrandName   = "CleanAF"
$Company     = "Zemmouri Digital Productions (CleanAF Edition)"
$TargetRoot  = "Current Desktop"
$ShowSummary = $true

# Desktop path
$desktop = [Environment]::GetFolderPath('Desktop')

# Determine this script or exe path (so we don't move it)
try {
    # When packaged as EXE, $PSCommandPath is empty, but $MyInvocation.MyCommand.Path points to EXE
    $selfPath = $PSCommandPath
    if (-not $selfPath) { $selfPath = $MyInvocation.MyCommand.Path }
    $selfName = Split-Path -Leaf $selfPath
    $selfBase = [System.IO.Path]::GetFileNameWithoutExtension($selfName)
} catch {
    $selfPath = $null
    $selfName = $null
    $selfBase = $null
}

# Destination folder (timestamped if taken)
$target = Join-Path $desktop $TargetRoot
if (Test-Path -LiteralPath $target) {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $target = Join-Path $desktop "$TargetRoot $timestamp"
}
New-Item -ItemType Directory -Path $target -Force | Out-Null

# Extension map for type folders
$extMap = @{
    ".pdf"  = "PDF"
    ".doc"  = "Word";  ".docx" = "Word"
    ".xls"  = "Excel"; ".xlsx" = "Excel"
    ".ppt"  = "PowerPoint"; ".pptx" = "PowerPoint"
    ".jpg"  = "Images"; ".jpeg" = "Images"; ".png" = "Images"; ".gif" = "Images"; ".bmp" = "Images"; ".webp" = "Images"
    ".txt"  = "Text"; ".rtf" = "Text"; ".md" = "Text"
    ".zip"  = "Archives"; ".rar" = "Archives"; ".7z" = "Archives"; ".gz" = "Archives"
    ".mp3"  = "Audio"; ".wav" = "Audio"; ".m4a" = "Audio"; ".flac" = "Audio"
    ".mp4"  = "Video"; ".mov" = "Video"; ".mkv" = "Video"; ".avi" = "Video"
    ".lnk"  = "Shortcuts"
    ".ps1"  = "Scripts"; ".bat" = "Scripts"; ".cmd" = "Scripts"; ".vbs" = "Scripts"; ".py" = "Scripts"; ".js" = "Scripts"
    ".exe"  = "Apps"; ".msi" = "Apps"
}

# Tracking
$counts = [ordered]@{
    PDF=0; Word=0; Excel=0; PowerPoint=0; Images=0; Text=0; Archives=0; Audio=0; Video=0; Shortcuts=0; Scripts=0; Apps=0; Other=0; Folders=0
}

# Fancy header
Write-Host ("="*64)
Write-Host ("{0} — Desktop Cleaner & Organizer" -f $BrandName) -ForegroundColor Cyan
Write-Host ("Company: {0}" -f $Company) -ForegroundColor DarkGray
Write-Host ("Target: {0}" -f $target) -ForegroundColor DarkGray
Write-Host ("="*64)

# Helper: Resolve destination subfolder for a file extension
function Get-TypeFolder($ext) {
    $e = ($ext + "").ToLower()
    if ($extMap.ContainsKey($e)) { return $extMap[$e] }
    return "Other"
}

# Ensure a subfolder exists and return its path
function Ensure-Subfolder($name) {
    $p = Join-Path $target $name
    if (-not (Test-Path -LiteralPath $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
    }
    return $p
}

# Main move loop
Get-ChildItem -Path $desktop -Force | Where-Object {
    # Skip desktop.ini, system/hidden items, the target folder itself, and this script/app
    $_.Name -ne 'desktop.ini' -and
    $_.Name -ne (Split-Path -Leaf $target) -and
    -not $_.Attributes.HasFlag([IO.FileAttributes]::System) -and
    -not $_.Attributes.HasFlag([IO.FileAttributes]::Hidden) -and
    (
        # If we know our own file name, skip it (both script and compiled exe name)
        -not $selfName -or (
            $_.Name -ne $selfName -and
            # When compiled as exe, $selfBase.exe is the app; when script, $selfBase.ps1 is this file
            $_.Name -ne ("{0}.exe" -f $selfBase) -and
            $_.Name -ne ("{0}.ps1" -f $selfBase) -and
            $_.FullName -ne $selfPath
        )
    )
} | ForEach-Object {
    try {
        if (-not $_.PSIsContainer) {
            $folderName = Get-TypeFolder $_.Extension
            $destFolder = Ensure-Subfolder $folderName

            # Handle duplicates by appending a number
            $destPath = Join-Path $destFolder $_.Name
            $i = 1
            while (Test-Path -LiteralPath $destPath) {
                $nameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                $ext       = [System.IO.Path]::GetExtension($_.Name)
                $destPath  = Join-Path $destFolder ("{0} ({1}){2}" -f $nameNoExt,$i,$ext)
                $i++
            }
            Move-Item -LiteralPath $_.FullName -Destination $destPath -Force
            $counts[$folderName]++
        } else {
            $destFolder = Ensure-Subfolder "Folders"
            $destPath   = Join-Path $destFolder $_.Name
            $i = 1
            while (Test-Path -LiteralPath $destPath) {
                $destPath = Join-Path $destFolder ("{0} ({1})" -f $_.Name,$i)
                $i++
            }
            Move-Item -LiteralPath $_.FullName -Destination $destPath -Force
            $counts["Folders"]++
        }
    } catch {
        Write-Host "Skipped: $($_.FullName) — $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($ShowSummary) {
    Write-Host ("-"*64)
    Write-Host "Summary:" -ForegroundColor Cyan
    foreach ($k in $counts.Keys) {
        if ($counts[$k] -gt 0) { Write-Host ("{0,-12} : {1,5}" -f $k, $counts[$k]) }
    }
    Write-Host ("-"*64)
    Write-Host "Done. Your desktop is organized. Keep shining ✨" -ForegroundColor Green
}
