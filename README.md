`.chezmoiignore` -> Ignore based on OS info from `chezmoi data`

## Windows bootstrap

The [Windows bootstrap](./run_before_windows-install-packages.ps1.tmpl) checks the
packages and Nerd Fonts declared in [packages.yaml](./.chezmoidata/packages.yaml)
before updating configuration files on every `chezmoi apply`.

- Install App Installer (`winget`) first.
- Missing packages are installed using exact IDs from the `winget` source.
  Existing packages are not upgraded; use `winget upgrade` separately.
- Packages under `wingetOptional` (Dropbox, Insta360 Link Controller, Logseq,
  PowerToys) are installed only when `chezmoi init` is answered yes for
  `optionalApps`. Answering no also stops managing their configuration files.
  Machines initialized before this prompt existed keep installing them until
  `chezmoi init` is rerun.
- Packages under `wingetNonMicrosoft` (Tailscale) are installed only when the
  configured email does not end in `@microsoft.com` (case-insensitive).
- WinGet package and source agreements are accepted automatically. Installers
  may still require elevation.
- After installing Oh My Posh, missing FiraCode and Hack Nerd Fonts are installed
  with `oh-my-posh font install`. Font families are checked again after installation.
- Installation failures stop the apply before configuration files are updated.
  A later apply retries, including when a previously installed package is removed.

Restart existing terminals or VS Code after installing tools or fonts so they
pick up PATH and font changes.

## Windows settings

[run_onchange_after_windows-settings.ps1](./run_onchange_after_windows-settings.ps1.tmpl)
runs after files are applied, and again whenever the script changes. It sets:

- Mouse acceleration (Enhance pointer precision) off, applied immediately.
- Snap Assist suggestions off; Alt+Tab shows open windows only (no Edge tabs).
- Taskbar aligned left, small bar (`TaskbarSize`), small buttons
  (`IconSizePreference`), never combined on any display, Task View and search
  hidden.
- This PC shown on the desktop; desktop icons auto arranged and sorted by name
  (applied to the live desktop view, since Explorer overwrites its registry state).
- Dark mode for apps and Windows, transparency off.

Only values that differ are written. Explorer restarts only when a taskbar or
theme value changed.

Validate the bootstrap and profile templates without installing anything using Pester 5:

```powershell
Invoke-Pester -Path .\tests -Output Detailed
```

## PowerShell profile

The [managed profile](./dot_powershell/profile.ps1.tmpl) saves history under
`$HOME\OneDrive - Microsoft\PowerShell\history.txt` when the configured email ends
in `@microsoft.com` (case-insensitive), otherwise under
`$HOME\OneDrive\PowerShell\history.txt`.

On `@microsoft.com` machines the profile also sets `PI_LEGACY_INSTALL=1`. Microsoft's
npm feed lags pi.dev releases, so Pi's default managed installer fails with 404s;
legacy mode installs the feed's latest Pi with npm instead. `pi update` targets
pi.dev's newest release, which the feed may not have yet, so update with
`npm install -g --ignore-scripts @earendil-works/pi-coding-agent` instead.

To get PowerShell to use the .posh folder:
1. `$profile | select *` to get all $profile locations
2. `code "C:\Program Files\PowerShell\7\profile.ps1"` as administrator
3. Contents should be:
```posh
 $profile = "C:\Users\duncanbeard\.powershell\profile.ps1"
. $profile
```
4. Open a new terminal and the new settings should be applied
