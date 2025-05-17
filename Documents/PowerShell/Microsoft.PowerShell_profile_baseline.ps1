# Importing PSfzf into profile and setting keybindings
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

### Aliases
# wwinget upgrade to run with options: --all, --include-unknown (-u), --recurse (-r), --silent (-h)
function wingetUpdateAll {
    winget upgrade --all --include-unknown --recurse --silent
}
# Create alias for wingetUpdateAll function
Set-Alias wga wingetUpdateAll

# Add eza to PATH
$ezaPath = Join-Path $env:USERPROFILE "AppData\Local\Microsoft\WinGet\Packages\eza-community.eza_Microsoft.Winget.Source_8wekyb3d8bbwe"
if (-not ($env:PATH -like "*$ezaPath*")) {
    $env:PATH += ";$ezaPath"
}

# Aliases and functions for eza
Set-Alias ls eza

function ll { eza -l @args }
function la { eza -la @args }
function lt { eza --tree @args }

# Add Startship
Invoke-Expression (&starship init powershell)
