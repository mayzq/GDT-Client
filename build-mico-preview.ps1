
# ============================================================
# MICO LAUNCHER - AUTOMATED PREVIEW BUILD
# Minecraft? Nao! Animal Jam Classic Launcher
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# 1. CAMINHOS DO PROJETO
# ------------------------------------------------------------

$root = $PSScriptRoot

$electron = Join-Path $root "electron-win"
$app = Join-Path $root "app"
$flash = Join-Path $root "flash"

$icon = Join-Path $root "tools\icon.ico"
$rcedit = Join-Path $root "tools\bin\rcedit-x64.exe"

$nsis = "C:\Program Files (x86)\NSIS\makensis.exe"
$nsiScript = Join-Path $root "installer\mico.nsi"

# ------------------------------------------------------------
# 2. CAMINHOS DE SAIDA
# ------------------------------------------------------------

$out = Join-Path $env:USERPROFILE "Mico-Setup-Preview-Auto.exe"

# Cada compilacao utiliza uma pasta temporaria exclusiva
$stage = Join-Path $env:TEMP (
    "Mico-Build-" + [guid]::NewGuid().ToString("N")
)

# ------------------------------------------------------------
# 3. VERIFICAR DEPENDENCIAS
# ------------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host "       MICO LAUNCHER BUILD SYSTEM"
Write-Host "========================================"
Write-Host ""

Write-Host "[1/6] Verificando dependencias..."

$required = @(
    (Join-Path $electron "electron.exe"),
    (Join-Path $app "boot.js"),
    (Join-Path $app "main.js"),
    (Join-Path $app "package.json"),
    (Join-Path $flash "pepflashplayer.dll"),
    $icon,
    $rcedit,
    $nsis,
    $nsiScript
)

foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath $file)) {
        throw "Arquivo necessario nao encontrado: $file"
    }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js nao encontrado no PATH!"
}

Write-Host "Dependencias encontradas!"

# ------------------------------------------------------------
# 4. VERIFICAR CODIGO JAVASCRIPT
# ------------------------------------------------------------

Write-Host ""
Write-Host "[2/6] Verificando JavaScript..."

& node --check (Join-Path $app "boot.js")

if ($LASTEXITCODE -ne 0) {
    throw "Erro de sintaxe no boot.js!"
}

& node --check (Join-Path $app "main.js")

if ($LASTEXITCODE -ne 0) {
    throw "Erro de sintaxe no main.js!"
}

Write-Host "JavaScript verificado!"

# ------------------------------------------------------------
# 5. PREPARAR ARQUIVOS
# ------------------------------------------------------------

try {

    Write-Host ""
    Write-Host "[3/6] Preparando arquivos do Mico..."

    New-Item -ItemType Directory -Path $stage -Force |
        Out-Null

    # Copiar os arquivos do Electron
    Copy-Item `
        -Path (Join-Path $electron "*") `
        -Destination $stage `
        -Recurse `
        -Force

    # Preparar pasta resources
    $resources = Join-Path $stage "resources"

    New-Item -ItemType Directory -Path $resources -Force |
        Out-Null

    # Copiar arquivos do aplicativo
    Copy-Item `
        -LiteralPath $app `
        -Destination (Join-Path $resources "app") `
        -Recurse `
        -Force

    # Copiar Flash
    Copy-Item `
        -LiteralPath $flash `
        -Destination (Join-Path $resources "flash") `
        -Recurse `
        -Force

    # --------------------------------------------------------
    # 6. CONFIGURAR SERVIDOR DE TESTES
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "[4/6] Configurando Mico Preview..."

    $buildJson = Join-Path $resources "app\build.json"

    # UTF-8 sem BOM
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $buildJson,
        '{"server":"http://127.0.0.1:8080"}',
        $utf8
    )

    # Renomear executavel Electron para Mico
    $originalExe = Join-Path $stage "electron.exe"
    $micoExe = Join-Path $stage "Mico.exe"

    Rename-Item `
        -LiteralPath $originalExe `
        -NewName "Mico.exe"

    # --------------------------------------------------------
    # 7. APLICAR IDENTIDADE VISUAL
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "[5/6] Aplicando identidade visual..."

    # Icone personalizado
    & $rcedit $micoExe --set-icon $icon

    if ($LASTEXITCODE -ne 0) {
        throw "Erro ao aplicar icone!"
    }

    # Nome do produto
    & $rcedit $micoExe `
        --set-version-string "ProductName" "Mico Preview"

    if ($LASTEXITCODE -ne 0) {
        throw "Erro ao definir nome do produto!"
    }

    # Descricao
    & $rcedit $micoExe `
        --set-version-string "FileDescription" "Mico Launcher Preview"

    if ($LASTEXITCODE -ne 0) {
        throw "Erro ao definir descricao!"
    }

    Write-Host "Identidade visual aplicada!"

    # --------------------------------------------------------
    # 8. COMPILAR INSTALADOR NSIS
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "[6/6] Compilando instalador Windows..."

    & $nsis `
        "/DVERSION=1.4.0" `
        "/DSOURCE=$stage" `
        "/DOUTFILE=$out" `
        "/DICON=$icon" `
        $nsiScript

    if ($LASTEXITCODE -ne 0) {
        throw "Erro na compilacao do instalador NSIS!"
    }

    if (-not (Test-Path -LiteralPath $out)) {
        throw "O instalador nao foi gerado!"
    }

    # --------------------------------------------------------
    # 9. FINALIZAR
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "========================================"
    Write-Host "    MICO COMPILADO COM SUCESSO!"
    Write-Host "========================================"
    Write-Host ""

    Write-Host "Instalador gerado em:"
    Write-Host $out

    Write-Host ""

    Get-Item -LiteralPath $out |
        Select-Object Name, Length, LastWriteTime

}
finally {

    # --------------------------------------------------------
    # 10. LIMPAR ARQUIVOS TEMPORARIOS
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Limpando arquivos temporarios..."

    if (Test-Path -LiteralPath $stage) {
        Remove-Item `
            -LiteralPath $stage `
            -Recurse `
            -Force
    }

    Write-Host "Limpeza concluida!"
}
