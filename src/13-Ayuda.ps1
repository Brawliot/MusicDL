#region Ayuda
# ================================================================
#  Ayuda / Desinstalar / Accesos
# ================================================================
function Mostrar-Aviso-Legal-PrimerUso {
    $rev = 0
    try { $rev = [int]$config.avisoLegalRevision } catch { $rev = 0 }
    if ($config.avisoLegalAceptado -and $rev -ge [int]$script:avisoLegalRevisionActual) { return $true }
    $f = New-Object System.Windows.Forms.Form
    Escalar-Dpi $f
    $f.Text = (T 'MusicDL — Condiciones de uso' 'MusicDL — Terms of use')
    $f.ClientSize = New-Object System.Drawing.Size(560, 480)
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterScreen'
    $f.BackColor = $colPanel; $f.ForeColor = $colTexto; $f.Font = $fNormal
    $f.TopMost = $true
    if ($script:icono) { $f.Icon = $script:icono }
    $t = New-Object System.Windows.Forms.TextBox
    $t.Multiline = $true; $t.ReadOnly = $true; $t.ScrollBars = 'Vertical'
    $t.BorderStyle = 'None'; $t.BackColor = $colPanel; $t.ForeColor = $colTexto
    $t.TabStop = $true
    $t.AccessibleName = (T 'Texto de condiciones de uso' 'Terms of use text')
    $t.AccessibleRole = [System.Windows.Forms.AccessibleRole]::Document
    $t.Location = New-Object System.Drawing.Point(20, 18)
    $t.Size = New-Object System.Drawing.Size(520, 380)
    $t.Text = (T @"
AVISO LEGAL (uso personal)

MusicDL es una herramienta local. Al continuar confirmas que:

1. Respetarás los términos de YouTube, SoundCloud y Spotify y la legislación de tu país sobre derechos de autor.
2. Usarás el programa solo para uso personal; no redistribuirás, venderás ni compartirás contenido sin permiso.
3. Entiendes que Spotify no entrega audio Premium: se busca un equivalente en YouTube (calidad variable).
4. Si una canción tiene DRM (protección anticopia) y no se puede bajar de la fuente, MusicDL puede buscar la misma en YouTube. No desactiva el DRM de la plataforma; es una búsqueda alternativa. Tú eliges (pestaña AJUSTES) y eres responsable según la ley de tu país y los términos de las plataformas.
5. El autor no se hace responsable del uso indebido ni de bloqueos o cambios de las plataformas.
6. No quitarás el crédito «Made by WLY» / MusicDL al redistribuir el programa.

Si no estás de acuerdo, pulsa «No acepto» y el programa se cerrará. No se descargarán herramientas.
"@ @"
LEGAL NOTICE (personal use)

MusicDL is a local tool. By continuing you confirm that:

1. You will respect YouTube, SoundCloud and Spotify terms and your country's copyright law.
2. You will use the program for personal use only; you will not redistribute, sell or share content without permission.
3. You understand Spotify does not provide Premium audio: an equivalent is searched on YouTube (variable quality).
4. If a track has DRM (copy protection) and cannot be downloaded from the source, MusicDL may search for it on YouTube. This does not disable the platform DRM; it is an alternate search. You choose (SETTINGS tab) and are responsible under your local law and platform terms.
5. The author is not liable for misuse or for platform blocks or changes.
6. You will not remove the «Made by WLY» / MusicDL credit when redistributing the program.

If you disagree, press «I do not accept» and the program will close. No tools will be downloaded.
"@) -replace "(?<!`r)`n", "`r`n"
    $f.Controls.Add($t)
    $bOk = Nuevo-BotonPrincipal $f (T 'ACEPTO' 'I ACCEPT') 280 420 140 36 $fBotonMed
    $bOk.DialogResult = 'Yes'
    $bNo = Nuevo-Boton $f (T 'No acepto' 'I do not accept') 140 420 120 36
    $bNo.DialogResult = 'No'
    $f.AcceptButton = $bOk
    $f.CancelButton = $bNo
    $r = $f.ShowDialog()
    $f.Dispose()
    if ($r -eq 'Yes') {
        $config.avisoLegalAceptado = $true
        $config.avisoLegalRevision = [int]$script:avisoLegalRevisionActual
        try { Guardar-Config-Disco } catch { Catch-Log 'AvisoLegal' $_ }
        return $true
    }
    return $false
}

function Mostrar-Onboarding-PrimerUso {
    if ($config.onboardingHecho) { return }
    $f = New-Object System.Windows.Forms.Form
    Escalar-Dpi $f
    $f.Text = 'MusicDL — Cómo empezar'
    $f.ClientSize = New-Object System.Drawing.Size(520, 360)
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterScreen'
    $f.BackColor = $colPanel; $f.ForeColor = $colTexto; $f.Font = $fNormal
    $f.TopMost = $true
    if ($script:icono) { $f.Icon = $script:icono }

    $barraTop = New-Object System.Windows.Forms.Panel
    $barraTop.BackColor = $colAcento
    $barraTop.Location = New-Object System.Drawing.Point(0, 0)
    $barraTop.Size = New-Object System.Drawing.Size(520, 4)
    $f.Controls.Add($barraTop)

    Nueva-Etiqueta $f 'Tres pasos' 24 24 470 28 $fTitulo $colTexto | Out-Null
    $t = New-Object System.Windows.Forms.TextBox
    $t.Multiline = $true; $t.ReadOnly = $true; $t.BorderStyle = 'None'
    $t.BackColor = $colPanel; $t.ForeColor = $colSuave; $t.Font = $fNormal
    $t.TabStop = $true
    $t.AccessibleName = (T 'Tutorial de tres pasos' 'Three-step tutorial')
    $t.AccessibleRole = [System.Windows.Forms.AccessibleRole]::Document
    $t.Location = New-Object System.Drawing.Point(24, 70)
    $t.Size = New-Object System.Drawing.Size(470, 210)
    $t.Text = @"
1. Abre YouTube, SoundCloud o Spotify y copia el enlace de la canción o lista (Compartir → Copiar enlace).

2. Vuelve aquí y pulsa PEGAR (o Ctrl+V en la caja).

3. Pulsa el botón naranja DESCARGAR.

La música se guarda en «Música descargada» (tu carpeta Música). Puedes cambiarlo con CAMBIAR.

Si necesitas formato, carpetas u otras opciones, pulsa «Más opciones».
"@ -replace "(?<!`r)`n", "`r`n"
    $f.Controls.Add($t)

    $b = Nuevo-BotonPrincipal $f 'ENTENDIDO' 340 300 150 36 $fBotonMed
    $b.DialogResult = 'OK'
    $f.AcceptButton = $b
    [void]$f.ShowDialog()
    $f.Dispose()
    $config.onboardingHecho = $true
    try { Guardar-Config-Disco } catch { Catch-Log 'Onboarding' $_ }
}

function Avisar-Spotify-Si-Hace-Falta($enlaces) {
    if ($config.avisoSpotifyHecho) { return }
    $hay = @($enlaces | Where-Object { (Tipo-Enlace $_) -eq 'spotify' })
    if ($hay.Count -eq 0) { return }
    Aviso @"
Sobre Spotify

Spotify no permite bajar el audio Premium.
MusicDL busca la misma canción en YouTube y descarga esa versión.

La calidad puede variar un poco respecto a Spotify.
"@
    $config.avisoSpotifyHecho = $true
    try { Guardar-Config-Disco } catch { Catch-Log 'AvisoSpotify' $_ }
}

function Mostrar-Ayuda {
    $f = New-Object System.Windows.Forms.Form
    Escalar-Dpi $f
    $f.Text = 'Ayuda - MusicDL'
    $f.ClientSize = New-Object System.Drawing.Size(560, 560)
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterParent'
    $f.BackColor = $colPanel; $f.ForeColor = $colTexto; $f.Font = $fNormal
    if ($script:icono) { $f.Icon = $script:icono }
    $t = New-Object System.Windows.Forms.TextBox
    $t.Multiline = $true; $t.ReadOnly = $true; $t.ScrollBars = 'Vertical'
    $t.BorderStyle = 'None'; $t.BackColor = $colPanel; $t.ForeColor = $colTexto
    $t.TabStop = $true
    $t.AccessibleName = (T 'Texto de ayuda' 'Help text')
    $t.AccessibleRole = [System.Windows.Forms.AccessibleRole]::Document
    $t.HideSelection = $true
    $t.Location = New-Object System.Drawing.Point(20, 18)
    $t.Size = New-Object System.Drawing.Size(520, 480)
    $t.Text = @"
CÓMO DESCARGAR
1. Copia el enlace de YouTube, SoundCloud o Spotify (Compartir → Copiar enlace).
2. Pégalo aquí con PEGAR (o Ctrl+V). Varios: uno por línea.
3. Pulsa Descargar. Si ya está descargando, se añade a la cola.

Por defecto ves el modo simple. Pulsa «Más opciones» para formato, carpetas e historial.

Spotify: no se baja el audio Premium; se busca la misma canción en YouTube y se descarga esa versión (calidad variable). La primera vez te lo avisamos.

FORMATO PARA DJs
- "Original (sin convertir)" guarda el audio tal cual lo envía la web: es la mejor calidad posible.
- Con Spotify, "Original" se guarda como M4A sin re-codificar.
- FLAC/WAV/MP3 320 NO mejoran el sonido de YouTube ni SoundCloud (suelen ser 128–160 kbps).
- Para uso diario, MP3 (recomendado) es el más compatible.

MIS LISTAS
Guarda playlists y actualízalas: solo bajan canciones nuevas de ese formato.
También vale con listas de Spotify.
Si mueves temas a Rekordbox, marca "No preguntar si faltan canciones...".

SEGURIDAD
Las actualizaciones del programa deben ir firmadas por el autor. Sin firma válida no se instalan.
Al arrancar se exige MusicDL.bat.sig y se verifica la firma RSA antes de ejecutar.
yt-dlp, FFmpeg, Deno y spotDL solo se usan desde %APPDATA%\MusicDL\bin (URL fija + SHA256; sin PATH ni winget).
Solo se aceptan enlaces https de YouTube, SoundCloud y Spotify.
La carpeta de destino queda acotada a tu perfil (Música, Documentos, Escritorio, Descargas).

LEGAL
Uso personal: respeta ToS de las plataformas y la ley de tu país. No redistribuyas contenido sin permiso.
Spotify→YouTube y DRM→YouTube (si lo activas en AJUSTES) son búsquedas alternativas; no desactivan protecciones de la fuente.
La primera vez (y si cambia el aviso) el programa pide aceptar estas condiciones antes de instalar herramientas.
Idioma: español o English en AJUSTES.

Si algo falla: menú → Ver detalles técnicos / Ver registro de errores.
"@ -replace "(?<!`r)`n", "`r`n"
    $f.Controls.Add($t)
    $b = Nuevo-BotonPrincipal $f 'ENTENDIDO' 400 510 140 36 $fBotonMed
    $b.DialogResult = 'OK'
    $f.AcceptButton = $b
    $f.Add_Shown({
        $t.SelectionStart = 0
        $t.SelectionLength = 0
        $b.Focus()
    })
    $owner = if ($script:enMini) { $formMini } else { $form }
    [void]$f.ShowDialog($owner)
}

function Desinstalar {
    if ($script:modo -ne $null) { Aviso 'Espera a que termine o cancela antes de desinstalar.'; return }
    if (-not (Pregunta "¿Desinstalar MusicDL?`n`nSe quitarán accesos directos, ajustes, listas e historial.`nTu música NO se borra.")) { return }
    $quitarPiezas = Pregunta "¿Quitar también yt-dlp, FFmpeg, Deno y spotDL de la carpeta del programa?"
    Abandonar-Tarea
    if ($quitarPiezas) {
        Mostrar-Popup-Encima 'Desinstalando' 'Quitando las piezas descargadas...'
        try { Remove-Item -LiteralPath $dirBin -Recurse -Force -ErrorAction SilentlyContinue } catch { Catch-Log 'Desinstalar' $_ }
        Cerrar-Popup
    }
    Terminar-Desinstalacion
}

function Terminar-Desinstalacion {
    $script:desinstalado = $true
    foreach ($lnk in @(
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'MusicDL.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Programs')) 'MusicDL.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Descargar música.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Programs')) 'Descargar música.lnk'))) {
        Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $dirApp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $env:APPDATA 'DescargarMusica') -Recurse -Force -ErrorAction SilentlyContinue
    $form.Enabled = $true
    Aviso "MusicDL se ha desinstalado. Tu música sigue en su carpeta.`n`nSe cerrará y se borrará este archivo."
    $bat = $env:DM_BAT
    if ($bat -and (Test-Path -LiteralPath $bat)) {
        $sigDel = $bat + '.sig'
        Start-Process cmd.exe -ArgumentList "/c ping 127.0.0.1 -n 3 > nul & del /f /q `"$bat`" & if exist `"$sigDel`" del /f /q `"$sigDel`"" -WindowStyle Hidden
    }
    $form.Close(); $formMini.Close()
}

function Escribir-Acceso($lnk, $bat) {
    $sh = New-Object -ComObject WScript.Shell
    $s = $sh.CreateShortcut($lnk)
    $s.TargetPath = $bat
    $s.WorkingDirectory = Split-Path $bat
    if (Test-Path -LiteralPath $archIcono) { $s.IconLocation = "$archIcono,0" }
    $s.Description = 'MusicDL — YouTube, SoundCloud y Spotify'
    $s.WindowStyle = 7
    $s.Save()
    if ($script:hayWin) { try { [DMWin]::SetShortcutAppId($lnk, 'MusicDL.App') } catch { Catch-Log 'Escribir-Acceso' $_ } }
}

function Crear-Acceso {
    $bat = $env:DM_BAT
    if (-not $bat -or -not (Test-Path -LiteralPath $bat)) { return }
    try { Escribir-Acceso (Join-Path ([Environment]::GetFolderPath('Programs')) 'MusicDL.lnk') $bat } catch { Catch-Log 'Crear-Acceso' $_ }
    try {
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'MusicDL.lnk'
        if ($config.accesoCreado -and -not (Test-Path -LiteralPath $lnk)) { return }
        Escribir-Acceso $lnk $bat
        $config.accesoCreado = $true
        Guardar-Config
    } catch { Catch-Log 'Crear-Acceso' $_ }
}
#endregion Ayuda

