BeforeAll {
  $repositoryRoot = Split-Path -Parent $PSScriptRoot
  $templatePath = Join-Path $repositoryRoot 'dot_powershell\profile.ps1.tmpl'

  function Set-PSReadLineOption {
    param([string]$HistorySavePath)
    throw 'History configuration must be mocked during tests.'
  }
}

Describe 'PowerShell history location' {
  BeforeEach {
    Mock Set-PSReadLineOption {}
  }

  It 'uses <Folder> for <Email>' -ForEach @(
    @{ Email = 'user@microsoft.com'; Folder = 'OneDrive - Microsoft' }
    @{ Email = 'user@MICROSOFT.COM'; Folder = 'OneDrive - Microsoft' }
    @{ Email = 'user@outlook.com'; Folder = 'OneDrive' }
    @{ Email = 'user@microsoft.com.example.org'; Folder = 'OneDrive' }
  ) {
    $overridePath = Join-Path $TestDrive 'email.json'
    @{ email = $Email } | ConvertTo-Json | Set-Content -LiteralPath $overridePath
    $rendered = & chezmoi --source $repositoryRoot --override-data-file $overridePath execute-template --file $templatePath
    $LASTEXITCODE | Should -Be 0

    $tokens = $null
    $parseErrors = $null
    $profileAst = [System.Management.Automation.Language.Parser]::ParseInput(
      ($rendered -join "`n"), [ref]$tokens, [ref]$parseErrors
    )
    $parseErrors | Should -BeNullOrEmpty
    $historyCommand = $profileAst.Find({
      param($node)
      $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Set-PSReadLineOption'
    }, $true)
    $historyCommand | Should -Not -BeNullOrEmpty

    & ([scriptblock]::Create($historyCommand.Extent.Text))

    Should -Invoke Set-PSReadLineOption -Exactly -Times 1 -ParameterFilter {
      $HistorySavePath -eq "$HOME\$Folder\PowerShell\history.txt"
    }
  }
}
