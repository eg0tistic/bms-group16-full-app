param(
  [ValidateSet('web', 'apk', 'doctor')]
  [string] $Action = 'web'
)

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$flutterDir = Join-Path $env:USERPROFILE 'dev\flutter'
$flutterBin = Join-Path $flutterDir 'bin'
$androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$cmdlineToolsUrl = 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip'
$cmdlineToolsLatest = Join-Path $androidSdk 'cmdline-tools\latest'

function Refresh-Path {
  $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $androidTools = @(
    (Join-Path $androidSdk 'platform-tools'),
    (Join-Path $cmdlineToolsLatest 'bin')
  ) -join ';'
  $env:Path = "$flutterBin;$androidTools;$machinePath;$userPath"
}

function Add-UserPath($pathToAdd) {
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($userPath -notlike "*$pathToAdd*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$pathToAdd", 'User')
  }
}

function Install-WingetPackage($id) {
  Write-Host "Installing/checking $id ..."
  winget install --id $id --exact --source winget --accept-package-agreements --accept-source-agreements
}

function Install-AndroidCommandLineTools {
  if (Test-Path -LiteralPath (Join-Path $cmdlineToolsLatest 'bin\sdkmanager.bat')) {
    return
  }

  Write-Host 'Installing Android command-line tools...'
  New-Item -ItemType Directory -Path $androidSdk -Force | Out-Null

  $zipPath = Join-Path $env:TEMP 'android-commandline-tools.zip'
  $extractPath = Join-Path $env:TEMP 'android-commandline-tools'

  Invoke-WebRequest -Uri $cmdlineToolsUrl -OutFile $zipPath
  if (Test-Path -LiteralPath $extractPath) {
    Remove-Item -LiteralPath $extractPath -Recurse -Force
  }
  Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

  New-Item -ItemType Directory -Path $cmdlineToolsLatest -Force | Out-Null
  Copy-Item -Path (Join-Path $extractPath 'cmdline-tools\*') -Destination $cmdlineToolsLatest -Recurse -Force
}

function Configure-Java {
  $jdkRoot = 'C:\Program Files\Eclipse Adoptium'
  if (Test-Path -LiteralPath $jdkRoot) {
    $jdk = Get-ChildItem -LiteralPath $jdkRoot -Directory -Filter 'jdk-17*' |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($jdk) {
      [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk.FullName, 'User')
      $env:JAVA_HOME = $jdk.FullName
      Add-UserPath (Join-Path $jdk.FullName 'bin')
    }
  }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw 'winget was not found. Open Microsoft Store, install "App Installer", then run this script again.'
}

Install-WingetPackage 'Git.Git'
Install-WingetPackage 'Microsoft.VisualStudioCode'
Install-WingetPackage 'Google.Chrome'
Install-WingetPackage 'EclipseAdoptium.Temurin.17.JDK'

Refresh-Path
Configure-Java

if (-not (Test-Path -LiteralPath (Join-Path $flutterBin 'flutter.bat'))) {
  Write-Host 'Installing Flutter SDK...'
  New-Item -ItemType Directory -Path (Split-Path $flutterDir) -Force | Out-Null
  git clone https://github.com/flutter/flutter.git -b stable $flutterDir
}

Add-UserPath $flutterBin

[Environment]::SetEnvironmentVariable('ANDROID_HOME', $androidSdk, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $androidSdk, 'User')
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk

Install-AndroidCommandLineTools
Refresh-Path

$sdkManager = Join-Path $cmdlineToolsLatest 'bin\sdkmanager.bat'
Write-Host 'Installing Android SDK packages...'
& $sdkManager --sdk_root=$androidSdk 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'

Write-Host 'Accepting Android SDK licenses...'
$licenseAnswers = ("y`n" * 100)
$licenseAnswers | & $sdkManager --sdk_root=$androidSdk --licenses

Write-Host 'Installing VS Code Flutter extension...'
code --install-extension Dart-Code.flutter --force

Set-Location -LiteralPath $projectRoot

Write-Host 'Getting Flutter packages...'
& (Join-Path $flutterBin 'flutter.bat') pub get

Write-Host 'Opening project in VS Code...'
code $projectRoot

if ($Action -eq 'doctor') {
  & (Join-Path $flutterBin 'flutter.bat') doctor -v
  exit 0
}

if ($Action -eq 'apk') {
  Write-Host 'Building APK...'
  & (Join-Path $flutterBin 'flutter.bat') build apk --release
  Copy-Item -LiteralPath (Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk') -Destination (Join-Path $projectRoot 'BMS_Group16_FULL_APP.apk') -Force
  Write-Host 'APK ready: BMS_Group16_FULL_APP.apk'
  exit 0
}

Write-Host 'Starting the app in Chrome...'
& (Join-Path $flutterBin 'flutter.bat') run -d chrome
