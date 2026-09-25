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
    'Verificar-Sha256',
    'Es-Enlace-Spotify', 'Tipo-Enlace', 'Es-Enlace-Valido',
    'Es-Titulo-Comodin-Drm', 'Titulo-Desde-Url-Track', 'Titulo-Para-Busqueda-Drm'
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

# Vars mínimas que usan algunas funciones de carpeta
if (-not $dirApp) { $script:dirApp = Join-Path $env:TEMP 'MusicDL-tests' }
