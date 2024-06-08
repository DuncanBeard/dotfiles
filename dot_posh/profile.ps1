oh-my-posh init pwsh | Invoke-Expression

Set-Alias which Get-Command
Set-Alias touch New-Item
Set-Alias cz chezmoi

Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
# Set-PSReadlineKeyHandler -Key Tab -Function AcceptSuggestion

#GitHub CoPilot CLI
$ghcopilotpath = "$HOME\gh-copilot.ps1"
if (Test-Path $ghcopilotpath) {
  . $ghcopilotpath
}

# Oh-My-Posh
oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json' | Invoke-Expression