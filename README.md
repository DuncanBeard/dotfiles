`.chezmoiignore` -> Ignore based on OS info from `chezmoi data`

## Windows bootstrap

The [Windows bootstrap](./run_before_windows-install-packages.ps1.tmpl) checks the
packages and Nerd Fonts declared in [packages.yaml](./.chezmoidata/packages.yaml)
before updating configuration files on every `chezmoi apply`.

- Install App Installer (`winget`) first.
- Missing packages are installed using exact IDs from the `winget` source.
  Existing packages are not upgraded; use `winget upgrade` separately.
- WinGet package and source agreements are accepted automatically. Installers
  may still require elevation.
- After installing Oh My Posh, missing FiraCode and Hack Nerd Fonts are installed
  with `oh-my-posh font install`. Font families are checked again after installation.
- Installation failures stop the apply before configuration files are updated.
  A later apply retries, including when a previously installed package is removed.

Restart existing terminals or VS Code after installing tools or fonts so they
pick up PATH and font changes.

Validate the bootstrap and profile templates without installing anything using Pester 5:

```powershell
Invoke-Pester -Path .\tests -Output Detailed
```

## PowerShell profile

The [managed profile](./dot_powershell/profile.ps1.tmpl) saves history under
`$HOME\OneDrive - Microsoft\PowerShell\history.txt` when the configured email ends
in `@microsoft.com` (case-insensitive), otherwise under
`$HOME\OneDrive\PowerShell\history.txt`.

To get PowerShell to use the .posh folder:
1. `$profile | select *` to get all $profile locations
2. `code "C:\Program Files\PowerShell\7\profile.ps1"` as administrator
3. Contents should be:
```posh
 $profile = "C:\Users\duncanbeard\.powershell\profile.ps1"
. $profile
```
4. Open a new terminal and the new settings should be applied
