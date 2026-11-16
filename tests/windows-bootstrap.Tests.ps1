BeforeAll {
  $repositoryRoot = Split-Path -Parent $PSScriptRoot
  $templatePath = Join-Path $repositoryRoot 'run_before_windows-install-packages.ps1.tmpl'
  $rendered = & chezmoi --source $repositoryRoot execute-template --file $templatePath
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to render the Windows bootstrap.'
  }
  $bootstrap = [scriptblock]::Create(($rendered -join "`n"))

  $packageData = & chezmoi --source $repositoryRoot execute-template '{{ .packages.windows | toJson }}'
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to render the Windows package data.'
  }
  $windowsPackages = ($packageData -join "`n") | ConvertFrom-Json
  $packageIds = @($windowsPackages.winget)
  $fontSpecs = @($windowsPackages.fonts)

  function winget { throw 'WinGet must be mocked during tests.' }
  function oh-my-posh { throw 'Oh My Posh must be mocked during tests.' }
}

Describe 'Windows prerequisite bootstrap' {
  BeforeEach {
    $script:originalPath = $env:Path
    $script:originalExitCode = $global:LASTEXITCODE
    $script:packageExitCode = 0
    $script:fontExitCode = 0
    $script:registerFonts = $true
    $script:installedFamilies = @($fontSpecs.family)
    $script:packageCalls = [System.Collections.Generic.List[object]]::new()
    $script:fontCalls = [System.Collections.Generic.List[string]]::new()
    $script:operations = [System.Collections.Generic.List[string]]::new()

    Mock winget {
      $script:packageCalls.Add(@($args))
      $script:operations.Add("package:$($args[2])")
      $global:LASTEXITCODE = $script:packageExitCode
    }
    Mock oh-my-posh {
      $fontName = $args[2]
      $script:fontCalls.Add($fontName)
      $script:operations.Add("font:$fontName")
      $global:LASTEXITCODE = $script:fontExitCode
      if ($script:fontExitCode -eq 0 -and $script:registerFonts) {
        $script:installedFamilies += ($fontSpecs | Where-Object name -EQ $fontName).family
      }
    }
    Mock Add-Type {} -ParameterFilter { $AssemblyName -eq 'System.Drawing' }
    Mock New-Object {
      $collection = [pscustomobject]@{
        Families = @($script:installedFamilies | ForEach-Object {
          [pscustomobject]@{ Name = $_ }
        })
      }
      $collection | Add-Member -MemberType ScriptMethod -Name Dispose -Value {} -PassThru
    } -ParameterFilter { $TypeName -eq 'System.Drawing.Text.InstalledFontCollection' }
  }

  AfterEach {
    $env:Path = $script:originalPath
    $global:LASTEXITCODE = $script:originalExitCode
  }

  It 'installs missing fonts only after the declared packages' {
    $script:installedFamilies = @()

    & $bootstrap

    $script:packageCalls.Count | Should -Be $packageIds.Count
    for ($index = 0; $index -lt $packageIds.Count; $index++) {
      $call = $script:packageCalls[$index]
      $call[0] | Should -Be 'install'
      $call[1] | Should -Be '--id'
      $call[2] | Should -Be $packageIds[$index]
      $call | Should -Contain '--exact'
      $call | Should -Contain '--no-upgrade'
      $call | Should -Contain '--disable-interactivity'
    }
    @($script:fontCalls) | Should -Be @($fontSpecs.name)
    $script:operations[$packageIds.Count] | Should -Be "font:$($fontSpecs[0].name)"
    @($script:installedFamilies) | Should -Be @($fontSpecs.family)
  }

  It 'accepts already-installed packages, skips existing fonts, and rechecks on later runs' {
    $script:packageExitCode = -1978335135

    & $bootstrap
    & $bootstrap

    $script:packageCalls.Count | Should -Be ($packageIds.Count * 2)
    $script:fontCalls.Count | Should -Be 0
  }

  It 'stops immediately when a package install fails' {
    $script:packageExitCode = 1
    $script:installedFamilies = @()

    { & $bootstrap } | Should -Throw "*$($packageIds[0])*exit code 1*"

    $script:packageCalls.Count | Should -Be 1
    $script:fontCalls.Count | Should -Be 0
  }

  It 'stops when font installation <Reason>' -ForEach @(
    @{ Reason = 'returns a failure'; ExitCode = 17; ExpectedError = '*exit code 17*' }
    @{ Reason = 'does not register the requested family'; ExitCode = 0; ExpectedError = '*is not available*' }
  ) {
    $script:installedFamilies = @()
    $script:fontExitCode = $ExitCode
    $script:registerFonts = $false

    { & $bootstrap } | Should -Throw $ExpectedError

    $script:fontCalls.Count | Should -Be 1
  }

  It 'reports a missing WinGet prerequisite without attempting installation' {
    Mock Get-Command { $null } -ParameterFilter { $Name -eq 'winget' }

    { & $bootstrap } | Should -Throw '*Install App Installer*'

    $script:packageCalls.Count | Should -Be 0
    $script:fontCalls.Count | Should -Be 0
  }

  It 'does not render Windows provisioning on <OperatingSystem>' -ForEach @(
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
