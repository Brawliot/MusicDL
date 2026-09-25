# ================================================================
#  Ensambla / parte MusicDL.bat desde src/ (modulos por #region).
#  Distribucion sigue siendo UN solo MusicDL.bat firmado.
#
#  Uso:
#    .\Assemble-MusicDL.ps1 -Split     # bat -> src/*.ps1
#    .\Assemble-MusicDL.ps1           # src/*.ps1 -> MusicDL.bat
#    .\Assemble-MusicDL.ps1 -Check    # falla si bat != src
# ================================================================
param(
    [switch]$Split,
    [switch]$Check,
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$batPath = Join-Path $Root 'MusicDL.bat'
$srcDir = Join-Path $Root 'src'
$manifestName = 'modules.txt'

function Get-BatText {
    if (-not (Test-Path -LiteralPath $batPath)) { throw "No existe $batPath" }
    return [IO.File]::ReadAllText($batPath, [Text.Encoding]::UTF8)
}

function Write-Utf8Lf([string]$path, [string]$text) {
    $norm = $text -replace "`r`n", "`n" -replace "`r", "`n"
    if (-not $norm.EndsWith("`n")) { $norm += "`n" }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($path, $norm, $utf8)
}

function Split-BatToSrc {
    $text = Get-BatText
    if (Test-Path -LiteralPath $srcDir) {
        Remove-Item -LiteralPath $srcDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $srcDir | Out-Null

    $pattern = '(?m)^#region (\S+)\r?\n'
    $rxMatches = [regex]::Matches($text, $pattern)
    $modules = New-Object System.Collections.Generic.List[string]
    $order = New-Object System.Collections.Generic.List[string]

    if ($rxMatches.Count -eq 0) { throw 'No hay #region en MusicDL.bat' }

    $prologue = $text.Substring(0, $rxMatches[0].Index)
    $proPath = Join-Path $srcDir '00-prologue.ps1'
    Write-Utf8Lf $proPath $prologue
    $order.Add('00-prologue.ps1')

    for ($i = 0; $i -lt $rxMatches.Count; $i++) {
        $name = $rxMatches[$i].Groups[1].Value
        $start = $rxMatches[$i].Index
        $end = if ($i + 1 -lt $rxMatches.Count) { $rxMatches[$i + 1].Index } else { $text.Length }
        $chunk = $text.Substring($start, $end - $start)
        $safe = ($name -replace '[^A-Za-z0-9\-]', '-')
        $file = ('{0:D2}-{1}.ps1' -f ($i + 1), $safe)
        Write-Utf8Lf (Join-Path $srcDir $file) $chunk
        $order.Add($file)
        $modules.Add($name)
    }

    Write-Utf8Lf (Join-Path $srcDir $manifestName) (($order -join "`n") + "`n")
    Write-Host ("Split OK: {0} modulos en {1}" -f $order.Count, $srcDir)
    Write-Host ("Regiones: " + ($modules -join ', '))
}

function Get-ModuleOrder {
    $man = Join-Path $srcDir $manifestName
    if (-not (Test-Path -LiteralPath $man)) {
        throw "Falta $man. Ejecuta: .\Assemble-MusicDL.ps1 -Split"
    }
    return @(
        Get-Content -LiteralPath $man -Encoding UTF8 |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#') }
    )
}

function Assemble-FromSrc {
    $order = Get-ModuleOrder
    $sb = New-Object System.Text.StringBuilder
    foreach ($f in $order) {
        $p = Join-Path $srcDir $f
        if (-not (Test-Path -LiteralPath $p)) { throw "Falta modulo: $f" }
        $chunk = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
        $chunk = $chunk -replace "`r`n", "`n" -replace "`r", "`n"
        [void]$sb.Append($chunk)
        if (-not $chunk.EndsWith("`n")) { [void]$sb.Append("`n") }
    }
    return $sb.ToString()
}

function Write-AssembledBat([string]$assembled) {
    Write-Utf8Lf $batPath $assembled
    Write-Host ("Ensamblado: {0} ({1} chars)" -f $batPath, $assembled.Length)
}

if ($Split) {
    Split-BatToSrc
    exit 0
}

if (-not (Test-Path -LiteralPath $srcDir)) {
    throw "No existe $srcDir. Ejecuta: .\Assemble-MusicDL.ps1 -Split"
}

$assembled = Assemble-FromSrc

if ($Check) {
    $current = (Get-BatText) -replace "`r`n", "`n" -replace "`r", "`n"
    if (-not $current.EndsWith("`n")) { $current += "`n" }
    if ($current -ne $assembled) {
        throw 'MusicDL.bat no coincide con src/. Ejecuta .\Assemble-MusicDL.ps1 y vuelve a firmar.'
    }
    Write-Host 'Check OK: MusicDL.bat sincronizado con src/'
    exit 0
}

Write-AssembledBat $assembled
