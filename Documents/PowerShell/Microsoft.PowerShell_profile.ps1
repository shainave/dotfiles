## PowerShell Profile version 2.00 2025-05-22

# =============================
# BOOTSTRAP / INITIALIZATION
# =============================

# Start profile timer
$global:profileTimer = [System.Diagnostics.Stopwatch]::StartNew()
$global:sectionTimer = [System.Diagnostics.Stopwatch]::new()

# Define log file
$profileDir = Split-Path -Parent $PROFILE
$logFile = Join-Path $profileDir 'PowerShellProfileLoadingTime.log'

# Initialize log file
if (Test-Path $logFile) {
    $firstLine = Get-Content $logFile -TotalCount 1 -ErrorAction SilentlyContinue
    if ($firstLine.Length -gt 0) {
        Add-Content $logFile "`n`n#### PowerShell Session Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ####"
    }
    else {
        Add-Content $logFile "#### PowerShell Session Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ####"
    }
}
else {
    Add-Content $logFile "#### PowerShell Session Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ####"
}

# Function: Append section timing log
function Write-TimingLog {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp `t $Message" | Out-File -FilePath $logFile -Append -Encoding utf8
}

# Initialize session cache for tool status
if (-not $global:ToolStatusCache) {
    $global:ToolStatusCache = @{}
}

# Begin bootstrap
$sectionTimer.Restart()

# Quick existence checks only (no installation attempts)
$global:ToolsAvailable = @{
    eza      = [bool](Get-Command eza -ErrorAction SilentlyContinue)
    fzf      = [bool](Get-Command fzf -ErrorAction SilentlyContinue)
    zoxide   = [bool](Get-Command zoxide -ErrorAction SilentlyContinue)
    starship = [bool](Get-Command starship -ErrorAction SilentlyContinue)
    nvim     = [bool](Get-Command nvim -ErrorAction SilentlyContinue)
    code     = [bool](Get-Command code -ErrorAction SilentlyContinue)
}

# Only configure tools that exist
if ($global:ToolsAvailable.eza) {
    $env:EZA_WINDOWS_ATTRIBUTES = "short"
    $env:EZA_ICONS_AUTO = "always"
    $env:EZA_COLORS = "da=2;34:xx=95:ur=36:su=95:sf=36:pi=96"
}

if ($global:ToolsAvailable.fzf) {
    $env:FZF_DEFAULT_OPTS = '--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4'

    # Import PSFzf only if fzf exists and module is available
    if (Get-Module -ListAvailable -Name PSFzf) {
        Import-Module PSFzf -ErrorAction SilentlyContinue
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
}

$sectionTimer.Stop()
Write-TimingLog "Bootstrap complete in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# TERMINAL CONFIGURATION & PROMPT
# =============================

$sectionTimer.Restart()

# Window title setup
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$adminSymbol = $isAdmin ? " ⚡" : ""
$host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$adminSymbol"

# Only initialize tools that are available
if ($global:ToolsAvailable.starship) {
    Invoke-Expression (&starship init powershell)
}

if ($global:ToolsAvailable.zoxide) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

$sectionTimer.Stop()
Write-TimingLog "Terminal configured in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# HELPER FUNCTIONS
# =============================

$sectionTimer.Restart()

# Lazy load Terminal-Icons (only if needed)
$script:TerminalIconsLoaded = $false
function Enable-TerminalIcons {
    if (-not $script:TerminalIconsLoaded -and (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
        $script:TerminalIconsLoaded = $true
    }
}

# Install missing tools function
function Install-MissingTools {
    $tools = @(
        @{ Name = "eza"; Package = "eza-community.eza"; Description = "Modern ls replacement" }
        @{ Name = "fzf"; Package = "junegunn.fzf"; Description = "Fuzzy finder" }
        @{ Name = "zoxide"; Package = "ajeetdsouza.zoxide"; Description = "Smart cd command" }
        @{ Name = "starship"; Package = "Starship.Starship"; Description = "Cross-shell prompt" }
    )

    Write-Host "Checking for missing tools..." -ForegroundColor Cyan
    $missingTools = @()

    foreach ($tool in $tools) {
        if (-not (Get-Command $tool.Name -ErrorAction SilentlyContinue)) {
            $missingTools += $tool
        }
    }

    if ($missingTools.Count -eq 0) {
        Write-Host "✅ All tools are already installed!" -ForegroundColor Green
        return
    }

    Write-Host "Missing tools:" -ForegroundColor Yellow
    foreach ($tool in $missingTools) {
        Write-Host "  • $($tool.Name) - $($tool.Description)" -ForegroundColor Gray
    }

    $choice = Read-Host "`nInstall missing tools? (y/N)"
    if ($choice -eq 'y' -or $choice -eq 'Y') {
        foreach ($tool in $missingTools) {
            Write-Host "Installing $($tool.Name)..." -ForegroundColor Cyan
            winget install --id $tool.Package -e --source winget
        }
        Write-Host "`n✅ Installation complete! Restart PowerShell to use new tools." -ForegroundColor Green
    }
}

$sectionTimer.Stop()
Write-TimingLog "Helper functions loaded in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# ALIASES AND SHORTHAND
# =============================

$sectionTimer.Restart()

# =============================
# Editor Configuration
# =============================

# Set default editor based on available tools
$EDITOR = if ($global:ToolsAvailable.nvim) { 'nvim' }
elseif ($global:ToolsAvailable.code) { 'code' }
else { 'notepad' }

Set-Alias -Name edit -Value $EDITOR

# Editor shortcuts - only defined if the editor exists
if ($global:ToolsAvailable.nvim) {
    function v { nvim $args }
}

if ($global:ToolsAvailable.code) {
    function c { code $args }
}

if (Get-Command notepad -ErrorAction SilentlyContinue) {
    function n { notepad $args }
}

# Profile management
function edit-profile { & $EDITOR $PROFILE }
function update-profile { . $PROFILE }
Set-Alias -Name ep -Value edit-profile

# =============================
# Unix-like Aliases
# =============================

# Navigation shortcuts
function cd... { Set-Location ..\.. }
function cd.... { Set-Location ..\..\.. }

# File operations
function touch {
    param($file)
    if (Test-Path $file) {
        Set-ItemProperty -Path $file -Name LastWriteTime -Value (Get-Date)
    }
    else {
        New-Item $file -ItemType File | Out-Null
    }
}

function which {
    param($name)
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function find {
    param($name)
    Get-ChildItem -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*$name*" }
}

function grep {
    param($pattern, $path = ".")
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

function mkcd {
    param($dir)
    mkdir $dir -Force | Out-Null
    Set-Location $dir
}

# =============================
# File Listing
# =============================

# Remove existing ls alias if present
if (Test-Path Alias:ls) {
    Remove-Item Alias:ls -ErrorAction SilentlyContinue
}

if ($global:ToolsAvailable.eza) {
    # EZA-based aliases (preferred)
    function ls { eza -F --group-directories-first --time-style='long-iso' --icons --color=always @args }
    function lh { eza -laF --group-directories-first --time-style='long-iso' --icons @args }
    function lslh { eza -la --icons @args }
    function ll { eza -lF --group-directories-first --total-size --time-style='long-iso' --icons --color=always @args }
    function la { eza -la --icons @args }
    function lt { eza -T --icons @args }
    function llt { eza -T --icons @args }
    function lltg { eza -T --git --icons @args }
}
else {
    # PowerShell-native fallback (with Terminal Icons)
    function ls { Enable-TerminalIcons; Get-ChildItem @args | Format-Wide }
    function lh { Enable-TerminalIcons; Get-ChildItem -Force @args }
    function lslh { Enable-TerminalIcons; Get-ChildItem -Force @args | Format-List }
    function ll { Enable-TerminalIcons; Get-ChildItem @args | Format-List }
    function la { Enable-TerminalIcons; Get-ChildItem -Force @args }
    function lt { Enable-TerminalIcons; Get-ChildItem -Recurse -Directory @args }
}

# =============================
# System Information and Tools
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

function pgrep { param($name) Get-Process -Name $name }
function pkill { param($name) Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process }
function k9 { param($name) Stop-Process -Name $name }

# =============================
# Hashing Functions
# =============================

function md5 { param($file) Get-FileHash -Algorithm MD5 -Path $file }
function sha1 { param($file) Get-FileHash -Algorithm SHA1 -Path $file }
function sha256 { param($file) Get-FileHash -Algorithm SHA256 -Path $file }

# =============================
# Git Aliases (if zoxide available, otherwise basic)
# =============================

function gs { git status }
function ga { git add . }
function gc { param($m) git commit -m "$m" }
function gp { git push }
function gcl { git clone $args }

# Git combination commands
function gcom {
    git add .
    git commit -m "$args"
}

function lazyg {
    git add .
    git commit -m "$args"
    git push
}

# Only define 'g' function if zoxide is available
if ($global:ToolsAvailable.zoxide) {
    function g { __zoxide_z github }
}

# =============================
# Winget Helpers
# =============================

function wgi { winget install $args }
function wgu { winget uninstall $args }
function wgs { winget search $args }
function wgl { winget list $args }
function wgx { winget upgrade $args }
function wgua { winget upgrade --all --include-unknown --recurse --silent $args }
function wgex { winget export $args }
function wgim { winget import $args }
function wgsr { winget source reset --force }
function wgt { winget show $args }

# =============================
# Other Aliases
# =============================

Set-Alias -Name sudo -Value admin

$sectionTimer.Stop()
Write-TimingLog "Aliases and shorthand loaded in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# UTILITIES
# =============================

$sectionTimer.Restart()

# Dotfiles management
function dotfiles {
    git --git-dir=$HOME\.dotfiles.git --work-tree=$HOME @Args
}

# External utilities
function winutil {
    Invoke-RestMethod https://christitus.com/win | Invoke-Expression
}

function wimutil {
    Invoke-RestMethod https://github.com/memstechtips/WIMUtil/raw/main/src/WIMUtil.ps1 | Invoke-Expression
}

# Admin function for elevated commands
function admin {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        $commandArgs
    )
    $wezterm = $env:WEZTERM_EXECUTABLE
    $isWezTerm = -not [string]::IsNullOrEmpty($wezterm)

    if ($commandArgs.Count -gt 0) {
        $argList = $commandArgs -join ' '
        if ($isWezTerm) {
            Start-Process $wezterm -Verb RunAs -ArgumentList "pwsh.exe", "-NoExit", "-Command", "$argList"
        }
        else {
            Start-Process wt -Verb RunAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
        }
    }
    else {
        if ($isWezTerm) {
            Start-Process $wezterm -Verb RunAs
        }
        else {
            Start-Process wt -Verb RunAs
        }
    }
}

$sectionTimer.Stop()
Write-TimingLog "Utilities loaded in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# PSREADLINE CONFIGURATION
# =============================

$sectionTimer.Restart()

# PSReadline configuration
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

# History management - prevent sensitive information from being recorded
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    -not ($sensitive | Where-Object { $line -match $_ })
}

# Custom completions for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git'    = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout', 'branch', 'merge', 'rebase')
        'winget' = @('search', 'install', 'uninstall', 'upgrade', 'list', 'show', 'source', 'validate', 'export', 'import')
        'npm'    = @('install', 'start', 'run', 'test', 'build', 'init', 'publish', 'update')
        'deno'   = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, winget, npm, deno -ScriptBlock $scriptblock

# .NET completion (if available)
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    $scriptblock = {
        param($wordToComplete, $commandAst, $cursorPosition)
        dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock
}

$sectionTimer.Stop()
Write-TimingLog "ReadLine and keybindings loaded in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# POWERSHELL DRIVES
# =============================

$sectionTimer.Restart()

# Create Work: drive if "Work Folders" exists
if (Test-Path "$env:USERPROFILE\Work Folders") {
    New-PSDrive -Name Work -PSProvider FileSystem -Root "$env:USERPROFILE\Work Folders" -Description "Work Folders" -ErrorAction SilentlyContinue
    function Work: { Set-Location Work: }
}

# Create OneDrive: drive if available
if (Test-Path HKCU:\SOFTWARE\Microsoft\OneDrive) {
    $onedrive = Get-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\OneDrive -ErrorAction SilentlyContinue
    if ($onedrive -and $onedrive.UserFolder -and (Test-Path $onedrive.UserFolder)) {
        New-PSDrive -Name OneDrive -PSProvider FileSystem -Root $onedrive.UserFolder -Description "OneDrive" -ErrorAction SilentlyContinue
        function OneDrive: { Set-Location OneDrive: }
    }
}

$sectionTimer.Stop()
Write-TimingLog "PowerShell drives configured in $($sectionTimer.ElapsedMilliseconds) ms"

# =============================
# FINALIZATION
# =============================

# Stop profile timer and log total time
$global:profileTimer.Stop()
Write-TimingLog "Profile loaded completely in $($global:profileTimer.ElapsedMilliseconds) ms total"

# Display loading summary (optional - comment out if you prefer silent loading)
# Write-Host "PowerShell profile loaded in $($global:profileTimer.ElapsedMilliseconds)ms" -ForegroundColor Green

# Clean up temporary variables
Remove-Variable sectionTimer -ErrorAction SilentlyContinue