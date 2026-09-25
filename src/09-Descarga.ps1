#region Descarga
# ================================================================
#  Descarga
# ================================================================
function Traducir-Error($l) {
    $web = if ($l -match '\[youtube') { 'YouTube' } elseif ($l -match '\[soundcloud') { 'SoundCloud' } else { 'La web' }
    switch -Regex ($l) {
        'Unsupported URL|is not a valid URL|no suitable extractor' {
            return @{ origen = 'El enlace'; texto = 'No es de una canción ni de una lista de YouTube, SoundCloud o Spotify.' } }
        'getaddrinfo|Failed to resolve|timed out|Connection refused|No route to host|Network is unreachable|Connection reset|RemoteDisconnected' {
            return @{ origen = 'Tu conexión'; texto = 'No hay internet o va muy lenta. Comprueba la conexión y vuelve a intentarlo.' } }
        'DRM protected|DRM-protected' {
            return @{ origen = $web; texto = 'Está protegida contra copia (DRM). Al terminar se preguntará si buscarla en YouTube.' } }
        'Private video|This video is private|Video unavailable|not available|has been removed|HTTP Error 404' {
            return @{ origen = $web; texto = 'La canción no está disponible o es privada.' } }
        'not a bot|Sign in to confirm|HTTP Error 429|Too Many Requests' {
            return @{ origen = $web; texto = 'Ha bloqueado las descargas por un rato. Espera unos minutos y vuelve a intentarlo.' } }
        'age-restricted|confirm your age|inappropriate' {
            return @{ origen = $web; texto = 'La canción tiene restricción de edad y no se puede descargar.' } }
        'ffmpeg not found|ffprobe not found|Postprocessing|Permission denied|No space left|WinError' {
            return @{ origen = 'El programa'; texto = 'Fallo al guardar o convertir la canción. Cierra y vuelve a abrir el programa.' } }
        'HTTP Error 403|Unable to extract|nsig|Signature|Requested format|JavaScript|jsc' {
            return @{ origen = "$web (ha cambiado algo)"; texto = 'Cierra el programa y vuelve a abrirlo: se actualizará solo.' } }
        default {
            return @{ origen = 'Desconocido'; texto = 'Error no reconocido. Menú → Ver detalles técnicos.' } }
    }
}

function Poner-Barra($pctCancion = 0) {
    $d = $script:dl
    if (-not $d) { return }
    $total = [Math]::Max([int]$d.total, 1)
    $hechos = [int]$d.nuevas + [int]$d.saltadas + [int]$d.nErrores + [int]$d.drmMarcados
    if ($total -gt 1) {
        # Canción actual: la siguiente a las ya hechas, o el índice de playlist si existe
        $idx = [int]$d.actual
        if ($idx -lt 1) { $idx = $hechos + 1 }
        if ($idx -gt $total) { $idx = $total }
        $v = (($idx - 1) + ([double]$pctCancion / 100.0)) / $total
        # No retroceder respecto a canciones ya cerradas
        $minV = $hechos / $total
        if ($v -lt $minV) { $v = $minV }
    } else {
        $v = [double]$pctCancion / 100.0
    }
    if ($v -gt 1) { $v = 1 }
    if ($v -lt 0) { $v = 0 }
    $valor = [int]($v * 1000)
    Set-BarraValor $barra $valor
    Set-BarraValor $barraMini $valor
    Barra-Tarea 2 $valor
}

function Poner-Barra-Canciones {
    $d = $script:dl
    if (-not $d) { return }
    $total = [Math]::Max([int]$d.total, 1)
    $hechos = [int]$d.nuevas + [int]$d.saltadas + [int]$d.nErrores + [int]$d.drmMarcados
    $v = [Math]::Min($hechos / $total, 1.0)
    $valor = [int]($v * 1000)
    Set-BarraValor $barra $valor
    Set-BarraValor $barraMini $valor
    Barra-Tarea 2 $valor
}

function Marcar-Completado($ruta) {
    $d = $script:dl
    if (-not $d -or -not $ruta) { return }
    $ruta = $ruta.Trim().Trim('"')
    if ($d.yaEstaba) { $d.yaEstaba = $false; return }
    if (-not $d.completados) { $d.completados = New-Object System.Collections.Generic.List[string] }
    if ($d.completados -contains $ruta) { return }
    [void]$d.completados.Add($ruta)
    $d.enCurso = $null
    try { $script:ultimaCarpetaReal = Split-Path -Parent $ruta } catch { Catch-Log 'Marcar-Completado' $_ }
    if (-not $d.saltandoDrm) {
        try {
            $parent = Split-Path -Parent $ruta
            if ($parent) { $d.carpetaLista = $parent }
        } catch { Catch-Log 'Marcar-Completado' $_ }
    }
    $d.nuevas++
    if ($d.listaActual) { $d.nuevasPorLista[$d.listaActual] = 1 + [int]$d.nuevasPorLista[$d.listaActual] }
    $nombre = [IO.Path]::GetFileNameWithoutExtension($ruta)
    $extra = if ($d.calidad) { "  [$($d.calidad)]" } else { '' }
    $tag = if ($d.saltandoDrm) { '  [DRM→YouTube]' }
           elseif ($d.motor -eq 'spotify-yt' -or $d.motor -eq 'spotdl') { '  [Spotify→YT]' }
           else { '' }
    Resultado ([string][char]0x2713 + '  ' + $nombre + $extra + $tag)
    Estado "Guardado:`n$nombre"
    $d.actual = [Math]::Max([int]$d.actual, [int]$d.nuevas + [int]$d.saltadas + [int]$d.nErrores)
    Poner-Barra-Canciones
}

function Es-Titulo-Comodin-Drm($t) {
    return ([string]$t -match '(?i)^Canci[oó]n\s+\d+\s+de\s+\d+$')
}

function Titulo-Desde-Url-Track($url) {
    if (-not $url) { return '' }
    # soundcloud.com/artista/tema (no sets/albums/api)
    if ($url -match '(?i)soundcloud\.com/([^/?#]+)/([^/?#]+)') {
        $a = $matches[1]; $b = $matches[2]
        if ($a -in @('you', 'discover', 'stream', 'search') ) { return '' }
        if ($b -in @('sets', 'albums', 'likes', 'tracks', 'popular-tracks', 'comments')) { return '' }
        $a = ($a -replace '-', ' ').Trim()
        $b = ($b -replace '-', ' ').Trim()
        if ($a -and $b) { return "$a $b" }
    }
    if ($url -match '(?i)youtube\.com/watch\?.*?v=([\w-]{11})' -or $url -match '(?i)youtu\.be/([\w-]{11})') {
        return ''  # sin título en la URL; se usa el de metadata
    }
    return ''
}

function Titulo-Para-Busqueda-Drm($d) {
    if ($d.titulo -and -not (Es-Titulo-Comodin-Drm $d.titulo)) { return ([string]$d.titulo).Trim() }
    if ($d.tituloDesdeUrl) { return ([string]$d.tituloDesdeUrl).Trim() }
    return ''
}

function Procesar-Linea($l) {
    $d = $script:dl
    if (-not $l) { return }
    # Título temprano (antes del DRM / descarga) vía --print before_dl
    if ($l -match '^\[DMTITLE\](.*)$') {
        $t = $matches[1].Trim()
        if ($t -and $t -ne 'NA' -and $t -ne 'None') {
            $d.titulo = $t
            if ($t -match '^(.*?)\s+/\s+(.*)$') {
                # formato "titulo / uploader" opcional
                $tit = $matches[1].Trim(); $up = $matches[2].Trim()
                if ($tit) { $d.titulo = $tit }
                if ($up -and -not $d.tituloDesdeUrl) { $d.tituloDesdeUrl = "$up $tit".Trim() }
            }
        }
        return
    }
    # Plantilla propia [DM]pct|idx|tot|titulo
    if ($l -match '^\[DM\](.*?)\|(.*?)\|(.*?)\|(.*)$') {
        $gPct = $matches[1]; $gIdx = $matches[2]; $gTot = $matches[3]; $gTit = $matches[4]
        $pct = 0.0
        [void][double]::TryParse(($gPct -replace '[^\d\.]', ''), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$pct)
        if ($gIdx -match '^\d+$' -and $gTot -match '^\d+$' -and [int]$gTot -gt 0) {
            $d.actual = [int]$gIdx
            $d.total = [Math]::Max([int]$d.total, [int]$gTot)
        }
        if ($gTit -and $gTit -ne 'NA' -and $gTit -ne 'None' -and -not (Es-Titulo-Comodin-Drm $gTit)) { $d.titulo = $gTit }
        Poner-Barra $pct
        $cual = if ($d.total -gt 1) { "canción $($d.actual) de $($d.total)" } else { 'canción' }
        Estado ("Descargando {0} ({1:0}%):`n{2}" -f $cual, $pct, $d.titulo)
        return
    }
    # Fallback: línea normal de yt-dlp "[download]  45.2%"
    if ($l -match '^\[download\]\s+(\d{1,3}(?:\.\d+)?)%') {
        $pct = [double]$matches[1]
        Poner-Barra $pct
        if ($d.titulo) {
            $cual = if ($d.total -gt 1) { "canción $($d.actual) de $($d.total)" } else { 'canción' }
            Estado ("Descargando {0} ({1:0}%):`n{2}" -f $cual, $pct, $d.titulo)
        }
        return
    }
    if ($l -match 'Downloading format (\d+)[^\]]*?(?:audio only)?.*?(\d+k?|~\d+k)') {
        $d.calidad = $matches[2]
        $lblCalidad.Text = "Calidad real de la fuente: $($d.calidad)"
        return
    }
    if ($l -match '\[info\].*?(\d{2,4}k)\b' -or $l -match 'abr[^\d]*(\d{2,4})') {
        if (-not $d.calidad) {
            $d.calidad = $matches[1]
            if ($d.calidad -notmatch 'k$') { $d.calidad = $d.calidad + 'k' }
            $lblCalidad.Text = "Calidad real de la fuente: ~$($d.calidad) (YouTube/SoundCloud no dan más)"
        }
        return
    }
    if ($l -match '^\[[\w:]+\] Extracting URL: (\S+)') {
        $u = $matches[1]
        $d.urlActual = $u
        $desdeUrl = Titulo-Desde-Url-Track $u
        if ($desdeUrl) { $d.tituloDesdeUrl = $desdeUrl }
        if ($d.porUrl.ContainsKey($u)) { $d.listaActual = $u }
        if ($d.total -gt 1) {
            $d.indiceUrl = 1 + [int]$d.indiceUrl
            $d.actual = [Math]::Min([int]$d.indiceUrl, [int]$d.total)
            Poner-Barra 0
        }
        return
    }
    if ($l -match '^\[download\] Downloading playlist: (.+)$') {
        $nombreLista = $matches[1].Trim()
        Resultado ([string][char]0x25B8 + '  Lista: ' + $nombreLista)
        if ($d.listaActual) { $d.porUrl[$d.listaActual].nombre = $nombreLista }
        if ($nombreLista) { $d.nombreLista = $nombreLista }
        return
    }
    if ($l -match 'Downloading (?:item|video) (\d+) of (\d+)') {
        $d.actual = [int]$matches[1]; $d.total = [Math]::Max([int]$d.total, [int]$matches[2])
        # Nuevo ítem: limpiar título; el comodín "Canción N de M" ya no se usa para buscar en YT
        $d.yaEstaba = $false; $d.titulo = ''; $d.tituloDesdeUrl = ''; $d.urlActual = $null; $d.calidad = $null
        $lblCalidad.Text = ''
        Poner-Barra 0
        return
    }
    if ($l -match '^\[download\] .+ has already been downloaded') {
        $d.yaEstaba = $true; $d.saltadas++
        Resultado ('–  Ya estaba en la carpeta: ' + $d.titulo)
        Poner-Barra-Canciones
        return
    }
    # En curso (aún no terminado)
    if ($l -match '^\[download\] Destination: (.+)$' -or $l -match '\[Merger\] Merging formats into "(.+)"') {
        $d.enCurso = $matches[1].Trim().Trim('"')
        try { $script:ultimaCarpetaReal = Split-Path -Parent $d.enCurso } catch { Catch-Log 'Procesar-Linea' $_ }
        return
    }
    # Terminado de verdad (convertido o ya en formato final)
    if ($l -match '^\[ExtractAudio\] Destination: (.+)$' -or $l -match '^\[ExtractAudio\] Not converting audio (.+?);') {
        Marcar-Completado $matches[1]
        return
    }
    if ($l -match '^\[download\] 100% of .+ in ') {
        if ($d.formato -eq 'original' -and $d.enCurso) { Marcar-Completado $d.enCurso }
        else { Poner-Barra 100 }
        return
    }
    if ($l -match '^Deleting original file') { $d.enCurso = $null; return }
    if ($l -match 'has already been recorded in the archive') {
        if ($l -match '^\[download\] (\S+): has already') { [void]$d.idsSaltados.Add($matches[1]) }
        $d.saltadas++
        Resultado ('–  Ya la tenías en este formato, se ha saltado')
        Poner-Barra-Canciones
        return
    }
    if ($l -match '^ERROR:') {
        if ($l -match 'HTTP Error 403|Unable to extract|nsig|Signature|Requested format|JavaScript|jsc') {
            $script:sugerirUpdateYtdlp = $true
        }
        # DRM: encolar búsqueda en YouTube (o marcar fallo si ya estamos en el salto)
        if ($l -match '(?i)DRM protected|DRM-protected') {
            if ($d.saltandoDrm) {
                $d.drmFallbackFallo = $true
                return
            }
            $quien = Titulo-Para-Busqueda-Drm $d
            $etiqueta = if ($quien) { $quien } elseif ($d.total -gt 1) { "Canción $($d.actual) de $($d.total)" } else { '' }
            if (-not $quien) {
                $d.nErrores++
                $lineaErr = if ($etiqueta) {
                    "$etiqueta — Tiene DRM y no pude saber el título real para buscarla en YouTube."
                } else {
                    'Canción con DRM — no pude leer el título para buscarla en YouTube.'
                }
                Resultado ([string][char]0x2717 + '  ' + $lineaErr)
                if (-not $d.errores.Contains($lineaErr)) { [void]$d.errores.Add($lineaErr) }
                Poner-Barra-Canciones
                return
            }
            if (-not $d.drmPendientes) { $d.drmPendientes = New-Object System.Collections.ArrayList }
            $ya = $false
            foreach ($p in @($d.drmPendientes)) {
                if ([string]$p.titulo -eq $quien) { $ya = $true; break }
            }
            if (-not $ya) {
                [void]$d.drmPendientes.Add(@{ titulo = $quien })
                $d.drmMarcados = 1 + [int]$d.drmMarcados
                Resultado ([string][char]0x2298 + '  DRM: ' + $quien + ' — al terminar te preguntaré si buscarla en YouTube')
                Estado ("DRM detectado. Al terminar te preguntaré:`n{0}" -f $quien)
            }
            Poner-Barra-Canciones
            return
        }
        if ($d.saltandoDrm) {
            # 403/red: no marcar como "otra vez DRM"; deja que el resultado lo decida nuevas/saltadas
            if ($l -match '(?i)DRM protected|DRM-protected') { $d.drmFallbackFallo = $true }
            elseif ($l -match '(?i)HTTP Error 403|Unable to extract|nsig|Sign in to confirm') {
                $d.drmFallbackFallo = $true
            }
            return
        }
        $err = Traducir-Error $l
        $txt = "$($err.origen): $($err.texto)"
        $d.nErrores++
        $quien = Titulo-Para-Busqueda-Drm $d
        if (-not $quien) { $quien = if ($d.total -gt 1) { "Canción $($d.actual) de $($d.total)" } else { 'Canción sin título' } }
        $lineaErr = "$quien — $txt"
        Resultado ([string][char]0x2717 + '  ' + $lineaErr)
        if (-not $d.errores.Contains($lineaErr)) { [void]$d.errores.Add($lineaErr) }
        if ($d.total -gt 1) {
            Estado ("Falló una canción; continúo con el resto...`n{0}" -f $quien)
        }
        Poner-Barra-Canciones
    }
}

$reLimpiar = '(?i)\s*[\(\[][^\)\]]*\b(official|oficial|videoclip|video|vídeo|audio|lyrics?|letra|visuali[sz]er|hd|hq|4k|mv)\b[^\)\]]*[\)\]]'
$reLimpiarCola = '(?i)\s*[|｜]\s*(official|oficial|video|vídeo|audio|lyrics?|letra).*$'

function Leer-Enlaces {
    return @(Quitar-Repetidos @($txtEnlace.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }))
}

function Comprobar-Enlaces($enlaces) {
    if ($enlaces.Count -eq 0) {
        Estado 'Primero pega un enlace de YouTube, SoundCloud o Spotify.'
        $txtEnlace.Focus()
        return $false
    }
    foreach ($e in $enlaces) {
        if (-not (Es-Enlace-Valido $e)) {
            Aviso "Enlace no válido o no permitido:`n`n$e`n`nSolo se aceptan enlaces https:// de YouTube, SoundCloud o Spotify, sin caracteres raros." 'Warning'
            return $false
        }
    }
    return $true
}

function Preparar-Ytdlp {
    if ($script:tarea -and $script:modo -eq $null) { Abandonar-Tarea; $lblAct.Text = '' }
    Refrescar-Path
    $ytdlp = Ruta-De 'yt-dlp'
    if (-not $ytdlp -or -not (Ruta-De 'ffmpeg')) {
        if (-not (Instalar-Si-Falta)) { return $null }
        Refrescar-Path
        $ytdlp = Ruta-De 'yt-dlp'
    }
    if (-not $ytdlp) { Aviso 'Falta el descargador. Cierra el programa y vuelve a abrirlo para que se instale.' 'Warning' }
    return $ytdlp
}

function Construir-Args($enlaces, $sync, $indices, $carpetaForzada = $null, $plantillaForzada = $null) {
    $fmt = $formatos[$cmbFormato.SelectedIndex]
    $carpetaRaw = if ($carpetaForzada) { [string]$carpetaForzada.TrimEnd('\') } else { Carpeta-UI-Actual }
    $carpeta = Normalizar-Carpeta-Destino $carpetaRaw
    if (-not (Es-Carpeta-Destino-Segura $carpetaRaw)) {
        if (-not $carpetaForzada) { Fijar-Carpeta-UI $carpeta }
    }
    $a = New-Object System.Collections.Generic.List[string]
    $a.AddRange([string[]]@('--newline', '--progress', '--color', 'never', '--no-mtime', '--encoding', 'utf-8', '--windows-filenames'))
    $a.Add('--concurrent-fragments'); $a.Add('4')
    # Robustez: reintentos y no abortar toda la lista si una canción falla
    $a.Add('--retries'); $a.Add('10')
    $a.Add('--fragment-retries'); $a.Add('10')
    $a.Add('--extractor-retries'); $a.Add('3')
    $a.Add('--retry-sleep'); $a.Add('1')
    $a.Add('--ignore-errors')
    $a.Add('--no-abort-on-error')
    # Título disponible antes de fallar por DRM (SoundCloud/YouTube)
    $a.Add('--print'); $a.Add('before_dl:[DMTITLE]%(title)s / %(uploader,creator,artist|)s')

    $ff = Ruta-De 'ffmpeg'
    if ($ff) { $a.Add('--ffmpeg-location'); $a.Add((Split-Path -Parent $ff)) }
    $deno = Ruta-De 'deno'
    if ($deno) { $a.Add('--js-runtimes'); $a.Add("deno:$deno") }

    $hayYt = @($enlaces | Where-Object { $_ -match 'youtube\.com|youtu\.be|ytsearch' }).Count -gt 0
    if ($hayYt) {
        $a.Add('--sleep-interval'); $a.Add('1')
        $a.Add('--max-sleep-interval'); $a.Add('3')
        $a.Add('--sleep-requests'); $a.Add('0.5')
    }

    if ($fmt -eq 'original') {
        $a.AddRange([string[]]@('-f', 'bestaudio/best', '--no-keep-video'))
    } else {
        $a.AddRange([string[]]@('-x', '--audio-format', $fmt, '--audio-quality', '0'))
    }

    $a.Add('-P'); $a.Add($carpeta)
    # Plantilla de progreso (funciona aunque la salida no sea una terminal)
    $a.Add('--progress-template'); $a.Add('download:[DM]%(progress._percent_str)s|%(info.playlist_index)s|%(info.playlist_count)s|%(info.title)s')
    $a.Add('--progress-template'); $a.Add('postprocess:[DM]100%|%(info.playlist_index)s|%(info.playlist_count)s|%(info.title)s')

    if (-not $plantillaForzada -and $cmbOrganizar.SelectedIndex -eq 2) {
        $a.Add('--parse-metadata'); $a.Add('title:(?P<artist>.+?) - (?P<title>.+)')
        $a.Add('--replace-in-metadata'); $a.Add('uploader'); $a.Add('(?i)\s*(- topic|vevo)$'); $a.Add('')
    }
    if ($chkLimpiar.Checked) {
        $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add($reLimpiar);     $a.Add('')
        $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add($reLimpiarCola); $a.Add('')
        $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add('\s{2,}');       $a.Add(' ')
    }
    # Truncar solo si supera el límite (antes ^(.{1,N}).+$ comía 1 carácter siempre)
    $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add('^(.{120}).+$'); $a.Add('\1')
    $a.Add('--replace-in-metadata'); $a.Add('playlist_title'); $a.Add('^(.{80}).+$'); $a.Add('\1')
    $a.Add('--replace-in-metadata'); $a.Add('artist'); $a.Add('^(.{60}).+$'); $a.Add('\1')
    $a.Add('--replace-in-metadata'); $a.Add('uploader'); $a.Add('^(.{60}).+$'); $a.Add('\1')

    if ($chkPortada.Checked) {
        if ($fmt -ne 'wav' -and $fmt -ne 'original') { $a.AddRange([string[]]@('--embed-thumbnail', '--convert-thumbnails', 'jpg')) }
        elseif ($fmt -eq 'original') { $a.Add('--embed-metadata') }
        else { $a.Add('--embed-metadata') }
        if ($fmt -ne 'original') { $a.Add('--embed-metadata') }
    }

    if ($plantillaForzada) {
        $plantilla = $plantillaForzada
    } else {
        switch ($cmbOrganizar.SelectedIndex) {
            0 { $plantilla = '%(title).120B.%(ext)s' }
            1 { $plantilla = '%(playlist_title).80B/%(playlist_index&{} - |)s%(title).100B.%(ext)s' }
            2 { $plantilla = '%(artist,uploader).60B/%(title).100B.%(ext)s' }
        }
    }
    $a.Add('-o'); $a.Add($plantilla)

    $archHist = Archivo-Historial $fmt
    if ($chkSaltar.Checked -or $sync) { $a.Add('--download-archive'); $a.Add($archHist) }
    if ($indices) { $a.Add('-I'); $a.Add($indices) }

    $finales = @($enlaces | ForEach-Object { Arreglar-Enlace $_ })
    foreach ($e in $finales) { $a.Add($e) }
    return @{ args = $a; finales = $finales; fmt = $fmt; carpeta = $carpeta }
}

function Nombre-Carpeta-Seguro($nombre) {
    if (-not $nombre) { return '' }
    $n = [string]$nombre
    foreach ($ch in [IO.Path]::GetInvalidFileNameChars()) { $n = $n.Replace([string]$ch, '') }
    $n = ($n -replace '\s+', ' ').Trim().TrimEnd('.')
    if ($n.Length -gt 80) { $n = $n.Substring(0, 80).Trim().TrimEnd('.') }
    return $n
}

function Carpeta-Padre-DrmYt($d) {
    # Carpeta de la lista (o raíz) dentro de la cual irá la subcarpeta YouTube.
    $raiz = if ($d -and $d.carpeta) { [string]$d.carpeta.TrimEnd('\') } else { (Carpeta-UI-Actual) }

    if ($d -and $d.carpetaLista) {
        $c = [string]$d.carpetaLista.TrimEnd('\')
        if ($c -match '[\\/]YouTube$') { $c = Split-Path -Parent $c }
        if ($c -and $c.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase)) { return $c }
    }

    if ($script:ultimaCarpetaReal) {
        $c = [string]$script:ultimaCarpetaReal.TrimEnd('\')
        if ($c -match '[\\/]YouTube$') { $c = Split-Path -Parent $c }
        if ($c -and $c.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $c)) {
            return $c
        }
    }

    if ($d -and $d.nombreLista) {
        $safe = Nombre-Carpeta-Seguro $d.nombreLista
        if ($safe) { return (Join-Path $raiz $safe) }
    }

    if ($d -and $d.listaActual -and $d.porUrl -and $d.porUrl.ContainsKey($d.listaActual)) {
        $nom = Nombre-Carpeta-Seguro $d.porUrl[$d.listaActual].nombre
        if ($nom) { return (Join-Path $raiz $nom) }
    }

    return $raiz
}

function Preparar-Carpeta-Y-Config-Descarga {
    $carpeta = Carpeta-UI-Actual
    if (-not (Es-Carpeta-Destino-Segura $script:carpetaReal)) {
        Fijar-Carpeta-UI $carpeta
        Aviso (T 'La carpeta no estaba permitida; se usará la carpeta por defecto (dentro de tu perfil).' 'That folder was not allowed; the default folder (inside your profile) will be used.') 'Warning'
    }
    try {
        New-Item -ItemType Directory -Force -Path $carpeta -ErrorAction Stop | Out-Null
    } catch {
        Aviso (T 'No se puede usar esa carpeta. Pulsa "Cambiar..." y elige otra.' 'Cannot use that folder. Press "Change..." and pick another.') 'Warning'
        return $null
    }
    Guardar-Config
    return $carpeta
}

function Nuevo-Estado-Descarga {
    param(
        $built,
        [int]$total,
        [string]$motor,
        $sync = $false,
        $porUrl = @{},
        $calidad = $null
    )
    return @{
        nuevas = 0; saltadas = 0; nErrores = 0; errores = New-Object System.Collections.ArrayList
        actual = 1; total = [Math]::Max($total, 1); titulo = ''; cancelada = $false; yaEstaba = $false; enCurso = $null
        idsSaltados = New-Object System.Collections.ArrayList
        sync = $sync; porUrl = $porUrl; listaActual = $null; nuevasPorLista = @{}
        inicio = Get-Date; carpeta = $built.carpeta; formato = $built.fmt; calidad = $calidad
        carpetaEscaneo = $null; motor = $motor
        completados = New-Object System.Collections.Generic.List[string]
        indiceUrl = 0
        drmPendientes = New-Object System.Collections.ArrayList
        drmMarcados = 0; saltandoDrm = $false; drmFallbackFallo = $false
        nombreLista = $null; carpetaLista = $null
    }
}

function Arrancar-Ui-Descarga([string]$estadoMsg, [string]$calidadTxt = '') {
    Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
    $lstResultados.Items.Clear()
    $lblCalidad.Text = $calidadTxt
    if (-not $script:enMini) { Mostrar-Pestana 1 }
    Modo 'descarga'
    Barra-Tarea 1
    Estado $estadoMsg
}

function Lanzar-Descarga($enlaces, $sync = $false, $indices = '') {
    $ytdlp = Preparar-Ytdlp
    if (-not $ytdlp) { return }
    if (-not (Preparar-Carpeta-Y-Config-Descarga)) { return }

    $built = Construir-Args $enlaces $sync $indices
    $porUrl = @{}
    if ($sync) { foreach ($x in $script:listas) { if ($built.finales -contains $x.url) { $porUrl[$x.url] = $x } } }

    $script:dl = Nuevo-Estado-Descarga $built $built.finales.Count 'yt-dlp' $sync $porUrl $null
    $script:ultimaPeticion = @{ enlaces = $enlaces; sync = $sync; indices = $indices; motor = 'yt-dlp' }
    $script:ultimosArgsLista = [string[]]@($built.args)
    $script:ultimosArgs = Formato-Args-Informe $script:ultimosArgsLista

    Arrancar-Ui-Descarga (T 'Empezando la descarga...' 'Starting download...')
    Iniciar-Tarea $ytdlp $script:ultimosArgsLista { param($l) Procesar-Linea $l } { param($c) Terminar-Descarga $c } 0 'descarga'
}

function Resolver-Spotify-Urls($enlaces) {
    # spotDL solo empareja Spotify→YouTube; la descarga real la hace yt-dlp (más actualizado).
    $spotdl = Ruta-De 'spotdl'
    $ff = Ruta-De 'ffmpeg'
    if (-not $spotdl) { return @() }
    $argsList = New-Object System.Collections.Generic.List[string]
    [void]$argsList.Add('url')
    foreach ($e in $enlaces) { [void]$argsList.Add([string]$e) }
    if ($ff) { [void]$argsList.Add('--ffmpeg'); [void]$argsList.Add([string]$ff) }

    $rS = Join-Path $dirApp 'spotdl-url-salida.txt'
    $rE = Join-Path $dirApp 'spotdl-url-errores.txt'
    Remove-Item -LiteralPath $rS, $rE -Force -ErrorAction SilentlyContinue
    $script:popupProc = $null
    try {
        $proc = Start-Process -FilePath $spotdl -ArgumentList $argsList.ToArray() -NoNewWindow -PassThru `
            -RedirectStandardOutput $rS -RedirectStandardError $rE
        $script:popupProc = $proc
        $espera = Esperar-Proceso-Con-Timeout -proc $proc -timeoutSeg 600 -contexto 'Resolver-Spotify-Urls' -siCancelar {
            [bool]$script:popupCancelado
        }
        if ($espera -eq 'timeout') {
            Registrar-Error 'Resolver-Spotify-Urls: spotDL excedió 600s'
            $script:popupProc = $null
            return @()
        }
    } catch {
        Registrar-Error "spotdl url: $($_.Exception.Message)"
        $script:popupProc = $null
        return @()
    }
    $script:popupProc = $null
    if ($script:popupCancelado) { return @() }

    $urls = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $rS) {
        foreach ($l in (Get-Content -LiteralPath $rS -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            $t = ([string]$l).Trim()
            if ($t -match '^https://(www\.)?(music\.)?youtube\.com/' -or $t -match '^https://youtu\.be/') {
                [void]$urls.Add($t)
            }
        }
    }
    return @($urls)
}

function Lanzar-Descarga-Spotify($enlaces, $sync = $false) {
    $spotdl = Preparar-Spotdl
    if (-not $spotdl) { return }
    $ytdlp = Preparar-Ytdlp
    if (-not $ytdlp) { return }
    Refrescar-Path
    if (-not (Ruta-De 'ffmpeg')) {
        Aviso (T 'Falta FFmpeg. Cierra y vuelve a abrir el programa para instalarlo.' 'FFmpeg is missing. Close and reopen the program to install it.') 'Warning'
        return
    }
    if (-not (Ruta-De 'deno')) {
        Aviso (T 'Falta Deno (necesario para YouTube). Cierra y vuelve a abrir el programa para instalarlo.' 'Deno is missing (needed for YouTube). Close and reopen the program to install it.') 'Warning'
        return
    }

    if (-not (Preparar-Carpeta-Y-Config-Descarga)) { return }

    $script:ytResueltosSp = @()
    $script:enlacesSpResolve = @($enlaces)
    $script:popupCancelado = $false
    $script:pop = Nuevo-Popup 'Spotify' (T "Buscando las canciones en YouTube...`nspotDL empareja; yt-dlp descarga (evita errores 403)." "Looking up tracks on YouTube...`nspotDL matches; yt-dlp downloads (avoids 403 errors).") $true
    $script:pop.form.ShowInTaskbar = $true
    $script:pop.form.Add_Shown({
        $script:pop.paso.Text = (T 'Emparejando con YouTube...' 'Matching on YouTube...')
        Bombeo-Ui
        $script:ytResueltosSp = @(Resolver-Spotify-Urls $script:enlacesSpResolve)
        if ($script:ytResueltosSp.Count -eq 0 -and -not $script:popupCancelado) {
            $script:pop.paso.Text = (T 'Sin resultados. Reintentando emparejado...' 'No results. Retrying match...')
            Bombeo-Ui
            Start-Sleep -Seconds 2
            if (-not $script:popupCancelado) {
                $script:ytResueltosSp = @(Resolver-Spotify-Urls $script:enlacesSpResolve)
            }
        }
        if (-not $script:popupCancelado) {
            Start-Sleep -Milliseconds 150
            Cerrar-Popup
        }
    })
    [void]$script:pop.form.ShowDialog()
    $script:pop = $null
    $form.Enabled = $true

    if ($script:popupCancelado) {
        Estado (T 'Búsqueda de Spotify cancelada.' 'Spotify lookup cancelled.')
        Modo $null
        Barra-Tarea 0
        return
    }

    $ytUrls = @($script:ytResueltosSp)
    if ($ytUrls.Count -eq 0) {
        Aviso (T "No se encontró ninguna canción en YouTube para ese enlace de Spotify.`n`nPrueba otro enlace o más tarde." "No YouTube match found for that Spotify link.`n`nTry another link or later.") 'Warning'
        Estado (T 'Listo.' 'Ready.')
        return
    }

    $porUrl = @{}
    if ($sync) { foreach ($x in $script:listas) { if ($enlaces -contains $x.url) { $porUrl[$x.url] = $x } } }

    $built = Construir-Args $ytUrls $sync ''
    $script:dl = Nuevo-Estado-Descarga $built $ytUrls.Count 'spotify-yt' $sync $porUrl 'Spotify→YouTube'
    $script:ultimaPeticion = @{ enlaces = $enlaces; sync = $sync; indices = ''; motor = 'spotdl' }
    $script:ultimosArgsLista = [string[]]@($built.args)
    $script:ultimosArgs = Formato-Args-Informe $script:ultimosArgsLista

    Arrancar-Ui-Descarga `
        (T "Spotify: $($ytUrls.Count) encontradas. Descargando..." "Spotify: $($ytUrls.Count) matched. Downloading...") `
        (T "Spotify → YouTube: $($ytUrls.Count) canción(es) emparejadas. Descargando con yt-dlp." "Spotify → YouTube: $($ytUrls.Count) track(s) matched. Downloading with yt-dlp.")
    Iniciar-Tarea $ytdlp $script:ultimosArgsLista { param($l) Procesar-Linea $l } { param($c) Terminar-Descarga $c } 0 'descarga'
}

function Encolar-O-Descargar($enlaces, $sync = $false, $indices = '') {
    if (-not (Comprobar-Enlaces $enlaces)) { return }
    Avisar-Spotify-Si-Hace-Falta $enlaces
    $sp = @($enlaces | Where-Object { (Tipo-Enlace $_) -eq 'spotify' })
    $otros = @($enlaces | Where-Object { (Tipo-Enlace $_) -ne 'spotify' })

    if ($script:modo -eq 'descarga' -or $script:modo -eq 'leyendo') {
        $script:colaDescargas.Enqueue(@{ enlaces = $enlaces; sync = $sync; indices = $indices })
        Pintar-Cola
        Estado "Añadido a la cola ($(Plural $script:colaDescargas.Count 'pendiente' 'pendientes'))."
        if (-not $script:enMini) { $txtEnlace.Clear() }
        else { $txtMini.Clear() }
        return
    }

    if ($sp.Count -gt 0 -and $otros.Count -gt 0) {
        $script:colaDescargas.Enqueue(@{ enlaces = $otros; sync = $sync; indices = $indices })
        Pintar-Cola
        Estado 'Spotify primero; YouTube/SoundCloud irán después en la cola.'
        Lanzar-Descarga-Spotify $sp $sync
        return
    }
    if ($sp.Count -gt 0) {
        Lanzar-Descarga-Spotify $sp $sync
        return
    }
    Lanzar-Descarga $otros $sync $indices
}

function Empezar-Descarga {
    $enlaces = Leer-Enlaces
    Encolar-O-Descargar $enlaces
}

function Procesar-Cola {
    if ($script:colaDescargas.Count -eq 0) { return $false }
    $item = $script:colaDescargas.Dequeue()
    Pintar-Cola
    $sp = @($item.enlaces | Where-Object { (Tipo-Enlace $_) -eq 'spotify' })
    if ($sp.Count -gt 0 -and $sp.Count -eq $item.enlaces.Count) {
        Lanzar-Descarga-Spotify $item.enlaces $item.sync
    } elseif ($sp.Count -gt 0) {
        $otros = @($item.enlaces | Where-Object { (Tipo-Enlace $_) -ne 'spotify' })
        if ($otros.Count -gt 0) {
            $script:colaDescargas.Enqueue(@{ enlaces = $otros; sync = $item.sync; indices = $item.indices })
            Pintar-Cola
        }
        Lanzar-Descarga-Spotify $sp $item.sync
    } else {
        Lanzar-Descarga $item.enlaces $item.sync $item.indices
    }
    return $true
}

function Preguntar-Salto-Drm($pendientes) {
    # Devuelve $true si el usuario quiere buscar en YouTube.
    # Respeta "No volver a preguntar" guardado en config.
    if ($config.noPreguntarDrmYt) { return [bool]$config.saltarDrmYtAuto }

    $titulos = @($pendientes | ForEach-Object { [string]$_.titulo } | Where-Object { $_ })
    $n = $titulos.Count
    if ($n -eq 0) { return $false }

    $f = New-Object System.Windows.Forms.Form
    Escalar-Dpi $f
    $f.Text = 'MusicDL'
    $f.ClientSize = New-Object System.Drawing.Size(520, 320)
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.StartPosition = 'CenterParent'
    $f.BackColor = $colPanel
    $f.ForeColor = $colTexto
    $f.Font = $fNormal
    $f.ShowInTaskbar = $false
    if ($script:icono) { $f.Icon = $script:icono }

    $barraTop = New-Object System.Windows.Forms.Panel
    $barraTop.BackColor = $colAcento
    $barraTop.Location = New-Object System.Drawing.Point(0, 0)
    $barraTop.Size = New-Object System.Drawing.Size(520, 4)
    $f.Controls.Add($barraTop)

    Nueva-Etiqueta $f 'PROTECCIÓN DRM' 24 24 470 22 $fEtiqueta $colAcento | Out-Null

    $intro = if ($n -eq 1) {
        "Esta canción tiene DRM (protección anticopia) y no se pudo bajar de la fuente original:"
    } else {
        "$n canciones tienen DRM y no se pudieron bajar de la fuente original:"
    }
    Nueva-Etiqueta $f $intro 24 52 470 40 $fNormal $colSuave | Out-Null

    $lst = New-Object System.Windows.Forms.ListBox
    $lst.Location = New-Object System.Drawing.Point(24, 96)
    $lst.Size = New-Object System.Drawing.Size(472, 88)
    $lst.BackColor = $colCampo
    $lst.ForeColor = $colTexto
    $lst.BorderStyle = 'FixedSingle'
    $lst.IntegralHeight = $false
    foreach ($t in ($titulos | Select-Object -First 20)) { [void]$lst.Items.Add($t) }
    if ($n -gt 20) { [void]$lst.Items.Add("… y $($n - 20) más") }
    $f.Controls.Add($lst)

    Nueva-Etiqueta $f '¿Quieres que intentemos descargar esto en YouTube?' 24 196 470 24 $fNormal $colTexto | Out-Null

    $chk = Nueva-Casilla $f 'No volver a preguntar' 24 228 $false 300

    $btnSi = Nuevo-BotonPrincipal $f 'Sí' 250 262 110 36 $fNormal
    $btnNo = Nuevo-Boton $f 'No' 370 262 110 36
    $btnSi.DialogResult = 'Yes'
    $btnNo.DialogResult = 'No'
    $f.AcceptButton = $btnSi
    $f.CancelButton = $btnNo

    $owner = if ($script:enMini) { $formMini } else { $form }
    $dr = $f.ShowDialog($owner)
    $ok = ($dr -eq 'Yes')

    if ($chk.Checked) {
        $config.noPreguntarDrmYt = $true
        $config.saltarDrmYtAuto = [bool]$ok
        try { Guardar-Config-Disco } catch { Registrar-Error "Config DRM: $($_.Exception.Message)" }
        Sync-Cmb-Drm-Yt
    }
    return [bool]$ok
}

function Marcar-Drm-Sin-Salto($d) {
    if (-not $d.drmPendientes) { return }
    foreach ($p in @($d.drmPendientes)) {
        $tit = [string]$p.titulo
        if (-not $tit) { $tit = 'Canción' }
        $d.nErrores++
        $msg = "$tit — Tiene DRM y no se buscó alternativa en YouTube."
        Resultado ([string][char]0x2717 + '  ' + $msg)
        if (-not $d.errores.Contains($msg)) { [void]$d.errores.Add($msg) }
    }
    $d.drmPendientes.Clear()
    $d.drmMarcados = 0
}

function Intentar-Saltos-Drm($d) {
    # Tras la descarga principal: canciones con DRM → buscar la misma en YouTube.
    if (-not $d -or -not $d.drmPendientes -or $d.drmPendientes.Count -eq 0) { return }
    $pend = @($d.drmPendientes)
    $d.drmPendientes.Clear()
    $d.drmMarcados = 0
    $ytdlp = Ruta-De 'yt-dlp'
    $n = $pend.Count
    $i = 0
    foreach ($p in $pend) {
        if ($d.cancelada) { return }
        $i++
        $titulo = [string]$p.titulo
        if (-not $titulo -or (Es-Titulo-Comodin-Drm $titulo)) {
            $d.nErrores++
            $msg = 'Canción con DRM — no pude leer el título real para buscarla en YouTube.'
            Resultado ([string][char]0x2717 + '  ' + $msg)
            if (-not $d.errores.Contains($msg)) { [void]$d.errores.Add($msg) }
            continue
        }
        if (-not $ytdlp) {
            $d.nErrores++
            $msg = "$titulo — Tiene DRM; intenté buscar en YouTube pero falta el descargador."
            Resultado ([string][char]0x2717 + '  ' + $msg)
            if (-not $d.errores.Contains($msg)) { [void]$d.errores.Add($msg) }
            continue
        }

        Estado ("DRM: buscando alternativa en YouTube ($i/$n):`n$titulo")
        Resultado ([string][char]0x2192 + '  DRM — buscando en YouTube: ' + $titulo)
        Bombeo-Ui

        $query = ($titulo -replace '[\r\n\t]+', ' ').Trim()
        # Quitar restos típicos de path/slug inútil
        $query = ($query -replace '\s{2,}', ' ').Trim()
        if ($query.Length -gt 100) { $query = $query.Substring(0, 100).Trim() }
        $search = "ytsearch1:$query"

        $antes = [int]$d.nuevas
        $antesSalt = [int]$d.saltadas
        $d.drmFallbackFallo = $false
        $d.saltandoDrm = $true
        $d.titulo = $titulo
        $d.yaEstaba = $false
        $d.enCurso = $null
        $d.calidad = $null

        $built = Construir-Args @($search) $false '' (Carpeta-Padre-DrmYt $d) 'YouTube/%(title).100B.%(ext)s'
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $built.carpeta 'YouTube') -ErrorAction SilentlyContinue | Out-Null
        } catch { Catch-Log 'Intentar-Saltos-Drm' $_ }
        $rS = Join-Path $dirApp 'drm-salida.txt'
        $rE = Join-Path $dirApp 'drm-errores.txt'
        Remove-Item -LiteralPath $rS, $rE -Force -ErrorAction SilentlyContinue
        try {
            $argsDrm = [string[]]@($built.args)
            $proc = Start-Process -FilePath $ytdlp -ArgumentList $argsDrm -NoNewWindow -PassThru `
                -RedirectStandardOutput $rS -RedirectStandardError $rE
            $espera = Esperar-Proceso-Con-Timeout -proc $proc -timeoutSeg 300 -contexto 'Intentar-Saltos-Drm' -siCancelar {
                [bool]$d.cancelada
            }
            if ($espera -eq 'timeout') {
                $d.drmFallbackFallo = $true
                Registrar-Error "DRM→YouTube timeout: $titulo"
            }
        } catch {
            Registrar-Error "DRM→YouTube: $($_.Exception.Message)"
            $d.drmFallbackFallo = $true
        }

        if ($d.cancelada) {
            $d.saltandoDrm = $false
            return
        }

        $huboDrmOtraVez = $false
        foreach ($rutaLog in @($rS, $rE)) {
            if (-not (Test-Path -LiteralPath $rutaLog)) { continue }
            foreach ($l in @(Get-Content -LiteralPath $rutaLog -Encoding UTF8 -ErrorAction SilentlyContinue)) {
                if ($l -match '(?i)DRM protected|DRM-protected') { $huboDrmOtraVez = $true }
                Procesar-Linea $l
            }
        }
        # Formato original: a veces no hay ExtractAudio; cerrar si hay destino y no hubo DRM/403 fatal
        if ([int]$d.nuevas -eq $antes -and $d.enCurso -and -not $huboDrmOtraVez -and -not $d.drmFallbackFallo) {
            if (Test-Path -LiteralPath $d.enCurso) { Marcar-Completado $d.enCurso }
        }
        $d.saltandoDrm = $false

        $ok = ([int]$d.nuevas -gt $antes) -or ([int]$d.saltadas -gt $antesSalt)
        if ($ok) {
            Estado ("DRM saltado vía YouTube:`n$titulo")
        } else {
            $d.nErrores++
            $motivo = if ($huboDrmOtraVez) {
                'Intenté saltar el DRM buscando en YouTube, pero el resultado también estaba protegido.'
            } elseif ($d.drmFallbackFallo) {
                'Intenté saltar el DRM buscando en YouTube, pero YouTube bloqueó o no dejó descargar (403/login).'
            } else {
                'Intenté saltar el DRM buscando en YouTube, pero no encontré la misma canción.'
            }
            $lineaErr = "$titulo — $motivo"
            Resultado ([string][char]0x2717 + '  ' + $lineaErr)
            if (-not $d.errores.Contains($lineaErr)) { [void]$d.errores.Add($lineaErr) }
            Estado ("No se pudo saltar el DRM:`n$titulo")
        }
        Poner-Barra-Canciones
        Bombeo-Ui
    }
}

function Guardar-Informe($codigo) {
    try {
        $rS = Join-Path $dirApp 'descarga-salida.txt'
        $rE = Join-Path $dirApp 'descarga-errores.txt'
        $ver = Obtener-Version-Ytdlp
        $txt = New-Object System.Collections.Generic.List[string]
        $txt.Add('Descarga del ' + (Hoy))
        $txt.Add("Versión del programa: $versionApp")
        $motor = if ($script:dl -and $script:dl.motor) { $script:dl.motor } else { 'yt-dlp' }
        $txt.Add("Versión de yt-dlp: $ver")
        $txt.Add("Motor: $motor")
        $txt.Add("Código de salida: $codigo")
        $txt.Add('')
        $txt.Add('Comando:')
        $prefijo = if ($motor -eq 'spotdl' -or $motor -eq 'spotify-yt') { 'spotify→yt-dlp ' } else { 'yt-dlp ' }
        $txt.Add($prefijo + $script:ultimosArgs)
        $txt.Add('')
        $txt.Add('===== Canciones con fallo =====')
        if ($script:dl -and $script:dl.errores -and $script:dl.errores.Count -gt 0) {
            foreach ($e in @($script:dl.errores)) { $txt.Add([string]$e) }
        } else {
            $txt.Add('(ninguna)')
        }
        $txt.Add('')
        $txt.Add('===== Lo que ha ido haciendo =====')
        if (Test-Path -LiteralPath $rS) { foreach ($x in (Get-Content -LiteralPath $rS -Encoding UTF8)) { $txt.Add($x) } }
        $txt.Add('')
        $txt.Add('===== Errores y avisos (yt-dlp) =====')
        if (Test-Path -LiteralPath $rE) { foreach ($x in (Get-Content -LiteralPath $rE -Encoding UTF8)) { $txt.Add($x) } }
        Set-Content -LiteralPath $archInforme -Value $txt -Encoding UTF8
    } catch { Registrar-Error "Informe: $($_.Exception.Message)" }
}

function Limpiar-Restos($d) {
    # Solo temporales / fragmentos / enCurso. NO borra audios recientes (.m4a, .mp3, etc.).
    Start-Sleep -Milliseconds 900
    if (-not $d) { return }
    $desde = $d.inicio.AddSeconds(-5)
    $bases = New-Object System.Collections.Generic.List[string]
    if ($d.carpeta) { [void]$bases.Add($d.carpeta) }
    if ($script:ultimaCarpetaReal) { [void]$bases.Add($script:ultimaCarpetaReal) }
    $ok = @{}
    if ($d.completados) { foreach ($c in @($d.completados)) { if ($c) { $ok[[string]$c] = $true } } }
    $tempExt = @('.part', '.ytdl', '.temp', '.webp', '.jpg', '.jpeg', '.png')

    foreach ($base in @($bases | Select-Object -Unique)) {
        if (-not $base -or -not (Test-Path -LiteralPath $base)) { continue }
        try {
            Get-ChildItem -LiteralPath $base -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $desde } |
                Where-Object {
                    $full = $_.FullName
                    if ($ok.ContainsKey($full)) { return $false }
                    $n = $_.Name.ToLower(); $e = $_.Extension.ToLower()
                    if ($d.enCurso -and ($full -eq [string]$d.enCurso)) { return $true }
                    if ($n -match '\.part($|-frag|\.)' -or $e -in $tempExt -or $n -match '\.temp\.') { return $true }
                    if ($n -match '\.f\d{2,4}(\.|$)') { return $true }
                    return $false
                } | Remove-Item -Force -ErrorAction SilentlyContinue

            Get-ChildItem -LiteralPath $base -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending |
                Where-Object { $_.CreationTime -ge $desde -or $_.LastWriteTime -ge $desde } |
                Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        } catch { Registrar-Error "Limpiar restos: $($_.Exception.Message)" }
    }
}

function Terminar-Descarga($codigo) {
    $d = $script:dl
    $btnAbrirUltima.Enabled = [bool]($script:ultimaCarpetaReal -and (Test-Path -LiteralPath $script:ultimaCarpetaReal))

    if ($d.cancelada) {
        Estado 'Cancelando: limpiando temporales...'
        Limpiar-Restos $d
        Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
        Barra-Tarea 0
        Modo $null
        Estado 'Descarga cancelada. Se han borrado temporales; los audios ya guardados se conservan.'
        $script:colaDescargas.Clear()
        Pintar-Cola
        return
    }
    if ($codigo -eq -999) {
        Guardar-Informe $codigo
        Barra-Tarea 0
        Modo $null
        Estado 'El programa: no se pudo iniciar la descarga.'
        return
    }

    # Canciones con DRM: preguntar si buscar en YouTube (salvo "no volver a preguntar")
    if ($d.drmPendientes -and $d.drmPendientes.Count -gt 0) {
        $hacer = Preguntar-Salto-Drm $d.drmPendientes
        if ($hacer) {
            Intentar-Saltos-Drm $d
            if ($d.cancelada) {
                Estado 'Cancelando: limpiando temporales...'
                Limpiar-Restos $d
                Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
                Barra-Tarea 0
                Modo $null
                Estado 'Descarga cancelada. Se han borrado temporales; los audios ya guardados se conservan.'
                $script:colaDescargas.Clear()
                Pintar-Cola
                return
            }
        } else {
            Marcar-Drm-Sin-Salto $d
        }
    }

    Guardar-Informe $codigo

    if ($d.sync) {
        foreach ($u in $d.porUrl.Keys) {
            $x = $d.porUrl[$u]
            $x.ultima = Hoy
            if ($d.motor -eq 'spotdl' -or $d.motor -eq 'spotify-yt') {
                $x.nuevas = [string][int]$d.nuevas
            } else {
                $x.nuevas = [string][int]$d.nuevasPorLista[$u]
            }
        }
        Guardar-Config
        Pintar-Listas
    }

    Set-BarraValor $barra 1000; Set-BarraValor $barraMini 1000
    $partes = @()
    if ($d.nuevas -gt 0)   { $partes += (Plural $d.nuevas 'canción nueva' 'canciones nuevas') }
    if ($d.saltadas -gt 0) { $partes += (Plural $d.saltadas 'ya la tenías' 'ya las tenías') }
    if ($d.nErrores -gt 0) { $partes += (Plural $d.nErrores 'con problemas' 'con problemas') }

    if ($partes.Count -eq 0) {
        if ($codigo -ne 0) { Estado 'Algo ha fallado. Comprueba el enlace o reinicia para actualizar yt-dlp.' }
        else { Estado 'Terminado.' }
    } elseif ($d.nuevas -eq 0 -and $d.nErrores -eq 0) {
        Estado 'No hay canciones nuevas: ya tenías todas en este formato.'
    } else {
        $msgFin = 'Terminado: ' + ($partes -join ', ') + '.'
        if ($d.nErrores -gt 0 -and ($d.nuevas -gt 0 -or $d.saltadas -gt 0)) {
            $msgFin += ' Las que fallaron se saltaron; el resto está guardado.'
        }
        Estado $msgFin
    }
    if ($d.nuevas -gt 0 -and -not $d.sync) { $txtEnlace.Clear(); $txtMini.Clear() }

    $conProblemas = ($d.nErrores -gt 0 -or ($partes.Count -eq 0 -and $codigo -ne 0))
    Barra-Tarea $(if ($conProblemas) { 4 } else { 2 }) 1000
    Avisar-Final $conProblemas

    # No preguntar en Mis listas, ni si el usuario lo desactivó
    $preguntar = (-not $d.sync) -and (-not $chkNoPreguntar.Checked) -and (-not $config.noPreguntarBorradas)
    if ($preguntar) {
        $borradas = Canciones-Borradas $d
        if ($borradas) { Ofrecer-Rebajar $d }
    }
    if ($d.errores.Count -gt 0) {
        $maxErr = @($d.errores | Select-Object -First 8)
        $extraErr = if ($d.errores.Count -gt 8) {
            "`n`n… y $($d.errores.Count - 8) más (Menú → Ver detalles técnicos)."
        } else { '' }
        Aviso ("Algunas canciones fallaron; el resto se ha seguido descargando:`n`n- " + ($maxErr -join "`n- ") + $extraErr) 'Warning'
    }
    if ($script:sugerirUpdateYtdlp -and -not $script:yaOfrecioUpdateSesion) {
        $script:yaOfrecioUpdateSesion = $true
        $script:sugerirUpdateYtdlp = $false
        if (Pregunta "YouTube ha bloqueado o cambiado algo.`n`n¿Actualizar yt-dlp ahora? (recomendado)") {
            Actualizar-Herramientas-Directas -Forzar
            $verAhora = Obtener-Version-Ytdlp
            Aviso "yt-dlp actualizado a $verAhora.`n`nVuelve a intentar la descarga."
        }
    }
    Barra-Tarea 0
    Modo $null

    if (Procesar-Cola) { return }
}

function Canciones-Borradas($d) {
    if ($d.idsSaltados.Count -eq 0) { return $false }
    $ext = @('.mp3', '.m4a', '.opus', '.flac', '.wav', '.webm', '.ogg', '.aac')
    $base = if ($script:ultimaCarpetaReal -and (Test-Path -LiteralPath $script:ultimaCarpetaReal)) {
        $script:ultimaCarpetaReal
    } else { $d.carpeta }
    $hay = 0
    try {
        # Solo la carpeta de esta descarga (no toda la biblioteca)
        $hay = @(Get-ChildItem -LiteralPath $base -File -ErrorAction SilentlyContinue |
            Where-Object { $ext -contains $_.Extension.ToLower() }).Count
    } catch { Catch-Log 'Canciones-Borradas' $_ }
    return ($hay -lt [Math]::Min($d.idsSaltados.Count, 3) -and $hay -eq 0)
}

function Ids-Descargados {
    $fmt = $formatos[$cmbFormato.SelectedIndex]
    $ids = @{}
    $arch = Archivo-Historial $fmt
    if (Test-Path -LiteralPath $arch) {
        foreach ($x in (Get-Content -LiteralPath $arch -Encoding UTF8)) {
            $p = $x.Trim() -split '\s+'
            if ($p.Count -ge 2) { $ids[$p[1]] = $true }
        }
    }
    return $ids
}

function Olvidar-Ids($ids) {
    $fmt = $formatos[$cmbFormato.SelectedIndex]
    $arch = Archivo-Historial $fmt
    if (-not (Test-Path -LiteralPath $arch)) { return }
    $quitar = @{}
    foreach ($i in $ids) { $quitar[[string]$i] = $true }
    $lineas = @(Get-Content -LiteralPath $arch -Encoding UTF8 | Where-Object {
        $partes = $_.Trim() -split '\s+'
        -not ($partes.Count -ge 2 -and $quitar.ContainsKey($partes[1]))
    })
    Set-Content -LiteralPath $arch -Value $lineas -Encoding UTF8
}

function Ofrecer-Rebajar($d) {
    $n = $d.idsSaltados.Count
    $r = [System.Windows.Forms.MessageBox]::Show(
        $(if ($script:enMini) { $formMini } else { $form }),
        "Se han saltado $(Plural $n 'canción' 'canciones') porque ya las descargaste en este formato, pero no están en la carpeta de esta descarga.`n`nSí = volver a descargarlas`nNo = dejarlas saltadas`nCancelar = no volver a preguntar (útil si las moviste a Rekordbox)",
        'MusicDL', 'YesNoCancel', 'Question')
    if ($r -eq 'Cancel') {
        $chkNoPreguntar.Checked = $true
        $config.noPreguntarBorradas = $true
        Guardar-Config
        return
    }
    if ($r -ne 'Yes') { return }
    Olvidar-Ids $d.idsSaltados
    $p = $script:ultimaPeticion
    if ($p.motor -eq 'spotdl') { Lanzar-Descarga-Spotify $p.enlaces $p.sync }
    else { Lanzar-Descarga $p.enlaces $p.sync $p.indices }
}
#endregion Descarga

