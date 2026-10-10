param([switch]$LegacyGuard, [string]$ScriptPath)
$ErrorActionPreference = 'Stop'
if ($LegacyGuard) {
  try {
    if ($ScriptPath.EndsWith('package-source.ps1')) {
      & $ScriptPath -Tag 'v0.0.0'
    } else {
      & $ScriptPath -RequireExistingSignature
    }
  } catch {
    if ($_.Exception.Message -match '7\.2') { exit 0 }
    throw
  }
  throw 'An unsupported environment was not rejected.'
}
if ($PSVersionTable.PSVersion -lt [version]'7.2') { throw 'Run this test with pwsh 7.2+.' }
$testRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('jianzhang-build-test-' + [guid]::NewGuid())))
New-Item -ItemType Directory -Path (Join-Path $testRoot 'scripts') | Out-Null
try {
  $projectRoot = Split-Path -Parent $PSScriptRoot
  Copy-Item -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Destination $testRoot
  Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $testRoot
  foreach ($script in @('build-release.ps1', 'package-source.ps1')) {
    $target = Join-Path $testRoot "scripts/$script"
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $script) -Destination $target
    & powershell.exe -NoProfile -File $PSCommandPath -LegacyGuard -ScriptPath $target
    if ($LASTEXITCODE -ne 0) { throw 'PowerShell 5.1 did not give the minimum-version error.' }
  }
  if ((Test-Path -LiteralPath (Join-Path $testRoot '.signing')) -or (Test-Path -LiteralPath (Join-Path $testRoot 'output'))) {
    throw 'Legacy rejection must happen before output/signature writes.'
  }
  Push-Location $testRoot
  try {
    git init --quiet
    git add pubspec.yaml README.md scripts
    git -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m 'Synthetic packaging fixture'
    if ($LASTEXITCODE -ne 0) { throw 'Fixture commit failed.' }
    $version = ((Select-String -LiteralPath pubspec.yaml -Pattern '^version:').Line -replace '^version:\s*', '').Split('+')[0]
    $tag = 'v' + $version
    git tag $tag
    if ($LASTEXITCODE -ne 0) { throw 'Fixture tag failed.' }
    $package = & (Join-Path $testRoot 'scripts/package-source.ps1') -Tag $tag
    if ($package.verified_tag_files -ne 4 -or -not (Test-Path -LiteralPath $package.path)) { throw 'Source integrity verification failed.' }
    try {
      & (Join-Path $testRoot 'scripts/package-source.ps1') -Tag $tag | Out-Null
      throw 'Existing output was unexpectedly overwritten.'
    } catch {
      if ($_.Exception.Message -eq 'Existing output was unexpectedly overwritten.') { throw }
    }
    Write-Output 'PowerShell guards, source integrity and no-overwrite checks passed.'
  } finally { Pop-Location }
} finally {
  # Delete only the exact test-created directory under the system temporary path.
  $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
  if ((Split-Path -Parent $testRoot) -ne $expectedParent -or (Split-Path -Leaf $testRoot) -notmatch '^jianzhang-build-test-[a-f0-9-]+$') { throw 'Unsafe temporary cleanup path.' }
  Remove-Item -LiteralPath $testRoot -Recurse -Force
}
