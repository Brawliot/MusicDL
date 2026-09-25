#region Actualizacion
# ================================================================
#  Actualización firmada del programa
# ================================================================
$timerApp = New-Object System.Windows.Forms.Timer
$timerApp.Interval = 400

function Comprobar-App($manual = $false) {
    $script:checkManual = $manual
    if (-not $urlApp) {
        if ($manual) { Aviso 'Este programa no tiene configurado de dónde descargar versiones nuevas. Pide el enlace Raw de GitHub a quien te lo pasó.' }
        return
    }
    try {
        $script:http = New-Object System.Net.Http.HttpClient
        $script:http.Timeout = [TimeSpan]::FromSeconds(30)
        $script:http.DefaultRequestHeaders.UserAgent.ParseAdd('MusicDL/3.40')
        $script:tareaApp = $script:http.GetByteArrayAsync($urlApp + '?v=' + [DateTime]::Now.Ticks)
        $script:firmaUrl = if ($urlFirma) { $urlFirma } else { $urlApp + '.sig' }
        $script:tareaFirma = $script:http.GetStringAsync($script:firmaUrl + '?v=' + [DateTime]::Now.Ticks)
        $timerApp.Start()
    } catch {
        if ($manual) { Aviso 'No se ha podido comprobar si hay una versión nueva. Revisa tu conexión a internet.' 'Warning' }
        Registrar-Error "Comprobar-App: $($_.Exception.Message)"
    }
}

$timerApp.Add_Tick({
    $t = $script:tareaApp
    $tf = $script:tareaFirma
    if (-not $t -or -not $t.IsCompleted) { return }
    if ($tf -and -not $tf.IsCompleted) { return }
    $timerApp.Stop()
    $script:tareaApp = $null
    if ($t.IsFaulted -or $t.IsCanceled) {
        if ($script:checkManual) { Aviso 'No se ha podido comprobar si hay una versión nueva. Revisa tu conexión a internet.' 'Warning' }
        return
    }
    if (-not $tf -or $tf.IsFaulted -or $tf.IsCanceled) {
        if ($script:checkManual) { Aviso 'No se encontró la firma de la versión nueva. Por seguridad no se instalará sin firma válida.' 'Warning' }
        return
    }
    $bytes = $t.Result
    $texto = [Text.Encoding]::UTF8.GetString($bytes)
    $firma = $tf.Result
    if ($texto -notmatch "(?m)^`$versionApp = '([\d\.]+)'" -or $texto -notmatch '^\s*<# :') {
        if ($script:checkManual) { Aviso 'El archivo de la versión nueva no parece correcto.' 'Warning' }
        return
    }
    $nueva = $Matches[1]
    if ($texto -match "(?m)^`$versionApp = '([\d\.]+)'") { $nueva = $Matches[1] }
    try { $esNueva = ([version]$nueva -gt [version]$versionApp) } catch { $esNueva = $false }
    if (-not $esNueva) {
        if ($script:checkManual) { Aviso "Ya tienes la última versión ($versionApp)." }
        return
    }
    if (-not (Verificar-Firma $bytes $firma)) {
        Aviso 'La versión nueva no tiene una firma válida. Por seguridad no se instalará. Avisa a quien te pasó el programa.' 'Warning'
        Registrar-Error "Actualización rechazada: firma inválida (remota $nueva)"
        return
    }
    if ($script:modo -ne $null -and -not $script:checkManual) { return }
    if (-not (Pregunta "Hay una versión nueva de MusicDL ($nueva), firmada por el autor. Tú tienes la $versionApp.`n`n¿Actualizar ahora?")) { return }
    Instalar-VersionApp $bytes $firma
})

function Instalar-VersionApp([byte[]]$bytes, [string]$firmaB64) {
    return Con-ErrorActionStop {
    try {
        $bat = $env:DM_BAT
        $sigPath = $bat + '.sig'
        $prevSig = $archPrevBat + '.sig'
        # Guardar versión anterior (+ firma) para rollback
        Copy-Item -LiteralPath $bat -Destination $archPrevBat -Force
        if (Test-Path -LiteralPath $sigPath) {
            Copy-Item -LiteralPath $sigPath -Destination $prevSig -Force
        } else {
            Remove-Item -LiteralPath $prevSig -Force -ErrorAction SilentlyContinue
        }
        # Escribir exactamente los bytes firmados (LF) para que el .sig siga siendo válido
        [IO.File]::WriteAllBytes($bat, $bytes)
        $firmaLimpia = ([string]$firmaB64) -replace '\s', ''
        [IO.File]::WriteAllText($sigPath, $firmaLimpia, [Text.Encoding]::ASCII)
        [IO.File]::WriteAllText((Join-Path $dirApp 'update-pending.flag'), (Hoy), [Text.Encoding]::UTF8)
        Remove-Item -LiteralPath (Join-Path $dirApp 'esperando-arranque.flag') -Force -ErrorAction SilentlyContinue
        if ($script:tarea) { Matar-Tarea }
        Guardar-Config
        $script:reiniciando = $true
        Start-Process -FilePath $bat
        $form.Close()
        $formMini.Close()
    } catch {
        Registrar-Error "Instalar versión: $($_.Exception.Message)"
        Aviso "No se ha podido actualizar el programa:`n`n$($_.Exception.Message)" 'Warning'
    }

    }
}
#endregion Actualizacion

