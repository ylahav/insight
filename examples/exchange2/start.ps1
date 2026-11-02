param(
    [Parameter(Position = 0)]
    [string]$Profile = 'bloc',

    [Parameter(Position = 1)]
    [int]$Lines = 3
)

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root
dart run examples/exchange2/start.dart $Profile $Lines
exit $LASTEXITCODE
