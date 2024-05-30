New-Alias which Get-Command
New-Alias touch New-Item
New-Alias cz chezmoi
New-Alias reload ". $HOME\.posh\profile.ps1"
New-Alias ".." "Set-Location .."
New-Alias ... "Set-Location ..\.."
New-Alias .... "Set-Location ..\..\.."

Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Set-PSReadlineKeyHandler -Key Tab -Function AcceptSuggestion
# Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# oh-my-posh init pwsh --config "$HOME\.atomic.omp.json" | Invoke-Expression
# oh-my-posh init pwsh --config "$HOME\.atomic-left-only.omp.json" | Invoke-Expression
oh-my-posh init pwsh | Invoke-Expression

$env:Path += "C:\src\scripts"

#34de4b3d-13a8-4540-b76d-b9e8d3851756 PowerToys CommandNotFound module

Import-Module "C:\Program Files\PowerToys\WinUI3Apps\..\WinGetCommandNotFound.psd1"
#34de4b3d-13a8-4540-b76d-b9e8d3851756
