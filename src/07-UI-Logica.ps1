#region UI-Logica
# ================================================================
#  Lógica de UI
# ================================================================
$script:modo = $null
$script:ultimaCarpetaReal = $null
$script:enMini = $false

function Estado($texto) {
    $lblEstado.Text = $texto
    $lblMiniEstado.Text = $texto
}
function Aviso($texto, $icono = 'Information') {
    $owner = if ($script:enMini) { $formMini } else { $form }
    [System.Windows.Forms.MessageBox]::Show($owner, $texto, 'MusicDL', 'OK', $icono) | Out-Null
}
function Pregunta($texto) {
    $owner = if ($script:enMini) { $formMini } else { $form }
    return ([System.Windows.Forms.MessageBox]::Show($owner, $texto, 'MusicDL', 'YesNo', 'Question') -eq 'Yes')
}
function Resultado($texto) {
    [void]$lstResultados.Items.Add($texto)
    $lstResultados.TopIndex = [Math]::Max(0, $lstResultados.Items.Count - 1)
}
function Barra-Tarea($estado, $valor = 0) {
    $h = if ($script:enMini) { $formMini.Handle } else { $form.Handle }
    if ($script:hayWin) { try { [DMWin]::Progreso($h, $estado, [uint64]$valor, [uint64]1000) } catch { Catch-Log 'Barra-Tarea' $_ } }
}
function Pintar-Cola {
    $n = $script:colaDescargas.Count
    if ($n -eq 0) { $lblCola.Text = '' }
    else { $lblCola.Text = "Cola: $(Plural $n 'enlace pendiente' 'enlaces pendientes')" }
    $lstMiniCola.Items.Clear()
    foreach ($item in @($script:colaDescargas.ToArray())) {
        $u = if ($item -is [hashtable]) { $item.enlaces[0] } else { $item }
        [void]$lstMiniCola.Items.Add($u)
    }
}
function Guardar-Config {
    if ($script:desinstalado) { return }
    $config.formato   = $cmbFormato.SelectedIndex
    $config.organizar = $cmbOrganizar.SelectedIndex
    $segura = Carpeta-UI-Actual
    Fijar-Carpeta-UI $segura
    $config.carpeta   = $segura
    $config.portada   = $chkPortada.Checked
    $config.limpiar   = $chkLimpiar.Checked
    $config.saltar    = $chkSaltar.Checked
    $config.noPreguntarBorradas = $chkNoPreguntar.Checked
    $config.bajarAlCopiar = $chkBajarCopiar.Checked
    $config.ventanaMini = $script:enMini
    $config.modoSimple = [bool]$config.modoSimple
    $config.listas    = @($script:listas)
    if ($script:cmbDrmYt) { Aplicar-Indice-Drm-Yt $script:cmbDrmYt.SelectedIndex }
    Guardar-Config-Disco
}
function Actualizar-Ayuda { $lblAyuda.Visible = ($txtEnlace.Text -eq '') }

function Modo($m) {
    $script:modo = $m
    $ocupado = ($m -ne $null)
    foreach ($c in @($cmbFormato, $cmbOrganizar, $btnCambiar, $chkPortada, $chkLimpiar,
                     $chkSaltar, $lnkOlvidar, $btnElegir, $txtNuevaLista, $btnAnadir, $btnSyncTodas, $btnSyncUna, $btnQuitar, $chkNoPreguntar, $script:cmbDrmYt)) {
        if ($c) { $c.Enabled = -not $ocupado }
    }
    # Enlaces y pegar siguen activos para poder encolar
    $txtEnlace.Enabled = $true
    $btnPegar.Enabled = $true
    $btnBorrar.Enabled = (-not $ocupado)
    $btnDescargar.Enabled = $true
    $btnCancelar.Enabled = $ocupado
    if ($btnMiniCancel) { $btnMiniCancel.Enabled = $ocupado }
    $btnMiniDl.Enabled = $true
    if ($ocupado) {
        $btnDescargar.Text = 'AÑADIR A COLA'
        $btnDescargar.BackColor = $colAcento
    } else {
        $btnDescargar.Text = 'DESCARGAR'
        $btnDescargar.BackColor = $colAcento
        $btnDescargar.FlatAppearance.MouseOverBackColor = $colAcentoOsc
    }
    Pintar-Cola
}

function Avisar-Final($conProblemas) {
    try {
        $wav = Join-Path $env:WINDIR 'Media\Windows Notify System Generic.wav'
        if (-not $conProblemas -and (Test-Path -LiteralPath $wav)) {
            (New-Object System.Media.SoundPlayer $wav).Play()
        } elseif ($conProblemas) {
            [System.Media.SystemSounds]::Exclamation.Play()
        } else {
            [System.Media.SystemSounds]::Asterisk.Play()
        }
    } catch { Catch-Log 'Avisar-Final' $_ }
    $activo = [System.Windows.Forms.Form]::ActiveForm
    $frm = if ($script:enMini) { $formMini } else { $form }
    if ($script:hayWin -and $activo -ne $frm) {
        try { [DMWin]::Flash($frm.Handle) } catch { Catch-Log 'Avisar-Final' $_ }
    }
}

function Leer-Portapapeles {
    try { return [System.Windows.Forms.Clipboard]::GetText() } catch { return '' }
}

function Obtener-Version-Ytdlp {
    if ($script:versionYtdlp) { return $script:versionYtdlp }
    try {
        $y = Ruta-De 'yt-dlp'
        if ($y) {
            $script:versionYtdlp = (& $y --version 2>$null | Select-Object -First 1)
        }
    } catch { Catch-Log 'Obtener-Version-Ytdlp' $_ }
    if (-not $script:versionYtdlp) { $script:versionYtdlp = '?' }
    return $script:versionYtdlp
}
#endregion UI-Logica

