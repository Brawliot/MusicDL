# ================================================================
#  Firmar una versión de "MusicDL.bat"
#  Uso:  .\Firmar-Version.ps1
#        .\Firmar-Version.ps1 -Archivo ".\MusicDL.bat"
#        $env:MUSICDL_SIGNING_KEY = 'D:\ruta\clave-privada.xml'
#        .\Firmar-Version.ps1
#
#  La clave privada NO debe estar en esta carpeta del repo.
#  Ubicación por defecto (fuera del proyecto):
#    %USERPROFILE%\.secrets\MusicDL\clave-privada.xml
#  O variable de entorno MUSICDL_SIGNING_KEY.
#
#  IMPORTANTE: Nunca compartas ni subas a GitHub la clave privada.
#  Solo sube el .bat y el archivo .sig generado.
# ================================================================
param(
    [string]$Archivo = (Join-Path $PSScriptRoot 'MusicDL.bat'),
    [string]$ClavePrivada = ''
)

$ErrorActionPreference = 'Stop'

function Resolver-ClavePrivada([string]$explicita) {
    if ($explicita) { return $explicita }
    if ($env:MUSICDL_SIGNING_KEY) { return $env:MUSICDL_SIGNING_KEY }
    return (Join-Path $env:USERPROFILE '.secrets\MusicDL\clave-privada.xml')
}

$ClavePrivada = Resolver-ClavePrivada $ClavePrivada
$enRepo = Join-Path $PSScriptRoot 'clave-privada.xml'

if (-not (Test-Path -LiteralPath $Archivo)) {
    Write-Error "No encuentro el archivo: $Archivo"
}
if (-not (Test-Path -LiteralPath $ClavePrivada)) {
    Write-Error @"
No encuentro la clave privada: $ClavePrivada

Colócala fuera del repo, por ejemplo:
  $($env:USERPROFILE)\.secrets\MusicDL\clave-privada.xml
O define la variable de entorno MUSICDL_SIGNING_KEY con la ruta completa.
"@
}
if ((Test-Path -LiteralPath $enRepo) -and (
        [IO.Path]::GetFullPath($ClavePrivada) -ne [IO.Path]::GetFullPath($enRepo)
    )) {
    Write-Warning "Hay un clave-privada.xml dentro del repo. Bórralo; la firma usará: $ClavePrivada"
}
if ([IO.Path]::GetFullPath($ClavePrivada) -eq [IO.Path]::GetFullPath($enRepo)) {
    Write-Warning "Estás firmando con una clave DENTRO del repo. Muévela a %USERPROFILE%\.secrets\MusicDL\"
}

$bytes = [IO.File]::ReadAllBytes($Archivo)
$rsa = [System.Security.Cryptography.RSA]::Create()
$rsa.FromXmlString((Get-Content -LiteralPath $ClavePrivada -Raw -Encoding UTF8))
$firma = $rsa.SignData($bytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
$rutaSig = $Archivo + '.sig'
[IO.File]::WriteAllText($rutaSig, [Convert]::ToBase64String($firma), [Text.Encoding]::ASCII)
Write-Host "Firma creada: $rutaSig"
Write-Host "Clave usada: $ClavePrivada"
Write-Host "Sube a GitHub el .bat y el .sig (mismo nombre + .sig)."
Write-Host "NO subas la clave privada."
