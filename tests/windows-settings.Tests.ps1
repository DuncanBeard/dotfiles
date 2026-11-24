BeforeAll {
  $repositoryRoot = Split-Path -Parent $PSScriptRoot
  $templatePath = Join-Path $repositoryRoot 'run_onchange_after_windows-settings.ps1.tmpl'
  $rendered = & chezmoi --source $repositoryRoot execute-template --file $templatePath
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to render the Windows settings script.'
  }
  $settingsScript = [scriptblock]::Create(($rendered -join "`n"))

  # Stand-in for the user32 binding so tests never change real pointer settings.
  if (-not ('ChezmoiWindowsSettings.Native' -as [type])) {
    Add-Type -TypeDefinition @'
namespace ChezmoiWindowsSettings {
  public static class Native {
    public static int Calls;
    public static int[] LastValues;
    public static bool SystemParametersInfo(uint action, uint param, int[] values, uint winIni) {
      Calls++;
      LastValues = values;
      return true;
    }
  }
  public static class Desktop {
    public static bool Arranged;
    public static int FailuresBeforeReady;
    public static int ApplyCalls;
    public static bool IsAutoArrangedByName() {
      if (FailuresBeforeReady > 0) {
        FailuresBeforeReady--;
        throw new System.InvalidOperationException("The desktop window is not available.");
      }
      return Arranged;
    }
    public static void AutoArrangeByName() {
      ApplyCalls++;
      Arranged = true;
    }
  }
}
'@
  }

  $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  $search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
  $personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
  $mouse = 'HKCU:\Control Panel\Mouse'
  $desktopIcons = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'

  $expected = @{
    "$mouse|MouseSpeed" = '0'
    "$mouse|MouseThreshold1" = '0'
    "$mouse|MouseThreshold2" = '0'
    "$advanced|SnapAssist" = 0
    "$advanced|MultiTaskingAltTabFilter" = 3
    "$advanced|TaskbarAl" = 0
    "$advanced|TaskbarSize" = 1
    "$advanced|IconSizePreference" = 0
    "$advanced|TaskbarGlomLevel" = 2
    "$advanced|MMTaskbarGlomLevel" = 2
    "$advanced|ShowTaskViewButton" = 0
    "$search|SearchboxTaskbarMode" = 0
    "$desktopIcons|{20D04FE0-3AEA-1069-A2D8-08002B30309D}" = 0
    "$personalize|AppsUseLightTheme" = 0
    "$personalize|SystemUsesLightTheme" = 0
    "$personalize|EnableTransparency" = 0
  }
}

Describe 'Windows settings' {
  BeforeEach {
    [ChezmoiWindowsSettings.Native]::Calls = 0
    [ChezmoiWindowsSettings.Native]::LastValues = $null
    [ChezmoiWindowsSettings.Desktop]::Arranged = $true
    [ChezmoiWindowsSettings.Desktop]::FailuresBeforeReady = 0
    [ChezmoiWindowsSettings.Desktop]::ApplyCalls = 0
    $script:registry = @{}
    $script:writes = [System.Collections.Generic.List[string]]::new()
    $script:explorerStops = 0
    $script:explorerStarts = 0

    Mock Get-ItemProperty {
      $key = "$($Path[0])|$($Name[0])"
      if ($script:registry.ContainsKey($key)) {
        [pscustomobject]@{ $Name[0] = $script:registry[$key] }
      }
    }
    Mock Set-ItemProperty {
      $script:registry["$Path|$Name"] = $Value
      $script:writes.Add("$Path|$Name")
    }
    Mock Test-Path { $true }
    Mock New-Item {}
    Mock Write-Host {}
    Mock Write-Warning {}
    Mock Start-Sleep {}
    Mock Stop-Process { $script:explorerStops++ } -ParameterFilter { $Name -eq 'explorer' }
    Mock Get-Process { $null } -ParameterFilter { $Name -eq 'explorer' }
    Mock Start-Process { $script:explorerStarts++ } -ParameterFilter { $FilePath -eq 'explorer.exe' }
  }

  It 'writes every setting, applies mouse settings, and restarts Explorer on a fresh machine' {
    [ChezmoiWindowsSettings.Desktop]::Arranged = $false

    & $settingsScript

    $script:writes.Count | Should -Be $expected.Count
    foreach ($key in $expected.Keys) {
      "$($script:registry[$key])" | Should -Be "$($expected[$key])" -Because $key
    }
    [ChezmoiWindowsSettings.Native]::Calls | Should -Be 1
    @([ChezmoiWindowsSettings.Native]::LastValues) | Should -Be @(0, 0, 0)
    $script:explorerStops | Should -Be 1
    $script:explorerStarts | Should -Be 1
    [ChezmoiWindowsSettings.Desktop]::ApplyCalls | Should -Be 1
  }

  It 'does nothing when every setting is already applied' {
    foreach ($key in $expected.Keys) { $script:registry[$key] = $expected[$key] }

    & $settingsScript

    $script:writes.Count | Should -Be 0
    [ChezmoiWindowsSettings.Native]::Calls | Should -Be 0
    $script:explorerStops | Should -Be 0
    [ChezmoiWindowsSettings.Desktop]::ApplyCalls | Should -Be 0
  }

  It 'applies mouse settings without restarting Explorer when only the mouse differs' {
    foreach ($key in $expected.Keys) { $script:registry[$key] = $expected[$key] }
    $script:registry["$mouse|MouseSpeed"] = '1'

    & $settingsScript

    @($script:writes) | Should -Be @("$mouse|MouseSpeed")
    [ChezmoiWindowsSettings.Native]::Calls | Should -Be 1
    $script:explorerStops | Should -Be 0
  }

  It 'restarts Explorer without touching the mouse when only a taskbar setting differs' {
    foreach ($key in $expected.Keys) { $script:registry[$key] = $expected[$key] }
    $script:registry["$advanced|TaskbarSize"] = 0

    & $settingsScript

    @($script:writes) | Should -Be @("$advanced|TaskbarSize")
    [ChezmoiWindowsSettings.Native]::Calls | Should -Be 0
    $script:explorerStops | Should -Be 1
  }

  It 'creates the desktop icon key when it does not exist' {
    Mock Test-Path { $false } -ParameterFilter { $Path -eq $desktopIcons }

    & $settingsScript

    Should -Invoke New-Item -Times 1 -Exactly -ParameterFilter { $Path -eq $desktopIcons }
    $script:registry["$desktopIcons|{20D04FE0-3AEA-1069-A2D8-08002B30309D}"] | Should -Be 0
  }

  It 'arranges desktop icons by name without restarting Explorer when only that differs' {
    foreach ($key in $expected.Keys) { $script:registry[$key] = $expected[$key] }
    [ChezmoiWindowsSettings.Desktop]::Arranged = $false

    & $settingsScript

    $script:writes.Count | Should -Be 0
    $script:explorerStops | Should -Be 0
    [ChezmoiWindowsSettings.Desktop]::ApplyCalls | Should -Be 1
  }

  It 'waits for the desktop after Explorer restarts before arranging icons' {
    [ChezmoiWindowsSettings.Desktop]::Arranged = $false
    [ChezmoiWindowsSettings.Desktop]::FailuresBeforeReady = 3

    & $settingsScript

    [ChezmoiWindowsSettings.Desktop]::ApplyCalls | Should -Be 1
    Should -Invoke Start-Sleep -Times 3 -Exactly -ParameterFilter { $Milliseconds -eq 500 }
    Should -Invoke Write-Warning -Times 0 -Exactly
  }

  It 'warns instead of failing when the desktop never becomes available' {
    [ChezmoiWindowsSettings.Desktop]::FailuresBeforeReady = 1000

    { & $settingsScript } | Should -Not -Throw

    [ChezmoiWindowsSettings.Desktop]::ApplyCalls | Should -Be 0
    Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*desktop icons were not arranged*' }
  }

  It 'does not render Windows settings on <OperatingSystem>' -ForEach @(
    @{ OperatingSystem = 'linux' }
    @{ OperatingSystem = 'darwin' }
  ) {
    $overridePath = Join-Path $TestDrive "$OperatingSystem.json"
    @{ chezmoi = @{ os = $OperatingSystem } } | ConvertTo-Json |
      Set-Content -LiteralPath $overridePath
    $output = & chezmoi --source $repositoryRoot --override-data-file $overridePath execute-template --file $templatePath
    $LASTEXITCODE | Should -Be 0
    ($output -join "`n").Trim() | Should -BeNullOrEmpty
  }
}
