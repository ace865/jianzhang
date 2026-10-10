param([Parameter(Mandatory=$true)][string]$Tag)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.2' -or $PSVersionTable.PSEdition -ne 'Core') { throw '需要 PowerShell 7.2 或更新版本；请安装 https://aka.ms/powershell 并使用 pwsh 执行。未写入源码产物。' }
if ($Tag -notmatch '^v\d+\.\d+\.\d+(-[A-Za-z0-9.]+)?$') { throw '无效版本标签' }
$sourceAppRoot = Split-Path -Parent $PSScriptRoot
Push-Location $sourceAppRoot
try {
  $sourceCommit = (git rev-parse "${Tag}^{commit}").Trim()
  if ($LASTEXITCODE -ne 0) { throw '找不到版本标签' }
  $sourceVersion = $Tag.Substring(1)
  $sourcePubspec = (git show "${sourceCommit}:pubspec.yaml") -join "`n"
  if ($sourcePubspec -notmatch '(?m)^version:\s*([^+\s]+)\+\d+') { throw '标签缺少应用版本' }
  if ($Matches[1] -ne $sourceVersion) { throw '标签与源码应用版本不一致' }
  $sourcePrefix = "jianzhang-$sourceVersion/"
  $sourceOutput = Join-Path $sourceAppRoot 'output'
  New-Item -ItemType Directory -Path $sourceOutput -Force | Out-Null
  $sourceZipPath = Join-Path $sourceOutput "jianzhang-$sourceVersion-source.zip"
  if (Test-Path -LiteralPath $sourceZipPath) { throw '源码包已经存在，避免覆盖既有版本' }
  git -c core.autocrlf=false archive --format=zip "--prefix=$sourcePrefix" "--output=$sourceZipPath" $Tag
  if ($LASTEXITCODE -ne 0) { throw '源码打包失败' }
  # Only the historical first beta needs supplemental documentation.
  # New tags archive their own complete documents without mixing in working-tree files.
  $sourceSupplements = @()
  if ($Tag -eq 'v1.0.0-beta.1') {
    $sourceSupplements = @('LICENSE','THIRD_PARTY_NOTICES.md','CONTRIBUTING.md','AGENTS.md','CLAUDE.md','docs/development.md','docs/BUILD.md','docs/SOURCE_VERSION.md')
    $sourceSupplements += @(Get-ChildItem -LiteralPath (Join-Path $sourceAppRoot 'docs/licenses') -File | ForEach-Object { 'docs/licenses/' + $_.Name })
  }
  $sourceZip = [System.IO.Compression.ZipFile]::Open($sourceZipPath, [System.IO.Compression.ZipArchiveMode]::Update)
  try {
    foreach ($sourceRelative in $sourceSupplements) {
      $sourceEntryName = $sourcePrefix + $sourceRelative
      if ($sourceZip.GetEntry($sourceEntryName)) { continue }
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($sourceZip, (Join-Path $sourceAppRoot $sourceRelative), $sourceEntryName) | Out-Null
    }
  } finally { $sourceZip.Dispose() }
  $sourceZip = [System.IO.Compression.ZipFile]::OpenRead($sourceZipPath)
  $sourceVerified = 0
  try {
    foreach ($sourceTreeRow in (git ls-tree -r $Tag)) {
      if ($sourceTreeRow -notmatch '^\d+\s+blob\s+([a-f0-9]{40})\t(.+)$') { throw '不支持的 Git 树条目' }
      $sourceExpectedHash = $Matches[1]
      $sourceRelative = $Matches[2]
      $sourceEntry = $sourceZip.GetEntry($sourcePrefix + $sourceRelative)
      if (-not $sourceEntry) { throw "源码缺失：$sourceRelative" }
      $sourceHasher = [System.Security.Cryptography.IncrementalHash]::CreateHash([System.Security.Cryptography.HashAlgorithmName]::SHA1)
      $sourceStream = $sourceEntry.Open()
      try {
        $sourceHasher.AppendData([System.Text.Encoding]::UTF8.GetBytes("blob $($sourceEntry.Length)`0"))
        $sourceBuffer = [byte[]]::new(65536)
        while (($sourceCount = $sourceStream.Read($sourceBuffer, 0, $sourceBuffer.Length)) -gt 0) { $sourceHasher.AppendData($sourceBuffer, 0, $sourceCount) }
        $sourceActualHash = [Convert]::ToHexString($sourceHasher.GetHashAndReset()).ToLowerInvariant()
        if ($sourceActualHash -ne $sourceExpectedHash) { throw "源码与标签不一致：$sourceRelative" }
        $sourceVerified++
      } finally { $sourceStream.Dispose(); $sourceHasher.Dispose() }
    }
    foreach ($sourceEntry in $sourceZip.Entries) {
      if ($sourceEntry.FullName -match '(^|/)(\.signing|\.env[^/]*|local\.properties|key\.properties)(/|$)|\.(p12|jks|keystore|db|db-wal|db-shm|apk)$') { throw '源码包包含不应发布的文件' }
    }
  } finally { $sourceZip.Dispose() }
  [pscustomobject]@{ path=$sourceZipPath; tag=$Tag; commit=$sourceCommit; verified_tag_files=$sourceVerified; sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $sourceZipPath).Hash.ToLowerInvariant() }
} finally { Pop-Location }
