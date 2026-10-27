
param(
    [Parameter(Mandatory = $true)]
    [string]$ServerUrl,

    [string]$Version = "1.4.0"
)

$ErrorActionPreference = "Stop"

# MICO LAUNCHER - BUILD DE PRODUCAO

$root = $PSScriptRoot
if (-not $root) {
    throw "Execute este codigo como arquivo .ps1."
}

$electron = Join-Path $root "electron-win"
$app = Join-Path $root "app"
$flash = Join-Path $root "flash"
$icon = Join-Path $root "tools\icon.ico"
$rcedit = Join-Path $root "tools\bin\rcedit-x64.exe"
$nsis = "C:\Program Files (x86)\NSIS\makensis.exe"
$nsi = Join-Path $root "installer\mico-release.nsi"

$out = Join-Path $env:USERPROFILE "Mico-Setup-$Version-Release.exe"
$stage = Join-Path $env:TEMP (
    "Mico-Release-" + [guid]::NewGuid().ToString("N")
)

Write-Host "=== MICO LAUNCHER - RELEASE ==="

# 1. Validar versao
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Use uma versao como 1.4.0."
}

# 2. Exigir endereco HTTPS real
try {
    $uri = [System.Uri]$ServerUrl
} catch {
    throw "Endereco do servidor invalido."
}

if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne "https") {
    throw "A versao publica exige um endereco HTTPS."
}

$serverHost = $uri.DnsSafeHost.ToLowerInvariant()

if ($serverHost -notmatch '\.' -or
    $serverHost -match '(^|\.)localhost$|\.local$|\.test$|\.invalid$|\.example$|(^|\.)example\.(com|net|org)$') {
    throw "Informe o dominio oficial, nao localhost ou um exemplo."
}

$parsedIp = $null
if ([System.Net.IPAddress]::TryParse($serverHost, [ref]$parsedIp)) {
    throw "Para esta release, utilize um dominio HTTPS oficial."
}

if ($uri.UserInfo -or $uri.Query -or $uri.Fragment) {
    throw "Nao inclua usuario, senha, parametros ou fragmentos na URL."
}

# 3. Validar dependencias
Write-Host "[1/5] Verificando arquivos..."

$required = @(
    (Join-Path $electron "electron.exe"),
    (Join-Path $app "boot.js"),
    (Join-Path $app "main.js"),
    (Join-Path $app "mico-config.js"),
    (Join-Path $app "package.json"),
    (Join-Path $flash "pepflashplayer.dll"),
    $icon,
    $rcedit,
    $nsis,
    $nsi
)

foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath $file)) {
        throw "Arquivo nao encontrado: $file"
    }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js nao encontrado."
}

if (Test-Path -LiteralPath $out) {
    throw "Ja existe um instalador com essa versao: $out"
}

# 4. Validar JavaScript
Write-Host "[2/5] Verificando JavaScript..."

foreach ($name in @("boot.js", "main.js", "mico-config.js")) {
    & node --check (Join-Path $app $name)

    if ($LASTEXITCODE -ne 0) {
        throw "Erro de sintaxe em $name"
    }
}

try {
    # 5. Preparar Electron
    Write-Host "[3/5] Preparando arquivos..."

    New-Item -ItemType Directory -Path $stage -Force |
        Out-Null

    Copy-Item -Path (Join-Path $electron "*") `
        -Destination $stage -Recurse -Force

    $resources = Join-Path $stage "resources"

    New-Item -ItemType Directory -Path $resources -Force |
        Out-Null

    Copy-Item -LiteralPath $app `
        -Destination (Join-Path $resources "app") `
        -Recurse -Force

    Copy-Item -LiteralPath $flash `
        -Destination (Join-Path $resources "flash") `
        -Recurse -Force

    # 6. Configurar producao
    $buildJson = Join-Path $resources "app\build.json"

    $config = @{
        channel = "release"
        server = $ServerUrl.TrimEnd('/')
    }

    $json = $config | ConvertTo-Json -Compress
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $buildJson,
        $json,
        $utf8
    )

    # Verificar o arquivo gerado
    $savedConfig = Get-Content $buildJson -Raw |
        ConvertFrom-Json

    if ($savedConfig.channel -ne "release" -or
        $savedConfig.server -ne $config.server) {
        throw "Configuracao de producao incorreta!"
    }

    # 7. Preparar executavel
    Write-Host "[4/5] Aplicando identidade visual..."

    Rename-Item -LiteralPath (Join-Path $stage "electron.exe") `
        -NewName "Mico.exe"

    $exe = Join-Path $stage "Mico.exe"

    & $rcedit $exe --set-icon $icon
    if ($LASTEXITCODE -ne 0) {
        throw "Erro ao aplicar icone."
    }

    & $rcedit $exe --set-version-string "ProductName" "Mico"
    if ($LASTEXITCODE -ne 0) {
        throw "Erro ao definir nome."
    }

    & $rcedit $exe --set-version-string "FileDescription" "Mico Launcher"
    if ($LASTEXITCODE -ne 0) {
        throw "Erro ao definir descricao."
    }

    # 8. Compilar instalador
    Write-Host "[5/5] Compilando instalador..."

    & $nsis `
        "/DVERSION=$Version" `
        "/DSOURCE=$stage" `
        "/DOUTFILE=$out" `
        "/DICON=$icon" `
        $nsi

    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao compilar o instalador."
    }

    if (-not (Test-Path -LiteralPath $out)) {
        throw "Instalador nao foi gerado."
    }

    Write-Host ""
    Write-Host "MICO RELEASE COMPILADO COM SUCESSO!"
    Write-Host "Arquivo: $out"

    Get-Item -LiteralPath $out |
        Select-Object Name, Length, LastWriteTime
}
finally {
    # Remover somente a pasta temporaria desta build
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
