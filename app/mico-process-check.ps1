
param(
    [Parameter(Mandatory = $true)]
    [string]$ExecutablePath
)

$ErrorActionPreference = "Stop"

try {
    $target = [System.IO.Path]::GetFullPath($ExecutablePath)

    $processes = @(
        Get-CimInstance Win32_Process `
            -Filter "Name = 'Mico.exe'" `
            -ErrorAction Stop
    )

    foreach ($process in $processes) {
        if (-not $process.ExecutablePath) {
            exit 3
        }

        $current = [System.IO.Path]::GetFullPath(
            $process.ExecutablePath
        )

        if ([string]::Equals(
            $current,
            $target,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            exit 2
        }
    }

    exit 0
}
catch {
    exit 3
}
