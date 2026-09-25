#region UI-Principal
# ================================================================
#  Ventana principal
# ================================================================
$form = New-Object System.Windows.Forms.Form
Escalar-Dpi $form
$form.Text = 'MusicDL'
$form.ClientSize = New-Object System.Drawing.Size(780, 1000)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $colFondo
$form.ForeColor = $colTexto
$form.Font = $fNormal

$tips = New-Object System.Windows.Forms.ToolTip
$tips.AutoPopDelay = 15000
$tips.BackColor = $colPanel
$tips.ForeColor = $colTexto

$hdrBar = New-Object System.Windows.Forms.Panel
$hdrBar.BackColor = $colAcento
$hdrBar.Location = New-Object System.Drawing.Point(0, 0)
$hdrBar.Size = New-Object System.Drawing.Size(780, 3)
$form.Controls.Add($hdrBar)

Nueva-Etiqueta $form 'MusicDL' 28 18 480 34 $fTitulo $colTexto | Out-Null
Nueva-Etiqueta $form 'YouTube  ·  SoundCloud  ·  Spotify' 30 54 400 20 $fPequena $colSuave | Out-Null
$lblSello = Nueva-Etiqueta $form 'Made by WLY' 430 54 150 20 $fPequena $colTenue
$lblSello.TextAlign = 'MiddleRight'

$btnMini = Nuevo-Boton $form 'MINI' 600 20 54 32
$tips.SetToolTip($btnMini, 'Ventana pequeña con cola y bajar al copiar')
$btnAyuda = Nuevo-Boton $form '?' 662 20 36 32
$btnAyuda.Font = $fBotonMed
$tips.SetToolTip($btnAyuda, 'Ayuda')
$btnMas = Nuevo-Boton $form ([string][char]0x22EF) 706 20 36 32
$btnMas.Font = $fBotonMed
$tips.SetToolTip($btnMas, 'Más opciones')

# Pestañas propias (el TabControl de Windows deja una franja blanca)
$script:pestanaActual = 1
$barPestanas = New-Object System.Windows.Forms.Panel
$barPestanas.Location = New-Object System.Drawing.Point(20, 90)
$barPestanas.Size = New-Object System.Drawing.Size(740, 40)
$barPestanas.BackColor = $colFondo
$form.Controls.Add($barPestanas)

$btnTabDesc = Nuevo-Boton $barPestanas 'DESCARGAR' 0 4 150 32
$btnTabList = Nuevo-Boton $barPestanas 'MIS LISTAS' 158 4 150 32
$btnTabAjustes = Nuevo-Boton $barPestanas 'AJUSTES' 316 4 150 32
$btnTabDesc.FlatAppearance.BorderSize = 0
$btnTabList.FlatAppearance.BorderSize = 0
$btnTabAjustes.FlatAppearance.BorderSize = 0

$tabHost = New-Object System.Windows.Forms.Panel
$tabHost.Location = New-Object System.Drawing.Point(20, 130)
$tabHost.Size = New-Object System.Drawing.Size(740, 790)
$tabHost.BackColor = $colPanel
$form.Controls.Add($tabHost)

$tab1 = New-Object System.Windows.Forms.Panel
$tab1.Dock = 'Fill'
$tab1.BackColor = $colPanel
$tab1.ForeColor = $colTexto
$tabHost.Controls.Add($tab1)

$tab2 = New-Object System.Windows.Forms.Panel
$tab2.Dock = 'Fill'
$tab2.BackColor = $colPanel
$tab2.ForeColor = $colTexto
$tab2.Visible = $false
$tabHost.Controls.Add($tab2)

$tab3 = New-Object System.Windows.Forms.Panel
$tab3.Dock = 'Fill'
$tab3.BackColor = $colPanel
$tab3.ForeColor = $colTexto
$tab3.Visible = $false
$tabHost.Controls.Add($tab3)

function Pintar-Pestanas {
    $activo = { param($b, $on)
        if ($on) {
            $b.ForeColor = $colAcento
            $b.BackColor = $colPanel
            $b.FlatAppearance.MouseOverBackColor = $colPanel
        } else {
            $b.ForeColor = $colSuave
            $b.BackColor = $colFondo
            $b.FlatAppearance.MouseOverBackColor = $colHover
        }
    }
    & $activo $btnTabDesc ($script:pestanaActual -eq 1)
    & $activo $btnTabList ($script:pestanaActual -eq 2)
    & $activo $btnTabAjustes ($script:pestanaActual -eq 3)
}

function Mostrar-Pestana($n) {
    $script:pestanaActual = $n
    $tab1.Visible = ($n -eq 1)
    $tab2.Visible = ($n -eq 2)
    $tab3.Visible = ($n -eq 3)
    if ($n -eq 1) { $tab1.BringToFront() }
    elseif ($n -eq 2) { $tab2.BringToFront() }
    else { $tab3.BringToFront() }
    Pintar-Pestanas
}

$btnTabDesc.Add_Click({ Mostrar-Pestana 1 })
$btnTabList.Add_Click({ Mostrar-Pestana 2 })
$btnTabAjustes.Add_Click({ Mostrar-Pestana 3 })
Pintar-Pestanas

$script:lblTabEnlaces = Nueva-Etiqueta $tab1 'ENLACES' 24 20 220 18 $fEtiqueta $colAcento
$txtEnlace = Nuevo-Campo $tab1 24 44 560 100 $true

$lblAyuda = New-Object System.Windows.Forms.Label
$lblAyuda.Text = "1. Copia el enlace de la canción o lista.`r`n2. Pégalo aquí (o pulsa PEGAR). Varios: uno por línea."
$lblAyuda.ForeColor = $colTenue
$lblAyuda.BackColor = $colCampo
$lblAyuda.Location = New-Object System.Drawing.Point(8, 8)
$lblAyuda.Size = New-Object System.Drawing.Size(520, 44)
$lblAyuda.Cursor = [System.Windows.Forms.Cursors]::IBeam
$txtEnlace.Controls.Add($lblAyuda)

$btnPegar  = Nuevo-Boton $tab1 'PEGAR'  600 44 116 42
$btnBorrar = Nuevo-Boton $tab1 'BORRAR' 600 96 116 42
$tips.SetToolTip($btnPegar, 'Pega el enlace que has copiado (Ctrl+C) desde YouTube, SoundCloud o Spotify')

$lblSalida = Nueva-Etiqueta $tab1 'SALIDA' 24 164 220 18 $fEtiqueta $colAcento
$lblFormato = Nueva-Etiqueta $tab1 'FORMATO' 24 190 340 16 $fEtiqueta $colTenue
$cmbFormato = Nuevo-Combo $tab1 24 210 340 $formatosEtiqueta $config.formato
$tips.SetToolTip($cmbFormato.Boton, "MP3: el más compatible (móvil, coche, casi todo).`nOriginal: deja el audio tal como lo envía la web (mejor para DJs).`nConvertir a FLAC/WAV no mejora el sonido de YouTube ni SoundCloud.")

$lblCarpetas = Nueva-Etiqueta $tab1 'CARPETAS' 384 190 340 16 $fEtiqueta $colTenue
$cmbOrganizar = Nuevo-Combo $tab1 384 210 332 @(
    'Todas las canciones juntas',
    'Una carpeta por cada lista',
    'Una carpeta por cada artista'
) $config.organizar

$lblDestino = Nueva-Etiqueta $tab1 'DÓNDE SE GUARDA' 24 260 400 16 $fEtiqueta $colTenue
$txtCarpeta = Nuevo-Campo $tab1 24 280 560 34 $false
$txtCarpeta.ReadOnly = $true
$script:carpetaReal = Normalizar-Carpeta-Destino $config.carpeta
$txtCarpeta.Text = Texto-Destino-Amigable $script:carpetaReal
$tips.SetToolTip($txtCarpeta, $script:carpetaReal)
$btnCambiar = Nuevo-Boton $tab1 'CAMBIAR' 600 280 116 34
$tips.SetToolTip($btnCambiar, 'Elige otra carpeta (Música, Documentos, Escritorio o Descargas)')

$chkPortada = Nueva-Casilla $tab1 'Guardar carátula y nombre del artista' 24 332 $config.portada 680
$chkLimpiar = Nueva-Casilla $tab1 'Limpiar nombres (Official Video, Lyrics, HD…)' 24 360 $config.limpiar 680
$chkSaltar  = Nueva-Casilla $tab1 'No volver a bajar la misma canción' 24 388 $config.saltar 480
$lnkOlvidar = Nuevo-Enlace $tab1 'Olvidar historial' 520 388 196 'MiddleRight'

$lnkMasOpciones = Nuevo-Enlace $tab1 'Más opciones' 24 228 200 'MiddleLeft'
$tips.SetToolTip($lnkMasOpciones, 'Mostrar u ocultar formato, carpetas y opciones avanzadas')

$btnDescargar = Nuevo-BotonPrincipal $tab1 'DESCARGAR' 24 434 360 52 $fBoton
$btnCancelar  = Nuevo-Boton $tab1 'CANCELAR' 400 434 140 52
$btnCancelar.Enabled = $false
$btnElegir = Nuevo-Boton $tab1 'Elegir canciones…' 556 434 160 52
$tips.SetToolTip($btnElegir, 'YouTube/SoundCloud: elige canciones de la lista. Spotify: usa Descargar (no admite elección una a una).')
$tips.SetToolTip($btnDescargar, 'Si ya hay una descarga, el enlace se añade a la cola')

$lblCola = Nueva-Etiqueta $tab1 '' 24 500 690 20 $fPequena $colSuave

$barra = Nueva-BarraProgreso $tab1 24 528 692 10
$lblEstado = Nueva-Etiqueta $tab1 'Listo. Pega un enlace y pulsa Descargar.' 24 550 692 40 $fNormal $colTexto
$lblEstado.AutoEllipsis = $true
$lblCalidad = Nueva-Etiqueta $tab1 '' 24 594 692 20 $fPequena $colAcento

$lstResultados = Nuevo-ListBoxOscuro $tab1 24 624 692 130

function Aplicar-Diseno-Descarga {
    $simple = [bool]$config.modoSimple
    $visAdv = -not $simple
    foreach ($c in @($lblSalida, $lblFormato, $lblCarpetas, $cmbFormato.Wrap, $cmbOrganizar.Wrap,
                     $chkPortada.Wrap, $chkLimpiar.Wrap, $chkSaltar.Wrap, $lnkOlvidar, $btnElegir)) {
        if ($c) { $c.Visible = $visAdv }
    }
    if ($lnkMasOpciones) {
        $lnkMasOpciones.Text = if ($simple) {
            (T 'Más opciones' 'More options')
        } else {
            (T 'Menos opciones' 'Fewer options')
        }
    }
    $wrapLista = if ($lstResultados) { $lstResultados.Parent } else { $null }
    if ($simple) {
        $btnPegar.Location = New-Object System.Drawing.Point(24, 152)
        $btnPegar.Size = New-Object System.Drawing.Size(140, 36)
        $btnBorrar.Location = New-Object System.Drawing.Point(176, 152)
        $btnBorrar.Size = New-Object System.Drawing.Size(140, 36)
        $lblDestino.Location = New-Object System.Drawing.Point(24, 204)
        Fijar-CampoCaja $txtCarpeta 24 224 500 34
        $btnCambiar.Location = New-Object System.Drawing.Point(536, 224)
        $btnCambiar.Size = New-Object System.Drawing.Size(180, 34)
        $lnkMasOpciones.Location = New-Object System.Drawing.Point(24, 270)
        $btnDescargar.Location = New-Object System.Drawing.Point(24, 310)
        $btnDescargar.Size = New-Object System.Drawing.Size(520, 52)
        $btnCancelar.Location = New-Object System.Drawing.Point(560, 310)
        $btnCancelar.Size = New-Object System.Drawing.Size(156, 52)
        $lblCola.Location = New-Object System.Drawing.Point(24, 376)
        if ($barra -and $barra.track) { $barra.track.Location = New-Object System.Drawing.Point(24, 404) }
        $lblEstado.Location = New-Object System.Drawing.Point(24, 426)
        $lblCalidad.Location = New-Object System.Drawing.Point(24, 470)
        if ($wrapLista) {
            $wrapLista.Location = New-Object System.Drawing.Point(24, 500)
            $wrapLista.Size = New-Object System.Drawing.Size(692, 254)
            $lstResultados.Size = New-Object System.Drawing.Size(690, 252)
        }
    } else {
        $btnPegar.Location = New-Object System.Drawing.Point(600, 44)
        $btnPegar.Size = New-Object System.Drawing.Size(116, 42)
        $btnBorrar.Location = New-Object System.Drawing.Point(600, 96)
        $btnBorrar.Size = New-Object System.Drawing.Size(116, 42)
        $lblDestino.Location = New-Object System.Drawing.Point(24, 260)
        Fijar-CampoCaja $txtCarpeta 24 280 560 34
        $btnCambiar.Location = New-Object System.Drawing.Point(600, 280)
        $btnCambiar.Size = New-Object System.Drawing.Size(116, 34)
        $lnkMasOpciones.Location = New-Object System.Drawing.Point(24, 420)
        $btnDescargar.Location = New-Object System.Drawing.Point(24, 454)
        $btnDescargar.Size = New-Object System.Drawing.Size(360, 52)
        $btnCancelar.Location = New-Object System.Drawing.Point(400, 454)
        $btnCancelar.Size = New-Object System.Drawing.Size(140, 52)
        $btnElegir.Location = New-Object System.Drawing.Point(556, 454)
        $lblCola.Location = New-Object System.Drawing.Point(24, 520)
        if ($barra -and $barra.track) { $barra.track.Location = New-Object System.Drawing.Point(24, 548) }
        $lblEstado.Location = New-Object System.Drawing.Point(24, 570)
        $lblCalidad.Location = New-Object System.Drawing.Point(24, 614)
        if ($wrapLista) {
            $wrapLista.Location = New-Object System.Drawing.Point(24, 644)
            $wrapLista.Size = New-Object System.Drawing.Size(692, 110)
            $lstResultados.Size = New-Object System.Drawing.Size(690, 108)
        }
    }
    # Z-order: destino y acciones por encima de combos/lista ocultos o reposicionados
    if ($wrapLista) { $wrapLista.SendToBack() }
    foreach ($c in @($lblDestino, $txtCarpeta.Parent, $btnCambiar, $lnkMasOpciones, $btnDescargar, $btnCancelar, $btnElegir)) {
        if ($c -and -not $c.IsDisposed) { $c.BringToFront() }
    }
}
Aplicar-Diseno-Descarga

Nueva-Etiqueta $tab2 'LISTAS GUARDADAS' 24 20 400 18 $fEtiqueta $colAcento | Out-Null
Nueva-Etiqueta $tab2 'Al actualizar se bajan solo las canciones nuevas del formato elegido.' 24 46 690 22 $fPequena $colSuave | Out-Null

$txtNuevaLista = Nuevo-Campo $tab2 24 80 560 34 $false
$btnAnadir = Nuevo-Boton $tab2 'AÑADIR' 600 80 116 34

$lvWrap = New-Object System.Windows.Forms.Panel
$lvWrap.Location = New-Object System.Drawing.Point(24, 130)
$lvWrap.Size = New-Object System.Drawing.Size(692, 360)
$lvWrap.BackColor = $colBorde
$tab2.Controls.Add($lvWrap)

$lvListas = New-Object System.Windows.Forms.ListView
$lvListas.Location = New-Object System.Drawing.Point(1, 1)
$lvListas.Size = New-Object System.Drawing.Size(690, 358)
$lvListas.View = 'Details'
$lvListas.FullRowSelect = $true
$lvListas.HideSelection = $false
$lvListas.BorderStyle = 'None'
$lvListas.BackColor = $colCampo
$lvListas.ForeColor = $colTexto
$lvListas.Font = $fPequena
[void]$lvListas.Columns.Add('Lista', 260)
[void]$lvListas.Columns.Add('Última vez', 140)
[void]$lvListas.Columns.Add('Nuevas', 80)
[void]$lvListas.Columns.Add('Enlace', 400)
$lvWrap.Controls.Add($lvListas)

$btnSyncTodas = Nuevo-BotonPrincipal $tab2 'ACTUALIZAR TODAS' 24 510 300 48 $fBotonMed
$btnSyncUna   = Nuevo-Boton $tab2 'ACTUALIZAR' 340 510 180 48
$btnQuitar    = Nuevo-Boton $tab2 'QUITAR' 536 510 180 48
$chkNoPreguntar = Nueva-Casilla $tab2 'No preguntar si faltan temas (si los mueves a Rekordbox)' 24 576 $config.noPreguntarBorradas 680
Nueva-Etiqueta $tab2 'Usa formato, carpetas y opciones de la pestaña Descargar.' 24 612 690 20 $fPequena $colTenue | Out-Null
$lblListas = Nueva-Etiqueta $tab2 '' 24 640 690 22 $fNormal $colTexto

# --- Pestaña AJUSTES ---
function Indice-Drm-Yt {
    if (-not $config.noPreguntarDrmYt) { return 0 }
    if ($config.saltarDrmYtAuto) { return 1 }
    return 2
}
function Aplicar-Indice-Drm-Yt($idx) {
    switch ([int]$idx) {
        1 { $config.noPreguntarDrmYt = $true;  $config.saltarDrmYtAuto = $true }
        2 { $config.noPreguntarDrmYt = $true;  $config.saltarDrmYtAuto = $false }
        default { $config.noPreguntarDrmYt = $false }
    }
}
function Sync-Cmb-Drm-Yt {
    if (-not $script:cmbDrmYt) { return }
    $script:syncDrmUi = $true
    try {
        $idx = Indice-Drm-Yt
        $script:cmbDrmYt.SelectedIndex = $idx
        $script:cmbDrmYt.Boton.Text = "  $($script:cmbDrmYt.Opciones[$idx])"
    } finally { $script:syncDrmUi = $false }
}

$script:lblAjustesTitulo = Nueva-Etiqueta $tab3 'AJUSTES' 24 20 400 18 $fEtiqueta $colAcento
$script:lblDrmTitulo = Nueva-Etiqueta $tab3 'PROTECCIÓN DRM' 24 64 400 18 $fEtiqueta $colAcento
$script:lblDrmDesc = Nueva-Etiqueta $tab3 "Si una canción tiene DRM (protección anticopia) y no se puede bajar de la fuente,`nMusicDL puede buscar la misma en YouTube." 24 90 690 44 $fPequena $colSuave
$script:lblDrmComp = Nueva-Etiqueta $tab3 'COMPORTAMIENTO' 24 150 400 16 $fEtiqueta $colTenue
$opcionesDrm = @(
    'Preguntar siempre',
    'Buscar en YouTube sin preguntar',
    'No buscar en YouTube'
)
$script:cmbDrmYt = Nuevo-Combo $tab3 24 172 692 $opcionesDrm (Indice-Drm-Yt)
$script:cmbDrmYt.AlCambiar = {
    param($idx)
    if ($script:syncDrmUi) { return }
    Aplicar-Indice-Drm-Yt $idx
    try { Guardar-Config-Disco } catch { Registrar-Error "Config DRM UI: $($_.Exception.Message)" }
}
$tips.SetToolTip($script:cmbDrmYt.Boton, "También se puede fijar desde el popup de DRM marcando «No volver a preguntar»:`nSí = buscar siempre · No = no buscar nunca.")
$script:lblDrmNota = Nueva-Etiqueta $tab3 'Puedes cambiarlo aquí en cualquier momento. El popup de DRM usa la misma preferencia.' 24 220 690 40 $fPequena $colTenue

$script:lblIdioma = Nueva-Etiqueta $tab3 'IDIOMA / LANGUAGE' 24 270 400 16 $fEtiqueta $colTenue
$idxIdioma = if ((Idioma-Actual) -eq 'en') { 1 } else { 0 }
$script:cmbIdioma = Nuevo-Combo $tab3 24 292 320 @('Español', 'English') $idxIdioma
$script:cmbIdioma.AlCambiar = {
    param($idx)
    if ($script:syncIdiomaUi) { return }
    $config.idioma = if ($idx -eq 1) { 'en' } else { 'es' }
    try { Aplicar-Idioma } catch { Catch-Log 'Cambiar-Idioma' $_ }
    try { Guardar-Config-Disco } catch { Registrar-Error "Config idioma: $($_.Exception.Message)" }
}
$script:lblIdiomaNota = Nueva-Etiqueta $tab3 'Cambia textos de la interfaz (español / English).' 24 336 690 24 $fPequena $colTenue

$btnAbrirUltima = Nuevo-Boton $form 'Última descarga' 20 940 170 36
$btnAbrirUltima.Enabled = $false
$btnAbrir = Nuevo-Boton $form 'Carpeta de música' 204 940 180 36
$lblAct = Nueva-Etiqueta $form '' 420 946 340 24 $fPequena $colTenue
$lblAct.TextAlign = 'MiddleRight'

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Font = $fNormal
$menu.BackColor = $colPanel
$menu.ForeColor = $colTexto
$miDetalles    = $menu.Items.Add('Ver detalles técnicos de la última descarga')
$miErrores     = $menu.Items.Add('Ver registro de errores internos')
$miActApp      = $menu.Items.Add('Buscar una versión nueva del programa')
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miDesinstalar = $menu.Items.Add('Desinstalar MusicDL...')
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miVersion     = $menu.Items.Add("Versión $versionApp")
$miVersion.Enabled = $false

function Opciones-Drm-Localizadas {
    return @(
        (T 'Preguntar siempre' 'Always ask'),
        (T 'Buscar en YouTube sin preguntar' 'Search YouTube without asking'),
        (T 'No buscar en YouTube' 'Do not search YouTube')
    )
}
function Opciones-Organizar-Localizadas {
    return @(
        (T 'Todas las canciones juntas' 'All tracks together'),
        (T 'Una carpeta por cada lista' 'One folder per playlist'),
        (T 'Una carpeta por cada artista' 'One folder per artist')
    )
}
function Aplicar-Idioma {
    $en = ((Idioma-Actual) -eq 'en')
    $formatosEtiqueta = if ($en) { $script:formatosEtiquetaEn } else { $script:formatosEtiquetaEs }
    if ($script:lblTabEnlaces) { $script:lblTabEnlaces.Text = (T 'ENLACES' 'LINKS') }
    if ($lblAyuda) {
        $lblAyuda.Text = (T `
            "1. Copia el enlace de la canción o lista.`r`n2. Pégalo aquí (o pulsa PEGAR). Varios: uno por línea." `
            "1. Copy the track or playlist link.`r`n2. Paste it here (or press PASTE). Several: one per line.")
    }
    if ($btnTabDesc) { $btnTabDesc.Text = (T 'DESCARGAR' 'DOWNLOAD') }
    if ($btnTabList) { $btnTabList.Text = (T 'MIS LISTAS' 'MY LISTS') }
    if ($btnTabAjustes) { $btnTabAjustes.Text = (T 'AJUSTES' 'SETTINGS') }
    if ($btnPegar) { $btnPegar.Text = (T 'PEGAR' 'PASTE') }
    if ($btnBorrar) { $btnBorrar.Text = (T 'BORRAR' 'CLEAR') }
    if ($lblSalida) { $lblSalida.Text = (T 'SALIDA' 'OUTPUT') }
    if ($lblFormato) { $lblFormato.Text = (T 'FORMATO' 'FORMAT') }
    if ($lblCarpetas) { $lblCarpetas.Text = (T 'CARPETAS' 'FOLDERS') }
    if ($lblDestino) { $lblDestino.Text = (T 'DÓNDE SE GUARDA' 'SAVE LOCATION') }
    if ($btnCambiar) { $btnCambiar.Text = (T 'CAMBIAR' 'CHANGE') }
    if ($chkPortada -and $chkPortada.Etiqueta) {
        $chkPortada.Etiqueta.Text = (T 'Guardar carátula y nombre del artista' 'Save artwork and artist name')
    }
    if ($chkLimpiar -and $chkLimpiar.Etiqueta) {
        $chkLimpiar.Etiqueta.Text = (T 'Limpiar nombres (Official Video, Lyrics, HD…)' 'Clean titles (Official Video, Lyrics, HD…)')
    }
    if ($chkSaltar -and $chkSaltar.Etiqueta) {
        $chkSaltar.Etiqueta.Text = (T 'No volver a bajar la misma canción' 'Skip tracks already downloaded')
    }
    if ($lnkOlvidar) { $lnkOlvidar.Text = (T 'Olvidar historial' 'Clear history') }
    if ($btnDescargar) { $btnDescargar.Text = (T 'DESCARGAR' 'DOWNLOAD') }
    if ($btnCancelar) { $btnCancelar.Text = (T 'CANCELAR' 'CANCEL') }
    if ($btnElegir) { $btnElegir.Text = (T 'Elegir canciones…' 'Pick tracks…') }
    if ($lblEstado -and ($lblEstado.Text -match '^(Listo|Ready)')) {
        $lblEstado.Text = (T 'Listo. Pega un enlace y pulsa Descargar.' 'Ready. Paste a link and press Download.')
    }
    if ($btnAbrirUltima) { $btnAbrirUltima.Text = (T 'Última descarga' 'Last download') }
    if ($btnAbrir) { $btnAbrir.Text = (T 'Carpeta de música' 'Music folder') }
    if ($btnExpandir) { $btnExpandir.Text = (T 'GRANDE' 'FULL') }
    if ($btnMiniDl) { $btnMiniDl.Text = (T 'AÑADIR' 'ADD') }
    if ($btnMiniCancel) { $btnMiniCancel.Text = (T 'CANCELAR' 'CANCEL') }
    if ($chkBajarCopiar -and $chkBajarCopiar.Etiqueta) {
        $chkBajarCopiar.Etiqueta.Text = (T 'Al copiar enlace, preguntar antes de descargar (Mini)' 'When copying a link, ask before downloading (Mini)')
    }
    if ($lblMiniEstado -and ($lblMiniEstado.Text -match '^(Listo|Ready)')) {
        $lblMiniEstado.Text = (T 'Listo.' 'Ready.')
    }
    if ($formMini) { $formMini.Text = (T 'MusicDL (mini)' 'MusicDL (mini)') }
    if ($miDetalles) { $miDetalles.Text = (T 'Ver detalles técnicos de la última descarga' 'View technical details of the last download') }
    if ($miErrores) { $miErrores.Text = (T 'Ver registro de errores internos' 'View internal error log') }
    if ($miActApp) { $miActApp.Text = (T 'Buscar una versión nueva del programa' 'Check for a new program version') }
    if ($miDesinstalar) { $miDesinstalar.Text = (T 'Desinstalar MusicDL...' 'Uninstall MusicDL...') }
    if ($miVersion) { $miVersion.Text = (T "Versión $versionApp" "Version $versionApp") }
    if ($script:lblAjustesTitulo) { $script:lblAjustesTitulo.Text = (T 'AJUSTES' 'SETTINGS') }
    if ($script:lblDrmTitulo) { $script:lblDrmTitulo.Text = (T 'PROTECCIÓN DRM' 'DRM PROTECTION') }
    if ($script:lblDrmDesc) {
        $script:lblDrmDesc.Text = (T `
            "Si una canción tiene DRM (protección anticopia) y no se puede bajar de la fuente,`nMusicDL puede buscar la misma en YouTube." `
            "If a track has DRM (copy protection) and cannot be downloaded from the source,`nMusicDL can search for it on YouTube.")
    }
    if ($script:lblDrmComp) { $script:lblDrmComp.Text = (T 'COMPORTAMIENTO' 'BEHAVIOR') }
    if ($script:lblDrmNota) {
        $script:lblDrmNota.Text = (T `
            'Puedes cambiarlo aquí en cualquier momento. El popup de DRM usa la misma preferencia.' `
            'You can change this anytime. The DRM popup uses the same preference.')
    }
    if ($script:lblIdiomaNota) {
        $script:lblIdiomaNota.Text = (T `
            'Cambia textos de la interfaz (español / English).' `
            'Switch interface language (Spanish / English).')
    }
    if ($cmbFormato) {
        $idx = [int]$cmbFormato.SelectedIndex
        $cmbFormato.Opciones = @($formatosEtiqueta)
        if ($idx -ge 0 -and $idx -lt $formatosEtiqueta.Count) {
            $cmbFormato.SelectedIndex = $idx
            $cmbFormato.Boton.Text = "  $($formatosEtiqueta[$idx])"
        }
    }
    if ($cmbOrganizar) {
        $opsOrg = Opciones-Organizar-Localizadas
        $idx = [int]$cmbOrganizar.SelectedIndex
        $cmbOrganizar.Opciones = @($opsOrg)
        if ($idx -ge 0 -and $idx -lt $opsOrg.Count) {
            $cmbOrganizar.SelectedIndex = $idx
            $cmbOrganizar.Boton.Text = "  $($opsOrg[$idx])"
        }
    }
    if ($script:cmbDrmYt) {
        $ops = Opciones-Drm-Localizadas
        $idx = Indice-Drm-Yt
        $script:cmbDrmYt.Opciones = @($ops)
        $script:cmbDrmYt.SelectedIndex = $idx
        $script:cmbDrmYt.Boton.Text = "  $($ops[$idx])"
    }
    $script:syncIdiomaUi = $true
    try {
        if ($script:cmbIdioma) {
            $ii = if ($en) { 1 } else { 0 }
            $script:cmbIdioma.SelectedIndex = $ii
            $script:cmbIdioma.Boton.Text = "  $(@('Español', 'English')[$ii])"
        }
    } finally { $script:syncIdiomaUi = $false }
    try { Aplicar-Diseno-Descarga } catch { Catch-Log 'Aplicar-Idioma-Diseno' $_ }
    try { Pintar-Pestanas } catch { Catch-Log 'Aplicar-Idioma-Pestanas' $_ }
}
#endregion UI-Principal

