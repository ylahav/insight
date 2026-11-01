# Build the Windows tools and, when Inno Setup is installed, the installer.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $root 'dist\windows\stage'
$bin = Join-Path $stage 'bin'
$analyzerDest = Join-Path $stage 'analyzer'

if (Test-Path $stage) {
  Remove-Item $stage -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $bin | Out-Null
New-Item -ItemType Directory -Force -Path $analyzerDest | Out-Null

Push-Location (Join-Path $root 'tool\analyzer')
try {
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}

$built = Join-Path $root 'tool\analyzer\build\windows\x64\runner\Release'
Copy-Item (Join-Path $built '*') $analyzerDest -Recurse

$tools = @(
  @{ Source = 'tool\compare.dart'; Name = 'compare.exe' },
  @{ Source = 'tool\play.dart'; Name = 'play.exe' },
  @{ Source = 'tool\record.dart'; Name = 'record.exe' },
  @{ Source = 'tool\parser_check.dart'; Name = 'parser_check.exe' },
  @{ Source = 'packages\insight_cli\bin\insight_cli.dart'; Name = 'insight_cli.exe' }
)

Push-Location $root
try {
  foreach ($tool in $tools) {
    $out = Join-Path $bin $tool.Name
    dart compile exe $tool.Source -o $out
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
} finally {
  Pop-Location
}

Write-Output "Staged the tools in $stage"

$iscc = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $iscc) {
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { $iscc = $cmd.Source }
}

$iss = Join-Path $root 'tool\windows\insight.iss'
if ($iscc) {
  & $iscc $iss
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Output "Wrote $(Join-Path $root 'dist\windows\Insight-Setup.exe')"
} else {
  Write-Output "Inno Setup is not installed, so the installer was not compiled."
  Write-Output "Install Inno Setup 6, then run this script again."
  Write-Output "The script is $iss"
}
