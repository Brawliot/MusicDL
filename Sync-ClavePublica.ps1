# ================================================================
#  Sincroniza DM_PUB_B64 y $clavePublicaXml desde clave-publica.xml
#  (unica fuente de verdad — evita drift L2).
#  Uso: .\Sync-ClavePublica.ps1
#       .\Sync-ClavePublica.ps1 -Check   # falla si bat/src no coinciden
# ================================================================
param(
    [switch]$Check,
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$pubPath = Join-Path $Root 'clave-publica.xml'
$prologuePath = Join-Path $Root 'src\00-prologue.ps1'
$batPath = Join-Path $Root 'MusicDL.bat'

if (-not (Test-Path -LiteralPath $pubPath)) { throw "Falta $pubPath" }
$pub = (Get-Content -LiteralPath $pubPath -Raw -Encoding UTF8).Trim()
if ($pub -notmatch '^<RSAKeyValue>') { throw 'clave-publica.xml no parece RSA XML' }
if ($pub.Contains("'")) { throw 'clave-publica.xml no debe contener comillas simples' }

$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pub))

function Get-Fingerprint([string]$xml) {
    $rsa = [Security.Cryptography.RSA]::Create()
    $rsa.FromXmlString($xml)
    $mod = $rsa.ExportParameters($false).Modulus
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($mod)
        return ([BitConverter]::ToString($hash) -replace '-', '')
    } finally { $sha.Dispose(); $rsa.Dispose() }
}

function Test-Embeddings([string]$text, [string]$pubXml, [string]$b64Expect) {
    $mCmd = [regex]::Match($text, 'set "DM_PUB_B64=([^"]+)"')
    $mPs = [regex]::Match($text, '\$clavePublicaXml = ''([^'']+)''')
    if (-not $mCmd.Success -or -not $mPs.Success) { return $false }
    if ($mCmd.Groups[1].Value -ne $b64Expect) { return $false }
    $fromPs = ($mPs.Groups[1].Value -replace '\s', '')
    $want = ($pubXml -replace '\s', '')
    return ($fromPs -eq $want)
}

function Apply-ToText([string]$text) {
    $t = [regex]::Replace($text, 'set "DM_PUB_B64=[^"]+"', ('set "DM_PUB_B64=' + $b64 + '"'))
    $t = [regex]::Replace($t, '\$clavePublicaXml = ''[^'']*''', ('$clavePublicaXml = ''' + $pub + ''''))
    return $t
}

$fp = Get-Fingerprint $pub
Write-Host ("Fingerprint SHA256(modulus): " + $fp.Substring(0, 16) + "...")

if ($Check) {
    $ok = $true
    if (Test-Path -LiteralPath $prologuePath) {
        $pro = [IO.File]::ReadAllText($prologuePath, [Text.Encoding]::UTF8)
        if (-not (Test-Embeddings $pro $pub $b64)) {
            Write-Host 'FAIL: src/00-prologue.ps1 desincronizado'
            $ok = $false
        }
    }
    if (Test-Path -LiteralPath $batPath) {
        $bat = [IO.File]::ReadAllText($batPath, [Text.Encoding]::UTF8)
        if (-not (Test-Embeddings $bat $pub $b64)) {
            Write-Host 'FAIL: MusicDL.bat desincronizado'
            $ok = $false
        }
    }
    if (-not $ok) { throw 'Clave publica embebida != clave-publica.xml. Ejecuta .\Sync-ClavePublica.ps1' }
    Write-Host 'Check OK: embeddings = clave-publica.xml'
    exit 0
}

$utf8 = New-Object System.Text.UTF8Encoding $false
if (Test-Path -LiteralPath $prologuePath) {
    $pro = [IO.File]::ReadAllText($prologuePath, [Text.Encoding]::UTF8)
    $pro2 = Apply-ToText $pro
    $pro2 = $pro2 -replace "`r`n", "`n" -replace "`r", "`n"
    if (-not $pro2.EndsWith("`n")) { $pro2 += "`n" }
    [IO.File]::WriteAllText($prologuePath, $pro2, $utf8)
    Write-Host "Actualizado: $prologuePath"
}

$assemble = Join-Path $Root 'Assemble-MusicDL.ps1'
if (Test-Path -LiteralPath $assemble) {
    & $assemble
} elseif (Test-Path -LiteralPath $batPath) {
    $bat = [IO.File]::ReadAllText($batPath, [Text.Encoding]::UTF8)
    $bat2 = Apply-ToText $bat
    $bat2 = $bat2 -replace "`r`n", "`n" -replace "`r", "`n"
    if (-not $bat2.EndsWith("`n")) { $bat2 += "`n" }
    [IO.File]::WriteAllText($batPath, $bat2, $utf8)
    Write-Host "Actualizado: $batPath"
}

Write-Host 'Sync OK (clave-publica.xml -> embeddings + assemble)'
