$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
flutter build web
if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
node tool/configure_web.cjs
if ($LASTEXITCODE -ne 0) { throw 'Web configuration failed.' }
