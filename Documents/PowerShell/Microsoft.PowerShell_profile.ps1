## PoweShell Profile version 1.00 2025-05-15

# =============================
# BOOTSTRAP / INITIALIZATION
# =============================

# Start profile timer
$global:profileTimer = [System.Diagnostics.Stopwatch]::StartNew()
$global:sectionTimer = [System.Diagnostics.Stopwatch]::new()

# Define log file
$profileDir = Split-Path -Parent $PROFILE
$logFile = Join-Path $profileDir 'PowerShellProfileLoadingTime.log'
# Check if the file exists and is not empty
# Check if the file exists
if (Test-Path $logFile) {
    # Then check if it's non-empty
    $firstLine = Get-Content $logFile -TotalCount 1
    if ($firstLine.Length -gt 0) {
        Add-Content $logFile "`n`n#### PowerShell Session Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ####"
    }
    else {
        Add-Content $logFile "#### PowerShell Session Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ####"
    }
}
else {
    # File doesn't exist yet
    Add-Content $logFile "#### PowerShell Session Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ####"
}

# Function: Append section timing log
function Write-TimingLog {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp `t $Message" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# Function: Automatically install program if missing
function Test-ProgramInstalled {
    param (
        [string]$CommandName,
        [string]$PackageId
    )
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        Write-Host "➡ Installing $CommandName..." -ForegroundColor Cyan
        winget install --id $PackageId -e --source winget
    }
}

# Function: Automatically install module if missing
function Test-ModuleInstalled {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "➡ Installing module $ModuleName..." -ForegroundColor Cyan
        Install-Module -Name $ModuleName -Repository PSGallery -Scope CurrentUser -Force
    }
}

# Begin bootstrap
$sectionTimer.Restart()

# --- Ensure core tools are installed ---
Test-ProgramInstalled -CommandName eza -PackageId "eza-community.eza"
Test-ProgramInstalled -CommandName fzf -PackageId "junegunn.fzf"
Test-ProgramInstalled -CommandName zoxide -PackageId "ajeetdsouza.zoxide"

# --- Ensure PSFzf module is installed and configured ---
Test-ModuleInstalled -ModuleName PSFzf
if (-not (Get-Module -Name PSFzf)) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
}
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Set eza configuration directory
$env:EZA_CONFIG_DIR = "$env:USERPROFILE\.config\eza"

# End bootstrap
$sectionTimer.Stop()
Write-TimingLog "Bootstrap complete in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# TERMINAL CONFIGURATION & PROMPT
# =============================

$sectionTimer.Restart()

# --- Set window title with PowerShell version and admin indicator ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$adminSymbol = $isAdmin ? " ⚡" : ""
$host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$adminSymbol"

# --- Initialize zoxide shell integration ---
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# --- Start Starship prompt ---
Invoke-Expression (&starship init powershell)

$sectionTimer.Stop()
Write-TimingLog "Terminal configured in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# ALIASES AND SHORTHAND
# =============================

$sectionTimer.Restart()

# =============================
# Helper Functions
# =============================

# --- Lazy load Terminal-Icons (only if needed) ---
$script:TerminalIconsLoaded = $false
function Enable-TerminalIcons {
    if (-not $script:TerminalIconsLoaded -and (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
        $script:TerminalIconsLoaded = $true
    }
}

# --- Editor and Profile Helpers ---
$EDITOR = if (Get-Command nvim -ErrorAction SilentlyContinue) { 'nvim' }
elseif (Get-Command code -ErrorAction SilentlyContinue) { 'code' }
else { 'notepad' }

Set-Alias -Name edit -Value $EDITOR
function edit-profile { & $EDITOR $PROFILE }
function update-profile { & $PROFILE.CurrentUserAllHosts }
Set-Alias -Name ep -Value edit-profile

# =============================
# Unix Aliases
# =============================

function .. { Set-Location ..\.. }
function ... { Set-Location ..\..\.. }

function touch($file) {
    if (Test-Path $file) {
        Set-ItemProperty -Path $file -Name LastWriteTime -Value (Get-Date)
    }
    else {
        New-Item $file -ItemType File | Out-Null
    }
}

function which { param($name) Get-Command $name | Select-Object -ExpandProperty Definition }

function find($name) {
    Get-ChildItem -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*$name*" }
}

function grep($pattern, $path = ".") {
    Get-ChildItem -Recurse -File -Path $path |
    Select-String -Pattern $pattern |
    ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line)" }
}

function head {
    param($Path, $n = 10)
    Get-Content -Path $Path -Head $n
}

function tail {
    param($Path, $n = 10, [switch]$f = $false)
    Get-Content -Path $Path -Tail $n -Wait:$f
}

# =============================
# File Listing
# =============================

# Remove the existing ls alias if exists
if (Test-Path Alias:ls) {
    Remove-Item Alias:ls -ErrorAction SilentlyContinue
}

$useEza = (Get-Command eza -ErrorAction SilentlyContinue)

if ($useEza) {
    # --- EZA-based Aliases (Preferred) ---
    function ls { eza -F --group-directories-first --group-directories-first --time-style='long-iso' --icons @args }
    function lh { eza -laF --group-directories-first --time-style='long-iso' --icons @args }
    function lslh { eza -la --icons @args }
    function llt { eza -T --icons @args }
    function lltg { eza -T --git --icons @args }
    function ll { eza -lF --group-directories-first --time-style='long-iso' --icons @args }
    function la { eza -la --icons @args }
    function lt { eza -T --icons @args }
}
else {
    # --- PowerShell-native fallback (with Terminal Icons) ---
    Remove-Item -Path Alias:ls -ErrorAction SilentlyContinue

    function ls { Enable-TerminalIcons; Get-ChildItem @args | Format-Wide }
    function lh { Enable-TerminalIcons; Get-ChildItem -Force @args }
    function lslh { Enable-TerminalIcons; Get-ChildItem -Force @args | Format-List }
    function ll { Enable-TerminalIcons; Get-ChildItem @args | Format-List }
    function la { Enable-TerminalIcons; Get-ChildItem -Force @args }
    function lt { Enable-TerminalIcons; Get-ChildItem -Recurse -Directory @args }
}

# =============================
# Directory Shortcuts
# =============================

function mkcd {
    param($dir)
    mkdir $dir -Force | Out-Null
    Set-Location $dir
}

# =============================
# System Info and Tools
# =============================

function sysinfo { Get-ComputerInfo }

function Get-IP {
    try {
        (Invoke-RestMethod http://ifconfig.me/ip).Trim()
    }
    catch {
        Write-Warning "Failed to retrieve IP address."
    }
}

function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS cache flushed."
}

# =============================
# Process Management
# =============================

function pgrep($name) { Get-Process -Name $name }
function pkill($name) { Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process }
function k9($name) { Stop-Process -Name $name }

# =============================
# Hashing
# =============================

function md5($file) { Get-FileHash -Algorithm MD5 -Path $file }
function sha1($file) { Get-FileHash -Algorithm SHA1 -Path $file }
function sha256($file) { Get-FileHash -Algorithm SHA256 -Path $file }

$sectionTimer.Stop()
Write-TimingLog "Aliases and shorthand loaded in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# Utilities
# =============================
#dotfiles management
function dotfiles {
    git --git-dir=$HOME\.dotfiles.git --work-tree=$HOME @Args
}

# Open WinUtil
function winutil {
    Invoke-RestMethod https://christitus.com/win | Invoke-Expression
}

# Open WIMUtil
function wimutil {
    Invoke-RestMethod https://github.com/memstechtips/WIMUtil/raw/main/src/WIMUtil.ps1 | Invoke-Expression
}

$sectionTimer.Stop()
Write-TimingLog "Utilities loaded in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# PSREADLINE CONFIGURATION
# =============================

$sectionTimer.Restart()

# --- PSReadline configuration ---
$PSReadLineOptions = @{
    EditMode                      = 'Windows'
    HistoryNoDuplicates           = $true
    HistorySearchCursorMovesToEnd = $true
    Colors                        = @{
        Command   = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator  = '#FFB6C1'  # LightPink (pastel)
        Variable  = '#DDA0DD'  # Plum (pastel)
        String    = '#FFDAB9'  # PeachPuff (pastel)
        Number    = '#B0E0E6'  # PowderBlue (pastel)
        Type      = '#F0E68C'  # Khaki (pastel)
        Comment   = '#D3D3D3'  # LightGray (pastel)
        Keyword   = '#8367c7'  # Violet (pastel)
        Error     = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    PredictionSource              = 'HistoryAndPlugin'
    PredictionViewStyle           = 'ListView'
    MaximumHistoryCount           = 10000
    BellStyle                     = 'None'
}

Set-PSReadLineOption @PSReadLineOptions

# Custom key handlers
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    -not ($sensitive | Where-Object { $line -match $_ })
}

# --- PSFzf Integration ---
if (-not (Get-Module -Name PSFzf)) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
}

Set-PsFzfOption `
    -PSReadlineChordProvider 'Ctrl+t' `
    -PSReadlineChordReverseHistory 'Ctrl+r'

$sectionTimer.Stop()
Write-TimingLog "ReadLine and keybindings loaded in $($sectionTimer.ElapsedMilliseconds) ms"