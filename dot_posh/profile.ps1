New-Alias which Get-Command
New-Alias touch New-Item
New-Alias cz chezmoi
New-Alias reload ". $HOME\.posh\profile.ps1"
New-Alias ".." "Set-Location .."
New-Alias ... "Set-Location ..\.."
New-Alias .... "Set-Location ..\..\.."

$GH_COPILOT_PROFILE = Join-Path -Path $(Split-Path -Path $PROFILE -Parent) -ChildPath "gh-copilot.ps1"
gh copilot alias -- pwsh | Out-File ( New-Item -Path $GH_COPILOT_PROFILE -Force )
echo ". `"$GH_COPILOT_PROFILE`"" >> $PROFILE

Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Set-PSReadlineKeyHandler -Key Tab -Function AcceptSuggestion
# Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# oh-my-posh init pwsh --config "$HOME\.atomic.omp.json" | Invoke-Expression
# oh-my-posh init pwsh --config "$HOME\.atomic-left-only.omp.json" | Invoke-Expression
oh-my-posh init pwsh | Invoke-Expression

$env:Path += "C:\src\scripts"
