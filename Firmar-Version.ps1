# ================================================================
#  Firmar una versión de "MusicDL.bat"
#  Uso:  .\Firmar-Version.ps1
#        .\Firmar-Version.ps1 -Archivo ".\MusicDL.bat"
#
#  IMPORTANTE: Nunca compartas ni subas a GitHub "clave-privada.xml".
#  Solo sube el .bat y el archivo .sig generado.
# ================================================================
param(
    [string]$Archivo = (Join-Path $PSScriptRoot 'MusicDL.bat'),
    [string]$ClavePrivada = (Join-Path $PSScriptRoot 'clave-privada.xml')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Archivo)) {
    Write-Error "No encuentro el archivo: $Archivo"
}
if (-not (Test-Path -LiteralPath $ClavePrivada)) {
    Write-Error "No encuentro la clave privada: $ClavePrivada"
}

$bytes = [IO.File]::ReadAllBytes($Archivo)
$rsa = [System.Security.Cryptography.RSA]::Create()
$rsa.FromXmlString((Get-Content -LiteralPath $ClavePrivada -Raw -Encoding UTF8))
$firma = $rsa.SignData($bytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
$rutaSig = $Archivo + '.sig'
[IO.File]::WriteAllText($rutaSig, [Convert]::ToBase64String($firma), [Text.Encoding]::ASCII)
Write-Host "Firma creada: $rutaSig"
Write-Host "Sube a GitHub el .bat y el .sig (mismo nombre + .sig)."
Write-Host "NO subas clave-privada.xml"
