#region Eventos
# ================================================================
#  Eventos
# ================================================================
$txtEnlace.Add_TextChanged({ Actualizar-Ayuda })
$lblAyuda.Add_Click({ $txtEnlace.Focus() })

$btnPegar.Add_Click({
    $c = (Leer-Portapapeles).Trim()
    if (-not $c) { Estado 'No tienes nada copiado.'; return }
    if (-not (Es-Enlace-Valido $c)) { Aviso 'El portapapeles no tiene un enlace válido de YouTube, SoundCloud o Spotify.' 'Warning'; return }
    $script:ultimoPortapapeles = $c
    $claves = @($txtEnlace.Lines | Where-Object { $_.Trim() -ne '' } | ForEach-Object { Clave-Enlace $_.Trim() })
    if ($claves -contains (Clave-Enlace $c)) { Estado 'Ese enlace ya está puesto.'; return }
    if ($txtEnlace.Text.Trim() -eq '') { $txtEnlace.Text = $c } else { $txtEnlace.AppendText("`r`n" + $c) }
})

$btnBorrar.Add_Click({ $txtEnlace.Clear(); $txtEnlace.Focus() })

$btnCambiar.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Elige la carpeta donde se guardará la música (perfil, Música, Documentos, Escritorio o Descargas)'
    $actual = Carpeta-UI-Actual
    if (Test-Path -LiteralPath $actual) { $dlg.SelectedPath = $actual }
    if ($dlg.ShowDialog($form) -eq 'OK') {
        if (-not (Es-Carpeta-Destino-Segura $dlg.SelectedPath)) {
            Aviso 'Esa carpeta no está permitida. Elige una dentro de tu perfil, Música, Documentos, Escritorio o Descargas.' 'Warning'
            return
        }
        Fijar-Carpeta-UI $dlg.SelectedPath
        Guardar-Config
    }
})

$lnkOlvidar.Add_LinkClicked({
    $fmt = $formatos[$cmbFormato.SelectedIndex]
    if (Pregunta "¿Olvidar el historial del formato '$fmt'?`n`nLa próxima vez se volverán a descargar esas canciones en este formato. Los archivos no se borran.") {
        Remove-Item -LiteralPath (Archivo-Historial $fmt) -Force -ErrorAction SilentlyContinue
        Estado "Historial de $fmt borrado."
    }
})

function Cancelar-Operacion {
    if ($script:modo -eq 'descarga') {
        if ($script:dl) { $script:dl.cancelada = $true }
        Estado 'Cancelando y limpiando temporales...'
        $btnCancelar.Enabled = $false
        if ($btnMiniCancel) { $btnMiniCancel.Enabled = $false }
        Matar-Tarea
    } elseif ($script:modo -eq 'leyendo') {
        $script:lecturaCancelada = $true
        $btnCancelar.Enabled = $false
        if ($btnMiniCancel) { $btnMiniCancel.Enabled = $false }
        Matar-Tarea
    }
}

$btnDescargar.Add_Click({ Empezar-Descarga })
$btnCancelar.Add_Click({ Cancelar-Operacion })
$btnMiniCancel.Add_Click({ Cancelar-Operacion })
$btnElegir.Add_Click({ Elegir-Canciones })

$btnAnadir.Add_Click({ Anadir-Lista })
$txtNuevaLista.Add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Enter') { $e.SuppressKeyPress = $true; Anadir-Lista } })

$btnSyncTodas.Add_Click({
    if ($script:listas.Count -eq 0) { $lblListas.Text = 'Primero añade alguna lista.'; return }
    Encolar-O-Descargar @($script:listas | ForEach-Object { $_.url }) $true
})
$btnSyncUna.Add_Click({
    $sel = Listas-Elegidas
    if ($sel.Count -eq 0) { $lblListas.Text = 'Elige una lista.'; return }
    Encolar-O-Descargar @($sel | ForEach-Object { $_.url }) $true
})
$lvListas.Add_DoubleClick({ $btnSyncUna.PerformClick() })
$btnQuitar.Add_Click({
    $sel = Listas-Elegidas
    if ($sel.Count -eq 0) { $lblListas.Text = 'Elige una lista.'; return }
    $nombre = if ($sel.Count -eq 1 -and $sel[0].nombre) { "`"$($sel[0].nombre)`"" } else { Plural $sel.Count 'lista' 'listas' }
    if (-not (Pregunta "¿Quitar $nombre de Mis listas?`n`nLas canciones no se borran.")) { return }
    foreach ($x in $sel) { $script:listas.Remove($x) }
    Guardar-Config
    Pintar-Listas
})
$chkNoPreguntar.Add_CheckedChanged({ Guardar-Config })
$chkBajarCopiar.Add_CheckedChanged({ Guardar-Config })

$btnAbrirUltima.Add_Click({
    if ($script:ultimaCarpetaReal -and (Test-Path -LiteralPath $script:ultimaCarpetaReal)) {
        Start-Process explorer.exe (Q $script:ultimaCarpetaReal)
    }
})
$btnAbrir.Add_Click({
    $c = Carpeta-UI-Actual
    try { New-Item -ItemType Directory -Force -Path $c | Out-Null } catch { Catch-Log 'Abrir-Carpeta' $_ }
    Start-Process explorer.exe (Q $c)
})

$lnkMasOpciones.Add_LinkClicked({
    $config.modoSimple = -not [bool]$config.modoSimple
    Aplicar-Diseno-Descarga
    try { Guardar-Config-Disco } catch { Catch-Log 'ModoSimple' $_ }
})

$btnAyuda.Add_Click({ Mostrar-Ayuda })
$btnMas.Add_Click({ $menu.Show($btnMas, 0, $btnMas.Height) })
$btnMini.Add_Click({ Mostrar-Mini })
$btnExpandir.Add_Click({ Mostrar-Grande })
$btnMiniDl.Add_Click({
    $u = $txtMini.Text.Trim()
    if (-not $u) { $u = (Leer-Portapapeles).Trim() }
    if (-not (Es-Enlace-Valido $u)) { Aviso 'Pega un enlace válido de YouTube, SoundCloud o Spotify.' 'Warning'; return }
    if (Parece-Lista $u) {
        if (-not (Pregunta "Es una lista. ¿Descargarla / añadirla a la cola?")) { return }
    }
    Encolar-O-Descargar @(Arreglar-Enlace $u)
    $txtMini.Clear()
})

$miDetalles.Add_Click({
    if (Test-Path -LiteralPath $archInforme) { Start-Process notepad.exe (Q $archInforme) }
    else { Aviso 'Todavía no hay detalles.' }
})
$miErrores.Add_Click({
    if (Test-Path -LiteralPath $archErrores) { Start-Process notepad.exe (Q $archErrores) }
    else { Aviso 'Todavía no hay errores internos registrados.' }
})
$miActApp.Add_Click({ Comprobar-App $true })
$miDesinstalar.Add_Click({ Desinstalar })

$form.Add_Activated({ if (-not $chkBajarCopiar.Checked) { Intentar-Bajar-Desde-Portapapeles $false } })
$formMini.Add_Activated({ })

$form.Add_FormClosing({
    param($s, $e)
    if ($script:desinstalado -or $script:reiniciando) { return }
    if ($script:enMini) { $e.Cancel = $true; $form.Hide(); return }
    if ($script:modo -ne $null) {
        if (-not (Pregunta 'Hay una descarga en marcha. Si cierras, se cancelará. ¿Cerrar?')) { $e.Cancel = $true; return }
        if ($script:dl) { $script:dl.cancelada = $true }
        Matar-Tarea
        if ($script:dl -and $script:modo -eq 'descarga') { Limpiar-Restos $script:dl }
    } elseif ($script:tarea) { Matar-Tarea }
    Guardar-Config
    $formMini.Close()
})

$formMini.Add_FormClosing({
    param($s, $e)
    if ($script:desinstalado -or $script:reiniciando) { return }
    if ($script:enMini) {
        # Cerrar mini = salir del todo
        if ($script:modo -ne $null) {
            if (-not (Pregunta 'Hay una descarga en marcha. ¿Cerrar?')) { $e.Cancel = $true; return }
            if ($script:dl) { $script:dl.cancelada = $true }
            Matar-Tarea
        }
        Guardar-Config
        $script:reiniciando = $true  # evitar bucle
        $form.Close()
    }
})
$form.Add_Shown({
    $pasoUi = 'inicio'
    try {
        $pasoUi = 'marcar'
        Marcar-Arranque-Ok
        $pasoUi = 'legal'
        if (-not (Mostrar-Aviso-Legal-PrimerUso)) {
            $script:reiniciando = $true
            $form.Close()
            return
        }
        $pasoUi = 'onboarding'
        Mostrar-Onboarding-PrimerUso
        if ($script:hayWin) {
            $pasoUi = 'tema'
            try { if ($form -and $form.Handle) { [DMWin]::TemaOscuro($form.Handle) } } catch { Catch-Log 'Shown-Tema form' $_ }
            try { if ($txtEnlace) { [DMWin]::TemaOscuro($txtEnlace.Handle) } } catch { Catch-Log 'Shown-TemaEnlace' $_ }
            try { if ($txtCarpeta) { [DMWin]::TemaOscuro($txtCarpeta.Handle) } } catch { Catch-Log 'Shown-TemaCarpeta' $_ }
            try { if ($txtNuevaLista) { [DMWin]::TemaOscuro($txtNuevaLista.Handle) } } catch { Catch-Log 'Shown-TemaNuevaLista' $_ }
            try { if ($lstResultados) { [DMWin]::TemaOscuro($lstResultados.Handle) } } catch { Catch-Log 'Shown-TemaResultados' $_ }
            try { if ($lvListas) { [DMWin]::TemaOscuro($lvListas.Handle) } } catch { Catch-Log 'Shown-TemaListas' $_ }
            try { if ($txtNuevaLista) { [DMWin]::Pista($txtNuevaLista.Handle, (T 'Pega aquí el enlace de una lista' 'Paste a playlist link here')) } } catch { Catch-Log 'Shown-PistaLista' $_ }
        }
        $pasoUi = 'acceso'
        Crear-Acceso
        $pasoUi = 'ayuda'
        Actualizar-Ayuda
        $pasoUi = 'listas'
        Pintar-Listas
        $pasoUi = 'cola'
        Pintar-Cola
        try { Refrescar-Path } catch { Catch-Log 'Shown-RefrescarPath' $_ }
        if ($lblAct) { $lblAct.Text = (T 'Todo listo' 'Ready') }

        if ($script:timerAct) { try { $script:timerAct.Stop(); $script:timerAct.Dispose() } catch {} }
        $script:timerAct = New-Object System.Windows.Forms.Timer
        $script:timerAct.Interval = 2000
        $script:timerAct.Add_Tick({
            try {
                if ($script:timerAct) { $script:timerAct.Stop() }
                if ($lblAct) { $lblAct.Text = (T 'Comprobando descargador...' 'Checking downloader...') }
                Bombeo-Ui
                Actualizar-Herramientas-Directas
            } catch {
                if ($lblAct) { $lblAct.Text = (T 'Todo al día' 'Up to date') }
                Registrar-Error "Timer actualización: $($_.Exception.Message)"
            }
        })
        $script:timerAct.Start()

        # Comprobar versión un poco después (evitar errores en Shown)
        if ($script:timerCheckApp) { try { $script:timerCheckApp.Stop(); $script:timerCheckApp.Dispose() } catch {} }
        $script:timerCheckApp = New-Object System.Windows.Forms.Timer
        $script:timerCheckApp.Interval = 800
        $script:timerCheckApp.Add_Tick({
            try { $script:timerCheckApp.Stop(); $script:timerCheckApp.Dispose(); $script:timerCheckApp = $null } catch {}
            try { Comprobar-App } catch { Registrar-Error "Comprobar-App diferida: $($_.Exception.Message)" }
        })
        $script:timerCheckApp.Start()

        if ($config -and $config.ventanaMini) { Mostrar-Mini }
        try { Aplicar-Idioma } catch { Catch-Log 'Shown-AplicarIdioma' $_ }
    } catch {
        Registrar-Error "Al mostrar ventana ($pasoUi): $($_.Exception.Message)"
        try { if ($lblAct) { $lblAct.Text = (T 'Listo' 'Ready') } } catch { Catch-Log 'Shown-CatchLbl' $_ }
    }
})
#endregion Eventos

