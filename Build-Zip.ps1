# Empaqueta MusicDL.zip reproducible (bat + sig + docs + clave pública).
# Uso: .\Build-Zip.ps1
param(
    [string]$Salida = (Join-Path $PSScriptRoot 'MusicDL.zip')
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$incluir = @(
    'MusicDL.bat',
    'MusicDL.bat.sig',
    'README.md',
    'LEEME.txt',
    'clave-publica.xml'
)

foreach ($n in $incluir) {
    $p = Join-Path $root $n
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Error "Falta archivo requerido: $n"
    }
}

if (Test-Path -LiteralPath $Salida) {
    Remove-Item -LiteralPath $Salida -Force
}

$staging = Join-Path $env:TEMP ('MusicDL-zip-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $staging | Out-Null
try {
    foreach ($n in $incluir) {
        Copy-Item -LiteralPath (Join-Path $root $n) -Destination (Join-Path $staging $n) -Force
    }
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $Salida -CompressionLevel Optimal
} finally {
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "ZIP creado: $Salida"
Write-Host "Contiene: $($incluir -join ', ')"
Write-Host "No incluye la clave privada ni Firmar-Version.ps1."
