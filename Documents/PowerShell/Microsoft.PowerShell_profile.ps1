### Helper Functions
# Tests if a command exists in the current environment
function Test-CommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$command
    )
    return ($null -ne (Get-Command $command -ErrorAction SilentlyContinue))
}

# Detect the parent process of the active terminal
function Get-ParentProcessName {
    param()
    $parentProc = Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -eq $PID } | Select-Object -ExpandProperty ParentProcessId
    $parentProcName = (Get-CimInstance Win32_Process -Filter "ProcessId=$parentProc").Name
    return $parentProcName
}

### Initialization
# Administrator Detection - Check if PowerShell is running with elevated privileges
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal $identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Console Appearance – Set custom colors for admin sessions
if (($host.Name -match "ConsoleHost") -and ($isAdmin)) {
    $host.PrivateData.ErrorBackgroundColor = "White"
    $host.PrivateData.ErrorForegroundColor = "Black"
    Clear-Host
}

# Set custom window title with admin indicator
$Host.UI.RawUI.WindowTitle = "PowerShell {0}" -f $PSVersionTable.PSVersion.ToString()
if ($isAdmin) {
    $Host.UI.RawUI.WindowTitle += " [ADMIN]"
}

### Module Imports and Tool Setup
# Import modules and configure external tools
# Import Terminal-Icons module for file icons in directory listings
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module -Name Terminal-Icons
} else {
    Write-Host "Terminal-Icons module not found. Install with: Install-Module -Name Terminal-Icons -Repository PSGallery" -ForegroundColor Yellow
}

# Add eza to path – remove if not using eza (winget install eza-community.eza)
$ezaPath = Join-Path $env:USERPROFILE "AppData\Local\Microsoft\WinGet\Packages\eza-community.eza_Microsoft.Winget.Source_8wekyb3d8bbwe"
if (-not ($env:PATH -like "*$ezaPath*")) {
    $env:PATH += ";$ezaPath"
}

# FZF Integration - Enable fuzzy finder for history search
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module -Name PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
} else {
    Write-Host "PSFzf module not found. Install with: Install-Module -Name PSFzf -Repository PSGallery" -ForegroundColor Yellow
}

# Prompt Setup
# Initialize Starship prompt if available, otherwise use custom prompt
if (Test-CommandExists starship) {
    Invoke-Expression (&starship init powershell)
} else {
    # Use the custom prompt function defined in the Prompt Appearance section
    function prompt { Format-PowerLinePrompt }
}

### Aliases and Shorthands
# Navigation Shortcuts
function cd... {
    param()
    Set-Location ..\..
}

function cd.... {
    param()
    Set-Location ..\..\..
}

# Navigate to common user directorie
# reduntant as it's better to use zoxide (winget install ajeetdsouza.zoxide)
function docs {
    param()
    $docs = if (([Environment]::GetFolderPath("MyDocuments"))) {
        ([Environment]::GetFolderPath("MyDocuments"))
    }
    else {
        $HOME + "\Documents"
    }
    Set-Location -Path $docs
}

# Utility Functions
# Creates an empty file, with safeguard against overwriting
function touch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$file
    )
    if (-not (Test-Path $file)) {
        New-Item -ItemType File -Path $file -Force | Out-Null
    }
    else {
        Write-Host "File already exists: $file" -ForegroundColor Yellow
    }
}

# Quick file creation shorthand
function nf {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name
    )
    New-Item -ItemType "file" -Path . -Name $name
}

# Search for files by name pattern recursively
function ff {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name
    )
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

# Find files by name pattern (find equivalent)
function find {
    param(
        [Parameter(Mandatory = $true)]
        [string]$pattern,

        [Parameter(Mandatory = $false)]
        [string]$dir = "."
    )
    Get-ChildItem -Recurse -File -Path $dir | Where-Object { $_.Name -match $pattern }
}

# Search content within files
function grep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$regex,

        [Parameter(Mandatory = $false)]
        [string]$dir
    )
    if ($dir) {
        Get-ChildItem -Recurse $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

# Search and replace in a file
function sed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$file,

        [Parameter(Mandatory = $true)]
        [string]$find,

        [Parameter(Mandatory = $true)]
        [string]$replace
    )
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

# Extract zip archives to current directory
function unzip {
    param(
        [Parameter(Mandatory = $true)]
        [string]$file
    )
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

# Displays first n lines of a file (head equivalent)
function head {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [int]$n = 10
    )
    Get-Content $Path -Head $n
}

# Displays last n lines of a file (tail equivalent)
function tail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [int]$n = 10,

        [Parameter(Mandatory = $false)]
        [switch]$f = $false
    )
    Get-Content $Path -Tail $n -Wait:$f
}

# Create directory and change to it in one command
function mkcd {
    param(
        [Parameter(Mandatory = $true)]
        [string]$dir
    )
    mkdir $dir -Force
    Set-Location $dir
}

# Move to recycle bin instead of permanent delete
function trash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$path
    )
    $fullPath = (Resolve-Path -Path $path).Path

    if (Test-Path $fullPath) {
        $item = Get-Item $fullPath

        if ($item.PSIsContainer) {
            # Handle directory
            $parentPath = $item.Parent.FullName
        }
        else {
            # Handle file
            $parentPath = $item.DirectoryName
        }

        $shell = New-Object -ComObject 'Shell.Application'
        $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)

        if ($item) {
            $shellItem.InvokeVerb('delete')
            Write-Host "Item '$fullPath' has been moved to the Recycle Bin."
        }
        else {
            Write-Host "Error: Could not find the item '$fullPath' to trash."
        }
    }
    else {
        Write-Host "Error: Item '$fullPath' does not exist."
    }
}

# Recursive directory listing
function dirs {
    param(
        [Parameter(Mandatory = $false)]
        [string]$pattern
    )
    if ($args.Count -gt 0) {
        Get-ChildItem -Recurse -Include "$args" | ForEach-Object FullName
    }
    else {
        Get-ChildItem -Recurse | ForEach-Object FullName
    }
}

# System Utilities
# Clear various Windows cache directories
function Clear-Cache {
    param()
    Write-Host "Clearing cache..." -ForegroundColor Cyan

    # Clear Windows Prefetch
    Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

    # Clear Windows Temp
    Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear User Temp
    Write-Host "Clearing User Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Cache clearing completed." -ForegroundColor Green
}

# Run commands with administrator privileges
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

# Show system information summary
function sysinfo {
    param()
    Get-ComputerInfo
}

# Display disk space information
function df {
    param()
    Get-PSDrive -PSProvider FileSystem |
    Select-Object Name, Used, Free, @{Name = "Used(GB)"; Expression = { [math]::Round($_.Used / 1GB, 2) } }, @{Name = "Free(GB)"; Expression = { [math]::Round($_.Free / 1GB, 2) } }
}

# Environment variable export
function export {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name,

        [Parameter(Mandatory = $true)]
        [string]$value
    )
    set-item -force -path "env:$name" -value $value;
}

# Find the location of a command
function which {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name
    )
    Get-Command $name | Select-Object -ExpandProperty Definition
}

# Network Utilities
# Get public IP address
function Get-IP {
    param()
    (Invoke-WebRequest http://ifconfig.me/ip).Content
}

# Clear DNS cache
function flushdns {
    param()
    Clear-DnsClientCache
    Write-Host "DNS has been flushed"
}

# Process Management
# Terminate processes by name
function pkill {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name
    )
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

# Find processes by name
function pgrep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name
    )
    Get-Process $name
}

# Quick process kill shorthand
function k9 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name
    )
    Stop-Process -Name $name
}

# Hashing Utilities
# Calculate MD5 hash of a file
function md5 {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$file
    )
    Get-FileHash -Algorithm MD5 $file
}

# Calculate SHA1 hash of a file
function sha1 {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$file
    )
    Get-FileHash -Algorithm SHA1 $file
}

# Calculate SHA256 hash of a file
function sha256 {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$file
    )
    Get-FileHash -Algorithm SHA256 $file
}

# External Tools
# Launch WinUtil utility
function winutil {
    param()
    Invoke-RestMethod https://christitus.com/win | Invoke-Expression
}

# Launch WIMUtil utility
function wimutil {
    param()
    Invoke-RestMethod "https://github.com/memstechtips/WIMUtil/raw/main/src/WIMUtil.ps1" | Invoke-Expression
}

# Profile Management
# Edit PowerShell profile in default editor
function edit-profile {
    param()
    edit $PROFILE
}

## Reload PowerShell profile
function update-profile {
    & $PROFILE.CurrentUserAllHosts
    Write-Host "PowerShell profile has been succesfully rreloaded"
}

# File Listing Commands
# Remove built-in ls alias if it exists
if (Get-Alias ls -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force
}

# Enhanced listing
# Use eza for file listing if available, otherwise use Get-ChildItem
# Use eza for file listing if available, otherwise use Get-ChildItem
if (Test-CommandExists eza) {
    function ls { eza --group-directories-first --icons @args }
    function ll { eza -lbGF --group-directories-first --icons }
    function lt { eza --tree --icons @args }
    function la { eza -l @args }
}
else {
    function ls { Get-ChildItem @args }
    function la { Get-ChildItem -Force @args | Format-Table -AutoSize }
    function ll { Get-ChildItem -Force @args | Format-Table -AutoSize }
}

# Editor Configuration
# Set default editor based on available tools
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
elseif (Test-CommandExists code) { 'code' }
else { 'notepad' }
Set-Alias -Name edit -Value $EDITOR

# Editor shortcuts – only defined if the editor exists
if (Test-CommandExists nvim) {
    function v { nvim $args }
}

if (Test-CommandExists code) {
    function c { code $args }
}

if (Test-CommandExists notepad) {
    function n { notepad $args }
}

# Other Aliases
Set-Alias -Name ep -Value Edit-Profile
Set-Alias -Name sudo -Value admin

# Git Aliases and Helpers
# Basic Git commands
function gs { git status }
function ga { git add . }
function gc { param($m) git commit -m "$m" }
function gp { git push }
function g { __zoxide_z github }
function gcl { git clone $args }

# Git Combination Commands
function gcom {
    git add .
    git commit -m "$args"
}

function lazyg {
    git add .
    git commit -m "$args"
    git push
}

# .dotfiles source control
function dotfiles {
    git --git-dir=$HOME\.dotfiles.git --work-tree=$HOME @Args
}

# Winget Helpers
# Package Installation and Management
function wgi { winget install $args }        # Install package(s)
function wgu { winget uninstall $args }      # Uninstall package(s)
function wgua { winget upgrade --all --include-unknown --recurse --silent $args }  # Upgrade all upgradable packages
function wgx { winget upgrade $args }        # Upgrade a specific package
function wgim { winget import $args }        # Import packages from a file

# Package Information and Search
function wgs { winget search $args }         # Search for package(s)
function wgl { winget list $args }           # List installed packages
function wgt { winget show $args }           # Show package details
function wgex { winget export $args }        # Export installed packages to a file

# System Maintenance
function wgsr { winget source reset --force } # Reset sources if they break

### PowerShell Drives
# Custom PSDrives - Create convenient drive mappings
# Create Work: drive if "Work Folders" exists
if (Test-Path "$env:USERPROFILE\Work Folders") {
    New-PSDrive -Name Work -PSProvider FileSystem -Root "$env:USERPROFILE\Work Folders" -Description "Work Folders"
    function Work: {
        param()
        Set-Location Work:
    }
}

# # Create OneDrive: drive if available
# if (Test-Path HKCU:\SOFTWARE\Microsoft\OneDrive) {
#     $onedrive = Get-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\OneDrive
#     if ($onedrive.PSObject.Properties.Match("UserFolder").Count -gt 0 -and $onedrive.UserFolder -and (Test-Path $onedrive.UserFolder)) {
#         New-PSDrive -Name OneDrive -PSProvider FileSystem -Root $onedrive.UserFolder -Description "OneDrive"
#         function OneDrive: {
#             param()
#             Set-Location OneDrive:
#         }
#     }
#     Remove-Variable onedrive
# }

### Prompt Appearance
# Custom PowerLine-style prompt configuration
function Format-PowerLinePrompt {
    # Get current path (shortened)
    $currentPath = $executionContext.SessionState.Path.CurrentLocation.Path
    $homePath = $HOME
    if ($currentPath.StartsWith($homePath)) {
        $currentPath = "~" + $currentPath.Substring($homePath.Length)
    }

    # Get Git branch if available
    $gitBranch = $null
    if (Test-CommandExists git) {
        try {
            $gitBranch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                # Check git status
                $gitStatus = git status --porcelain 2>$null
                $gitColor = if ($gitStatus) { "Yellow" } else { "Green" }
            } else {
                $gitBranch = $null
            }
        } catch {
            # Not in a git repo or git not working
            $gitBranch = $null
        }
    }

    # Set end symbol based on admin status
    $endSymbol = if ($isAdmin) { "#" } else { ">" }

    # PowerLine style prompt
    Write-Host ""  # Add empty line
    Write-Host "┌─" -NoNewline -ForegroundColor Blue
    Write-Host "[" -NoNewline -ForegroundColor DarkGray
    Write-Host "$currentPath" -NoNewline -ForegroundColor Cyan
    Write-Host "]" -NoNewline -ForegroundColor DarkGray

    # Show git branch if available
    if ($gitBranch) {
        Write-Host " (" -NoNewline -ForegroundColor DarkGray
        Write-Host "$gitBranch" -NoNewline -ForegroundColor $gitColor
        Write-Host ")" -NoNewline -ForegroundColor DarkGray
    }

    # Admin indicator
    if ($isAdmin) {
        Write-Host " [ADMIN]" -NoNewline -ForegroundColor Red
    }

    # Second line with prompt symbol
    Write-Host ""  # Line break
    Write-Host "└─$endSymbol" -NoNewline -ForegroundColor Blue

    return " "  # Return a space to maintain spacing after prompt
}

### PSReadLine Configuration
# Visual Styling –  Customize console appearance and syntax highlighting
$PSReadLineOptions = @{
    EditMode                     = 'Windows'
    HistoryNoDuplicates          = $true
    HistorySearchCursorMovesToEnd = $true
    Colors                       = @{
        Command  = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator = '#FFB6C1'  # LightPink (pastel)
        Variable = '#DDA0DD'  # Plum (pastel)
        String   = '#FFDAB9'  # PeachPuff (pastel)
        Number   = '#B0E0E6'  # PowderBlue (pastel)
        Type     = '#F0E68C'  # Khaki (pastel)
        Comment  = '#D3D3D3'  # LightGray (pastel)
        Keyword  = '#8367c7'  # Violet (pastel)
        Error    = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    PredictionSource             = 'HistoryAndPlugin'
    MaximumHistoryCount          = 10000
    PredictionViewStyle          = 'ListView'
    BellStyle                    = 'None'
}
Set-PSReadLineOption @PSReadLineOptions

# Key Bindings - Configure keyboard shortcuts for enhanced editing
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

# History Management – Prevent sensitive information from being recorded
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

# Custom Completions – Add tab completion for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git'  = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'winget' = @('search', 'install', 'uninstall', 'upgrade', 'upgrade -r -u -h')
        'npm'  = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

### Variable Cleanup
Remove-Variable identity -ErrorAction SilentlyContinue
Remove-Variable principal -ErrorAction SilentlyContinue