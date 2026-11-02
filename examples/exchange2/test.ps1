param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Profile,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Scenario
)

$candidate = $Scenario
if (-not [System.IO.Path]::IsPathRooted($candidate)) {
    $fromHere = Join-Path (Get-Location) $candidate
    $besideScript = Join-Path $PSScriptRoot $candidate
    if (Test-Path -LiteralPath $fromHere) {
        $candidate = (Resolve-Path -LiteralPath $fromHere).Path
    } elseif (Test-Path -LiteralPath $besideScript) {
        $candidate = (Resolve-Path -LiteralPath $besideScript).Path
    }
}

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root
dart run examples/exchange2/test.dart $Profile $candidate @args
exit $LASTEXITCODE
