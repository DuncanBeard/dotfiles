oh-my-posh init pwsh | Invoke-Expression

. "C:\Users\duncanbeard\.posh\gh-copilot.ps1"

Set-Alias which Get-Command
Set-Alias touch New-Item
Set-Alias cz chezmoi

Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
# Set-PSReadlineKeyHandler -Key Tab -Function AcceptSuggestion

# oh-my-posh init pwsh --config "$HOME\.atomic.omp.json" | Invoke-Expression
# oh-my-posh init pwsh --config "$HOME\.atomic-left-only.omp.json" | Invoke-Expression