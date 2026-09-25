# Carga funciones puras de MusicDL.bat para tests (sin UI).
# Uso: . $PSScriptRoot\Import-MusicDLFns.ps1

$ErrorActionPreference = 'Stop'
$batPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
if (-not (Test-Path -LiteralPath $batPath)) {
    throw "No encuentro MusicDL.bat en $(Split-Path $batPath -Parent)"
}

$raw = [IO.File]::ReadAllText($batPath, [Text.Encoding]::UTF8)
$idx = $raw.IndexOf('#>')
if ($idx -lt 0) { throw 'MusicDL.bat: no encuentro cierre de bloque CMD (#>)' }
$psText = $raw.Substring($idx + 2)

$tokens = $null
$errs = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($psText, [ref]$tokens, [ref]$errs)
if ($errs -and $errs.Count -gt 0) {
    $msg = ($errs | ForEach-Object { $_.ToString() }) -join '; '
    throw "Parse MusicDL.bat: $msg"
}

# Stubs de dependencias usadas por algunas funciones
if (-not (Get-Command Registrar-Error -ErrorAction SilentlyContinue)) {
    function script:Registrar-Error([string]$msg) { }
}
if (-not (Get-Command Catch-Log -ErrorAction SilentlyContinue)) {
    function script:Catch-Log([string]$contexto, $err) { }
}
if (-not (Get-Command Aviso -ErrorAction SilentlyContinue)) {
    function script:Aviso($texto, $icono = 'Information') { }
}

$wanted = @(
    'Q', 'Formato-Args-Informe',
    'Raices-Destino-Permitidas', 'Carpeta-Destino-Por-Defecto', 'Es-Carpeta-Destino-Segura', 'Normalizar-Carpeta-Destino',
    'Texto-Destino-Amigable',
    'Verificar-Sha256', 'Verificar-Firma',
    'Es-Enlace-Spotify', 'Tipo-Enlace', 'Es-Enlace-Valido', 'Arreglar-Enlace',
    'Es-Titulo-Comodin-Drm', 'Titulo-Desde-Url-Track', 'Titulo-Para-Busqueda-Drm',
    'Idioma-Actual', 'T',
    'Nombre-Carpeta-Seguro', 'Archivo-Historial', 'Construir-Args'
)

$fns = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $wanted -contains $node.Name
    }, $true)

$loaded = @{}
foreach ($fn in $fns) {
    # global: para que Pester (scopes aislados) vea las funciones
    $text = $fn.Extent.Text -replace '^function\s+', 'function global:'
    Invoke-Expression $text
    $loaded[$fn.Name] = $true
}

$missing = @($wanted | Where-Object { -not $loaded.ContainsKey($_) })
if ($missing.Count -gt 0) {
    throw ("Faltan funciones en MusicDL.bat: " + ($missing -join ', '))
}

# Vars mínimas que usan algunas funciones de carpeta / i18n / firma / args
$script:dirApp = Join-Path $env:TEMP 'MusicDL-tests'
$script:dirBin = Join-Path $script:dirApp 'bin'
Set-Variable -Name dirApp -Scope Global -Value $script:dirApp
Set-Variable -Name dirBin -Scope Global -Value $script:dirBin
if (-not $config) { $script:config = [ordered]@{ idioma = 'es' } }

$pubFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'clave-publica.xml'
if (Test-Path -LiteralPath $pubFile) {
    $script:clavePublicaXml = (Get-Content -LiteralPath $pubFile -Raw -Encoding UTF8).Trim()
    Set-Variable -Name clavePublicaXml -Scope Global -Value $script:clavePublicaXml
} else {
    throw "Falta clave-publica.xml en $(Split-Path $pubFile -Parent)"
}

# Stubs UI / PATH para Construir-Args (sin WinForms)
function global:Ruta-De([string]$cmd) { return $null }
function global:Fijar-Carpeta-UI([string]$ruta) { }
function global:Carpeta-UI-Actual {
    return (Normalizar-Carpeta-Destino (Carpeta-Destino-Por-Defecto))
}

$script:formatos = @('original', 'mp3', 'm4a', 'opus', 'flac', 'wav')
Set-Variable -Name formatos -Scope Global -Value $script:formatos
$script:reLimpiar = '(?i)\s*[\(\[][^\)\]]*\b(official|oficial|video)\b[^\)\]]*[\)\]]'
$script:reLimpiarCola = '(?i)\s*[|｜]\s*(official|video).*$'
Set-Variable -Name reLimpiar -Scope Global -Value $script:reLimpiar
Set-Variable -Name reLimpiarCola -Scope Global -Value $script:reLimpiarCola

if (-not $script:carpetaReal) {
    $script:carpetaReal = Carpeta-Destino-Por-Defecto
}

# Controles falsos (SelectedIndex / Checked) para Construir-Args
$global:cmbFormato = @{ SelectedIndex = 1 }
$global:cmbOrganizar = @{ SelectedIndex = 0 }
$global:chkLimpiar = @{ Checked = $false }
$global:chkPortada = @{ Checked = $false }
$global:chkSaltar = @{ Checked = $false }
