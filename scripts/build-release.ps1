param(
  [string]$FlutterRoot = 'D:\Dev\flutter',
  [string]$AndroidSdk = 'D:\Android\Sdk',
  [string]$JavaRoot = 'C:\Program Files\Android\Android Studio\jbr'
)
$ErrorActionPreference = 'Stop'
$appRoot = Split-Path -Parent $PSScriptRoot
$appSigning = Join-Path $appRoot '.signing'
$appKey = Join-Path $appSigning 'jianzhang-release.p12'
$appSecret = Join-Path $appSigning 'password.xml'
$appVersion = ((Get-Content (Join-Path $appRoot 'pubspec.yaml') | Select-String '^version:').Line -replace '^version:\s*','').Split('+')[0]
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
    Copy-Item -LiteralPath (Join-Path $appRoot 'build\app\outputs\flutter-apk\app-release.apk') -Destination (Join-Path $appOutput "jianzhang-$appVersion.apk")
    Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $appOutput "jianzhang-$appVersion.apk")
  } finally { Pop-Location }
} finally {
  Remove-Item Env:JIANZHANG_KEY_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:JIANZHANG_KEYSTORE -ErrorAction SilentlyContinue
  $appPlain = $null
}
