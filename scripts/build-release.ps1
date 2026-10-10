param(
  [string]$FlutterRoot = 'D:\Dev\flutter',
  [string]$AndroidSdk = 'D:\Android\Sdk',
  [string]$JavaRoot = 'C:\Program Files\Android\Android Studio\jbr',
  [switch]$RequireExistingSignature
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.2' -or $PSVersionTable.PSEdition -ne 'Core') { throw '需要 PowerShell 7.2 或更新版本；请安装 https://aka.ms/powershell 并使用 pwsh 执行。未写入签名或产物。' }
if (-not $IsWindows) { throw '发行签名脚本仅支持 Windows（使用 DPAPI）；请在原 Windows 签名环境运行。' }
$appRoot = Split-Path -Parent $PSScriptRoot
$appSigning = Join-Path $appRoot '.signing'
$appKey = Join-Path $appSigning 'jianzhang-release.p12'
$appSecret = Join-Path $appSigning 'password.xml'
$appVersionParts = ((Get-Content (Join-Path $appRoot 'pubspec.yaml') | Select-String '^version:').Line -replace '^version:\s*','').Split('+')
if ($appVersionParts.Count -ne 2 -or $appVersionParts[1] -notmatch '^[1-9][0-9]*$') { throw '版本必须包含正整数构建号。' }
$appVersion = $appVersionParts[0]
$appBuild = $appVersionParts[1]
$appDestination = Join-Path $appRoot "output\jianzhang-android-$appVersion-build$appBuild.apk"
if (Test-Path -LiteralPath $appDestination) { throw '安装包已存在，禁止覆盖；新的分发构建请增加构建号。' }
if ($RequireExistingSignature -and (-not (Test-Path -LiteralPath $appKey) -or -not (Test-Path -LiteralPath $appSecret))) { throw '维护者原签名材料不完整，禁止生成替代密钥。' }
New-Item -ItemType Directory -Path $appSigning -Force | Out-Null
if (-not (Test-Path -LiteralPath $appSecret)) {
  if (Test-Path -LiteralPath $appKey) { throw '已有签名密钥但找不到密码文件，请恢复原签名材料。' }
  $appBytes = [byte[]]::new(32)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($appBytes)
  $appPlain = [Convert]::ToBase64String($appBytes)
  $appSecure = ConvertTo-SecureString $appPlain -AsPlainText -Force
  $appSecure | Export-Clixml -LiteralPath $appSecret
} else {
  $appSecure = Import-Clixml -LiteralPath $appSecret
  $appPlain = [System.Net.NetworkCredential]::new('', $appSecure).Password
}
$env:ANDROID_HOME = $AndroidSdk
$env:JAVA_HOME = $JavaRoot
$env:JIANZHANG_KEYSTORE = $appKey
$env:JIANZHANG_KEY_PASSWORD = $appPlain
try {
  if (-not (Test-Path -LiteralPath $appKey)) {
    & (Join-Path $JavaRoot 'bin\keytool.exe') -genkeypair -keystore $appKey -storetype PKCS12 -alias jianzhang -keyalg RSA -keysize 3072 -validity 10000 -storepass:env JIANZHANG_KEY_PASSWORD -keypass:env JIANZHANG_KEY_PASSWORD -dname 'CN=Jianzhang Personal, OU=Offline App, O=Personal, C=CN'
    if ($LASTEXITCODE -ne 0) { throw '无法创建应用签名。' }
  }
  Push-Location $appRoot
  try {
    & (Join-Path $FlutterRoot 'bin\flutter.bat') --no-version-check build apk --release --target-platform android-arm,android-arm64,android-x64
    if ($LASTEXITCODE -ne 0) { throw '安卓构建失败。' }
    $appOutput = Join-Path $appRoot 'output'
    New-Item -ItemType Directory -Path $appOutput -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $appRoot 'build\app\outputs\flutter-apk\app-release.apk') -Destination $appDestination
    Get-FileHash -Algorithm SHA256 -LiteralPath $appDestination
  } finally { Pop-Location }
} finally {
  Remove-Item Env:JIANZHANG_KEY_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:JIANZHANG_KEYSTORE -ErrorAction SilentlyContinue
  $appPlain = $null
}
