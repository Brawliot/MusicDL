#region Utilidades
# ================================================================
#  Utilidades
# ================================================================
function Q($s) { '"' + ($s -replace '"', '\"') + '"' }


function Con-ErrorActionStop([scriptblock]$accion) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    try { return & $accion }
    finally { $ErrorActionPreference = $prev }
}
function Formato-Args-Informe($argsLista) {
    if ($null -eq $argsLista) { return '' }
    $parts = foreach ($a in @($argsLista)) {
        $s = [string]$a
        if ($s -match '[\s"]') { '"' + ($s -replace '"', '\"') + '"' } else { $s }
    }
    return ($parts -join ' ')
}


function Refrescar-Path {
    # Preferir siempre nuestras herramientas pinneadas en %APPDATA%\MusicDL\bin
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$dirBin;$m;$u"
}

function Ruta-De($cmd) {
    # Solo binarios instalados por MusicDL (URL+SHA256). No se usa PATH del sistema.
    $local = Join-Path $dirBin "$cmd.exe"
    if (-not (Test-Path -LiteralPath $local)) { return $null }
    $h = @($script:herramientas | Where-Object { $_.cmd -eq $cmd } | Select-Object -First 1)[0]
    if ($h) {
        $esperado = $null
        if ($h.tipo -eq 'exe' -and $h.sha256) { $esperado = [string]$h.sha256 }
        elseif ($h.sha256exe) { $esperado = [string]$h.sha256exe }
        if ($esperado -and -not (Verificar-Sha256 $local $esperado)) {
            Registrar-Error "Ruta-De: SHA256 inválido para $cmd en bin\; se ignora el archivo"
            return $null
        }
    }
    return $local
}

function Faltan { return @($script:herramientas | Where-Object { -not (Ruta-De $_.cmd) }) }

$script:ultimoBombeoUi = [datetime]::MinValue
$script:enBombeoUi = $false
function Bombeo-Ui([int]$minMs = 120) {
    # DoEvents con límite de frecuencia + anti-reentrancia (M6)
    if ($script:enBombeoUi) { return }
    $ahora = Get-Date
    if (($ahora - $script:ultimoBombeoUi).TotalMilliseconds -lt [double]$minMs) { return }
    $script:ultimoBombeoUi = $ahora
    $script:enBombeoUi = $true
    try {
        [System.Windows.Forms.Application]::DoEvents()
    } catch {
    } finally {
        $script:enBombeoUi = $false
    }
}

function Esperar-Proceso-Con-Timeout {
    param(
        $proc,
        [int]$timeoutSeg = 300,
        [scriptblock]$siCancelar = $null,
        [string]$contexto = 'Proceso'
    )
    if (-not $proc) { return 'ok' }
    $inicio = Get-Date
    while (-not $proc.HasExited) {
        $cancel = $false
        if ($siCancelar) {
            try { $cancel = [bool](& $siCancelar) } catch { $cancel = $false }
        }
        if ($cancel) {
            try { Start-Process taskkill -ArgumentList "/PID $($proc.Id) /T /F" -WindowStyle Hidden -Wait } catch { Catch-Log $contexto $_ }
            return 'cancelado'
        }
        if (((Get-Date) - $inicio).TotalSeconds -ge [double]$timeoutSeg) {
            try { Start-Process taskkill -ArgumentList "/PID $($proc.Id) /T /F" -WindowStyle Hidden -Wait } catch { Catch-Log $contexto $_ }
            Registrar-Error "${contexto}: timeout tras ${timeoutSeg}s"
            return 'timeout'
        }
        Bombeo-Ui 80
        Start-Sleep -Milliseconds 40
    }
    return 'ok'
}

function Verificar-Sha256($ruta, $esperado) {
    if (-not $esperado) { return $false }
    if (-not $ruta -or -not (Test-Path -LiteralPath $ruta)) { return $false }
    try {
        $real = (Get-FileHash -LiteralPath $ruta -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
        $want = ([string]$esperado).Trim().ToUpperInvariant()
        return ($real -eq $want)
    } catch {
        Registrar-Error "SHA256 $($ruta): $($_.Exception.Message)"
        return $false
    }
}

function Instalar-Spotdl {
    $h = $script:herramientas | Where-Object { $_.cmd -eq 'spotdl' } | Select-Object -First 1
    if (-not $h) { return $false }
    if (Test-Path -LiteralPath (Join-Path $dirBin 'spotdl.exe')) { return $true }
    return (Instalar-Herramienta-Directa $h)
}

function Preparar-Spotdl {
    if ($script:tarea -and $script:modo -eq $null) { Abandonar-Tarea; $lblAct.Text = '' }
    Refrescar-Path
    $s = Ruta-De 'spotdl'
    if ($s -and (Ruta-De 'ffmpeg') -and (Ruta-De 'deno')) { return $s }
    if (-not (Instalar-Si-Falta)) { return $null }
    Refrescar-Path
    $s = Ruta-De 'spotdl'
    if (-not $s) {
        Aviso "No se pudo instalar spotDL.`n`nComprueba internet y vuelve a abrir el programa." 'Warning'
    } elseif (-not (Ruta-De 'ffmpeg') -or -not (Ruta-De 'deno')) {
        Aviso "Faltan FFmpeg o Deno (necesarios para Spotify). Cierra y vuelve a abrir el programa." 'Warning'
        return $null
    }
    return $s
}

function Plural($n, $uno, $varios) { if ($n -eq 1) { "1 $uno" } else { "$n $varios" } }

function Escalar-Dpi($f) {
    $f.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $f.AutoScaleMode = 'Dpi'
}

function Hoy { (Get-Date).ToString('dd/MM/yyyy HH:mm') }

function Archivo-Historial($fmt) {
    return (Join-Path $dirApp ("ya-descargadas-$fmt.txt"))
}

# Enlaces: YouTube / SoundCloud / Spotify (descarga Spotify vía spotDL → YouTube)
function Es-Enlace-Spotify($e) {
    if (-not $e) { return $false }
    # (?i) = mayúsculas/minúsculas; admite /embed/, /user/.../playlist/, query ?si=
    if ($e -match '(?i)^https://open\.spotify\.com/') { return $true }
    if ($e -match '(?i)^https://(www\.)?spotify\.com/') { return $true }
    if ($e -match '(?i)^https://spotify\.link/') { return $true }
    return $false
}

function Tipo-Enlace($e) {
    if ($e -match '(?i)^https://(www\.)?(youtube\.com|youtu\.be|music\.youtube\.com)/') { return 'youtube' }
    if ($e -match '(?i)^https://(www\.|m\.)?soundcloud\.com/') { return 'soundcloud' }
    if (Es-Enlace-Spotify $e) { return 'spotify' }
    return 'desconocido'
}

function Es-Enlace-Valido($e) {
    if (-not $e) { return $false }
    if ($e -notmatch '^https://') { return $false }
    # Bloquear metacaracteres peligrosos; ? y & son normales en URLs (watch?v=...&list=...)
    if ($e -match '[\s\"''`|;<>\*\{\}\[\]\\]') { return $false }
    if ($e -match '[^\x20-\x7E]') { return $false }  # solo ASCII imprimible
    $t = Tipo-Enlace $e
    return ($t -ne 'desconocido')
}

function Parsear-Spotify($e) {
    # Devuelve @{ tipo = track|album|playlist|artist|corto; id = '...' } o $null
    if ($e -match '(?i)^https://spotify\.link/([a-zA-Z0-9]+)') {
        return @{ tipo = 'corto'; id = $matches[1] }
    }
    if ($e -match '(?i)^https://open\.spotify\.com/(?:intl-[a-z]{2}/)?(?:embed/)?(track|album|playlist|artist)/([a-zA-Z0-9]+)') {
        return @{ tipo = $matches[1].ToLower(); id = $matches[2] }
    }
    if ($e -match '(?i)^https://open\.spotify\.com/(?:intl-[a-z]{2}/)?user/[^/]+/(playlist)/([a-zA-Z0-9]+)') {
        return @{ tipo = 'playlist'; id = $matches[2] }
    }
    return $null
}

function Clave-Enlace($e) {
    if ($e -match '[?&]list=((?!RD)[^&]+)') { return 'lista:' + $matches[1] }
    if ($e -match '(?:youtu\.be/|[?&]v=|/shorts/)([\w-]{11})') { return 'yt:' + $matches[1] }
    if ($e -match 'soundcloud\.com/([^?#]+)') { return 'sc:' + $matches[1].TrimEnd('/').ToLower() }
    $sp = Parsear-Spotify $e
    if ($sp) { return "sp:$($sp.tipo):$($sp.id)" }
    return ($e -replace '[?#].*$', '').TrimEnd('/').ToLower()
}

function Quitar-Repetidos($lista) {
    $vistos = @{}
    foreach ($e in $lista) {
        $k = Clave-Enlace $e
        if (-not $vistos.ContainsKey($k)) { $vistos[$k] = $true; $e }
    }
}

function Arreglar-Enlace($e) {
    if ($e -match 'youtube\.com/watch' -and $e -match '[?&]list=RD') {
        $e = ($e -replace '[?&](list|start_radio|index)=[^&]*', '')
        if ($e -notmatch '\?') { $e = $e -replace '&', '?' }
    }
    return $e
}

function Parece-Lista($e) {
    if ($e -match '[?&]list=' -and $e -notmatch '[?&]list=RD') { return $true }
    if ($e -match 'youtube\.com/(playlist|channel|c/|@|user/)') { return $true }
    if ($e -match 'soundcloud\.com/.+/(sets|albums)/') { return $true }
    if ($e -match 'soundcloud\.com/[^/]+/?$' ) { return $true }  # perfil
    $sp = Parsear-Spotify $e
    if ($sp -and $sp.tipo -in @('album', 'playlist', 'artist', 'corto')) { return $true }
    return $false
}

function Verificar-Firma($bytes, $firmaB64) {
    try {
        $tmp = [System.Security.Cryptography.RSA]::Create()
        $tmp.FromXmlString($clavePublicaXml)
        $rp = $tmp.ExportParameters($false)
        $tmp.Dispose()
        $rsa = New-Object System.Security.Cryptography.RSACng
        $rsa.ImportParameters($rp)
        $firma = [Convert]::FromBase64String(($firmaB64 -replace '\s', ''))
        $sha = [System.Security.Cryptography.HashAlgorithmName]::SHA256
        # PSS (releases nuevas) y PKCS1 (transicion: lo que aun hay en GitHub raw)
        if ($rsa.VerifyData($bytes, $firma, $sha, [System.Security.Cryptography.RSASignaturePadding]::Pss)) { return $true }
        if ($rsa.VerifyData($bytes, $firma, $sha, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)) { return $true }
        return $false
    } catch {
        Registrar-Error "Verificar firma: $($_.Exception.Message)"
        return $false
    }
}

function Marcar-Arranque-Ok {
    Remove-Item -LiteralPath (Join-Path $dirApp 'esperando-arranque.flag') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $dirApp 'update-pending.flag') -Force -ErrorAction SilentlyContinue
}

# ---------- Icono ----------
function Crear-Icono {
    try {
        $bmp = New-Object System.Drawing.Bitmap 64, 64
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = 'AntiAlias'
        $g.TextRenderingHint = 'AntiAlias'
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush $colAcento), 2, 2, 60, 60)
        $f = New-Object System.Drawing.Font('Segoe UI Symbol', 34, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
        $g.DrawString([string][char]0x266B, $f, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 3, 64, 64)), $sf)
        $g.Dispose()
        $script:bmpIcono = $bmp
        $script:icono = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
        $ms = New-Object IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $png = $ms.ToArray()
        $out = New-Object IO.MemoryStream
        $w = New-Object IO.BinaryWriter($out)
        $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]1)
        $w.Write([byte]64); $w.Write([byte]64); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$png.Length); $w.Write([uint32]22)
        $w.Write($png); $w.Flush()
        [IO.File]::WriteAllBytes($archIcono, $out.ToArray())
    } catch { Registrar-Error "Icono: $($_.Exception.Message)" }
}
#endregion Utilidades

