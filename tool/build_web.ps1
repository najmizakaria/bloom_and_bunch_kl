$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$webSettings = @{}
Get-Content .env | ForEach-Object {
  if ($_ -match '^([A-Z0-9_]+)=(.*)$') { $webSettings[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'") }
}
if (!$webSettings['FIREBASE_API_KEY_WEB'] -or !$webSettings['MAPS_API_KEY_WEB']) { throw 'Missing Firebase or Maps web key in .env.' }
$buildArguments = @('build', 'web', "--dart-define=FIREBASE_API_KEY_WEB=$($webSettings['FIREBASE_API_KEY_WEB'])")
if ($webSettings['FCM_VAPID_KEY_WEB']) { $buildArguments += "--dart-define=FCM_VAPID_KEY_WEB=$($webSettings['FCM_VAPID_KEY_WEB'])" }
& flutter @buildArguments
if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
node tool/configure_web.cjs
if ($LASTEXITCODE -ne 0) { throw 'Web configuration failed.' }
node tool/validate_web_build.cjs
if ($LASTEXITCODE -ne 0) { throw 'Web validation failed.' }
