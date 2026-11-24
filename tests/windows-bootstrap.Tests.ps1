BeforeAll {
  $repositoryRoot = Split-Path -Parent $PSScriptRoot
  $templatePath = Join-Path $repositoryRoot 'run_before_windows-install-packages.ps1.tmpl'
  $bootstrapDataPath = Join-Path $TestDrive 'bootstrap-data.json'
  @{ email = 'user@example.com'; optionalApps = $true } | ConvertTo-Json |
    Set-Content -LiteralPath $bootstrapDataPath
  $rendered = & chezmoi --source $repositoryRoot --override-data-file $bootstrapDataPath execute-template --file $templatePath
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to render the Windows bootstrap.'
  }
  $bootstrap = [scriptblock]::Create(($rendered -join "`n"))

  $packageData = & chezmoi --source $repositoryRoot execute-template '{{ .packages.windows | toJson }}'
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to render the Windows package data.'
  }
  $windowsPackages = ($packageData -join "`n") | ConvertFrom-Json
  $requiredPackageIds = @($windowsPackages.winget)
  $optionalPackageIds = @($windowsPackages.wingetOptional)
  $nonMicrosoftPackageIds = @($windowsPackages.wingetNonMicrosoft)
  $packageIds = @($requiredPackageIds + $optionalPackageIds + $nonMicrosoftPackageIds)
  $fontSpecs = @($windowsPackages.fonts)

  function Get-RenderedPackageIds {
    param([hashtable]$Data)
    $overridePath = Join-Path $TestDrive 'gate-data.json'
    $Data | ConvertTo-Json | Set-Content -LiteralPath $overridePath
    $output = & chezmoi --source $repositoryRoot --override-data-file $overridePath execute-template --file $templatePath
    if ($LASTEXITCODE -ne 0) {
      throw 'Unable to render the Windows bootstrap.'
    }
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
      ($output -join "`n"), [ref]$null, [ref]$null
    )
    $assignment = $ast.Find({
      param($node)
      $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left.Extent.Text -eq '$packageIds'
    }, $true)
    @(& ([scriptblock]::Create($assignment.Right.Extent.Text)))
  }

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

Describe 'Windows package gates' {
  It 'installs optional apps: <OptionalApps>, non-Microsoft apps for <Email>' -ForEach @(
    @{ OptionalApps = $true;  Email = 'user@example.com';   ExpectOptional = $true;  ExpectNonMicrosoft = $true }
    @{ OptionalApps = $false; Email = 'user@example.com';   ExpectOptional = $false; ExpectNonMicrosoft = $true }
    @{ OptionalApps = $true;  Email = 'user@microsoft.com'; ExpectOptional = $true;  ExpectNonMicrosoft = $false }
    @{ OptionalApps = $false; Email = 'user@MICROSOFT.COM'; ExpectOptional = $false; ExpectNonMicrosoft = $false }
    @{ OptionalApps = $false; Email = 'user@microsoft.com.example.org'; ExpectOptional = $false; ExpectNonMicrosoft = $true }
  ) {
    $rendered = Get-RenderedPackageIds @{ email = $Email; optionalApps = $OptionalApps }

    $expected = @($requiredPackageIds)
    if ($ExpectOptional) { $expected += $optionalPackageIds }
    if ($ExpectNonMicrosoft) { $expected += $nonMicrosoftPackageIds }
    $rendered | Should -Be $expected
  }

  It 'keeps installing optional apps when optionalApps has not been set' {
    $overridePath = Join-Path $TestDrive 'no-gate.json'
    @{ email = 'user@example.com' } | ConvertTo-Json | Set-Content -LiteralPath $overridePath
    $configPath = Join-Path $TestDrive 'empty.toml'
    Set-Content -LiteralPath $configPath -Value ''
    $output = & chezmoi --source $repositoryRoot --config $configPath --override-data-file $overridePath execute-template --file $templatePath
    $LASTEXITCODE | Should -Be 0
    foreach ($id in $optionalPackageIds) {
      ($output -join "`n") | Should -Match ([regex]::Escape("`"$id`""))
    }
  }

  It 'ignores optional app configuration only when optionalApps is false' {
    $ignorePath = Join-Path $repositoryRoot '.chezmoiignore'
    foreach ($case in @(@{ Value = $true; Ignored = $false }, @{ Value = $false; Ignored = $true })) {
      $overridePath = Join-Path $TestDrive 'ignore.json'
      @{ email = 'user@example.com'; optionalApps = $case.Value } | ConvertTo-Json |
        Set-Content -LiteralPath $overridePath
      $output = (& chezmoi --source $repositoryRoot --override-data-file $overridePath execute-template --file $ignorePath) -join "`n"
      $LASTEXITCODE | Should -Be 0
      foreach ($pattern in '.config/powertoys', 'AppData/Local/Microsoft/PowerToys', '.logseq') {
        if ($case.Ignored) {
          $output | Should -Match "(?m)^$([regex]::Escape($pattern))\r?$"
        } else {
          $output | Should -Not -Match "(?m)^$([regex]::Escape($pattern))\r?$"
        }
      }
    }
  }
}
