# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/atomic.omp.json" | Invoke-Expression
$omppath = "$HOME\.config\ohmyposh\omp.yml"
if (Test-Path $omppath) {
  oh-my-posh init pwsh --config $omppath | Invoke-Expression
} else {
  oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json' | Invoke-Expression
}

Set-Alias which Get-Command
Set-Alias touch New-Item
Set-Alias -Name cz -Value chezmoi

Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
# Set-PSReadlineKeyHandler -Key Tab -Function AcceptSuggestion
Set-PSReadLineOption -HistorySavePath "C:\Users\duncanbeard\OneDrive - Microsoft\PowerShell\history.txt"

#GitHub CoPilot CLI
$ghcopilotpath = "$HOME\gh-copilot.ps1"
if (Test-Path $ghcopilotpath) {
  . $ghcopilotpath
}