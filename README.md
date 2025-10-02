`.chezmoiignore` -> Ignore based on OS info from `chezmoi data`

To get PowerShell to use the .posh folder:
1. `$profile | select *` to get all $profile locations
2. `code "C:\Program Files\PowerShell\7\profile.ps1"` as administrator
3. Contents should be:
```posh
 $profile = "C:\Users\duncanbeard\.powershell\profile.ps1"
. $profile
```
4. Open a new terminal and the new settings should be applied
