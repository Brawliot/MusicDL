# ================================================================
#  Firmar una version de "MusicDL.bat" (RSA-PSS + SHA256)
#  Uso:  .\Firmar-Version.ps1
#        .\Firmar-Version.ps1 -Force          # sin prompt (CI/local automatizado)
#        $env:MUSICDL_SIGNING_KEY = 'D:\ruta\clave-privada.xml'
#
#  CHECKLIST (antes de firmar / publicar):
#  1. Clave SOLO en %USERPROFILE%\.secrets\MusicDL\ (o MUSICDL_SIGNING_KEY).
#  2. NUNCA en el repo, USB compartido, chat, correo ni capturas.
#  3. Backup offline cifrado de la privada (fuera de este PC si puedes).
#  4. MusicDL.bat en LF; fuente de verdad publica: clave-publica.xml.
#  5. Tras firmar: sube SOLO MusicDL.bat + MusicDL.bat.sig (+ docs).
#  6. Si sospechas filtracion: deja de firmar, rota la clave (nueva
#     clave-publica.xml + Sync-ClavePublica.ps1 + release) y revoca la antigua.
#
#  ACL recomendada (una vez):
#    icacls "%USERPROFILE%\.secrets\MusicDL" /inheritance:r
#    icacls "%USERPROFILE%\.secrets\MusicDL\clave-privada.xml" /grant:r "%USERNAME%:R"
# ================================================================
param(
    [string]$Archivo = (Join-Path $PSScriptRoot 'MusicDL.bat'),
    [string]$ClavePrivada = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Pad = [Security.Cryptography.RSASignaturePadding]::Pss
$Hash = [Security.Cryptography.HashAlgorithmName]::SHA256

function Resolver-ClavePrivada([string]$explicita) {
    if ($explicita) { return $explicita }
    if ($env:MUSICDL_SIGNING_KEY) { return $env:MUSICDL_SIGNING_KEY }
    return (Join-Path $env:USERPROFILE '.secrets\MusicDL\clave-privada.xml')
}

function Normalizar-XmlClave([string]$xml) {
    return (($xml -replace '\s+', '')).Trim()
}

function Get-KeyFingerprint([string]$xml) {
    $rsa = [Security.Cryptography.RSA]::Create()
    try {
        $rsa.FromXmlString($xml)
        $mod = $rsa.ExportParameters($false).Modulus
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha.ComputeHash($mod)) -replace '-', '')
        } finally { $sha.Dispose() }
    } finally { $rsa.Dispose() }
}

function Extraer-ClavePublicaDelBat([string]$batText) {
    $mCmd = [regex]::Match($batText, 'set "DM_PUB_B64=([^"]+)"')
    if (-not $mCmd.Success) { throw 'MusicDL.bat: no encuentro DM_PUB_B64' }
    $fromCmd = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($mCmd.Groups[1].Value))
    $mPs = [regex]::Match($batText, '\$clavePublicaXml = ''([^'']+)''')
    if (-not $mPs.Success) { throw 'MusicDL.bat: no encuentro $clavePublicaXml' }
    return @{ Cmd = $fromCmd; Ps = $mPs.Groups[1].Value }
}

# L2: embeddings desde clave-publica.xml
$sync = Join-Path $PSScriptRoot 'Sync-ClavePublica.ps1'
if (Test-Path -LiteralPath $sync) {
    & $sync
}

$assemble = Join-Path $PSScriptRoot 'Assemble-MusicDL.ps1'
if (Test-Path -LiteralPath $assemble) {
    & $assemble -Check
}
if (Test-Path -LiteralPath $sync) {
    & $sync -Check
}

$ClavePrivada = Resolver-ClavePrivada $ClavePrivada
$enRepo = Join-Path $PSScriptRoot 'clave-privada.xml'
$pubPath = Join-Path $PSScriptRoot 'clave-publica.xml'
$secretsRoot = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE '.secrets\MusicDL'))

if (-not (Test-Path -LiteralPath $Archivo)) {
    Write-Error "No encuentro el archivo: $Archivo"
}
if (-not (Test-Path -LiteralPath $pubPath)) {
    Write-Error "Falta clave-publica.xml en el repo: $pubPath"
}
if (-not (Test-Path -LiteralPath $ClavePrivada)) {
    Write-Error @"
No encuentro la clave privada: $ClavePrivada

Colocala fuera del repo, por ejemplo:
  $($env:USERPROFILE)\.secrets\MusicDL\clave-privada.xml
O define MUSICDL_SIGNING_KEY con la ruta completa.
"@
}

$claveFull = [IO.Path]::GetFullPath($ClavePrivada)
$repoFull = [IO.Path]::GetFullPath($PSScriptRoot)

if ($claveFull.StartsWith($repoFull, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Error @"
RECHAZADO: la clave privada esta DENTRO del repo ($claveFull).
Muevela a %USERPROFILE%\.secrets\MusicDL\ y borra cualquier copia del proyecto.
"@
}
if (Test-Path -LiteralPath $enRepo) {
    Write-Error "RECHAZADO: existe $enRepo. Borralo del disco (y del historial git si alguna vez se subio)."
}
if (-not $claveFull.StartsWith($secretsRoot, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Warning "La clave no esta bajo $secretsRoot. Usa esa ruta o MUSICDL_SIGNING_KEY solo si es un almacen igual de restringido."
}

$batText = [IO.File]::ReadAllText($Archivo, [Text.Encoding]::UTF8)
$pubs = Extraer-ClavePublicaDelBat $batText
$pubFile = (Get-Content -LiteralPath $pubPath -Raw -Encoding UTF8).Trim()
$nCmd = Normalizar-XmlClave $pubs.Cmd
$nPs = Normalizar-XmlClave $pubs.Ps
$nFile = Normalizar-XmlClave $pubFile
if ($nCmd -ne $nFile -or $nPs -ne $nFile) {
    Write-Error 'Las claves publicas no coinciden tras Sync. Revisa Sync-ClavePublica.ps1.'
}

$fp = Get-KeyFingerprint $pubFile
$ver = 'unknown'
if ($batText -match "(?m)^\`$versionApp = '([^']+)'") { $ver = $Matches[1] }

Write-Host ""
Write-Host "=== Firma MusicDL (RSA-PSS) ==="
Write-Host "Archivo : $Archivo"
Write-Host "Version : $ver"
Write-Host "Clave   : $ClavePrivada"
Write-Host "FP pub  : $($fp.Substring(0, 32))..."
Write-Host "Padding : PSS + SHA256"
Write-Host ""

$auto = $Force -or ($env:MUSICDL_SIGN_OK -eq '1')
if (-not $auto) {
    $ans = Read-Host "Escribe FIRMAR para continuar (o usa -Force)"
    if ($ans -ne 'FIRMAR') {
        Write-Error 'Firma cancelada.'
    }
}

$bytes = [IO.File]::ReadAllBytes($Archivo)
function New-RsaCngFromXml([string]$xml, [bool]$conPrivada) {
    $tmp = [System.Security.Cryptography.RSA]::Create()
    try {
        $tmp.FromXmlString($xml)
        $p = $tmp.ExportParameters($conPrivada)
    } finally { $tmp.Dispose() }
    $rsa = New-Object System.Security.Cryptography.RSACng
    $rsa.ImportParameters($p)
    return $rsa
}

$rsa = New-RsaCngFromXml ((Get-Content -LiteralPath $ClavePrivada -Raw -Encoding UTF8)) $true
$rsaPub = New-RsaCngFromXml $pubFile $false
$modPriv = [Convert]::ToBase64String($rsa.ExportParameters($false).Modulus)
$modPub = [Convert]::ToBase64String($rsaPub.ExportParameters($false).Modulus)
if ($modPriv -ne $modPub) {
    Write-Error 'La clave privada NO corresponde a clave-publica.xml. No se firma.'
}

$firma = $rsa.SignData($bytes, $Hash, $Pad)
$rutaSig = $Archivo + '.sig'
$firmaB64 = [Convert]::ToBase64String($firma)
[IO.File]::WriteAllText($rutaSig, $firmaB64, [Text.Encoding]::ASCII)

if (-not $rsaPub.VerifyData($bytes, $firma, $Hash, $Pad)) {
    Remove-Item -LiteralPath $rutaSig -Force -ErrorAction SilentlyContinue
    Write-Error 'La firma recien creada no verifica (PSS). No se deja el .sig.'
}

# H2: registro local de firmas (fuera del repo)
$logDir = Join-Path $env:USERPROFILE '.secrets\MusicDL'
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}
$logLine = '{0:o} version={1} file={2} fp={3} pad=PSS sha256={4}' -f (Get-Date), $ver, $Archivo, $fp, (Get-FileHash -LiteralPath $Archivo -Algorithm SHA256).Hash
Add-Content -LiteralPath (Join-Path $logDir 'firmas.log') -Value $logLine -Encoding UTF8

Write-Host "Firma creada: $rutaSig"
Write-Host "Registro: $logDir\firmas.log"
Write-Host "Sube a GitHub el .bat y el .sig. NO subas la clave privada."
