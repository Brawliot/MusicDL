#region Arrancar
# ================================================================
#  Arrancar
# ================================================================
[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $e)
    $msg = $e.Exception.Message
    try { $msg += " | " + $e.Exception.StackTrace } catch { Catch-Log 'ThreadException' $_ }
    Registrar-Error "UI: $msg"
})
[AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $e)
    try { Registrar-Error "Fatal: $($e.ExceptionObject)" } catch { Catch-Log 'UnhandledException' $_ }
})

try {
    Crear-Icono
    if ($script:icono) { $form.Icon = $script:icono; $formMini.Icon = $script:icono }
    # Consentimiento antes de descargar yt-dlp / FFmpeg / Deno / spotDL
    if (-not (Mostrar-Aviso-Legal-PrimerUso)) { return }
    if (Instalar-Si-Falta) {
        $form.ShowInTaskbar = $true
        Marcar-Arranque-Ok
        [System.Windows.Forms.Application]::Run($form)
    }
} catch {
    Registrar-Error "Arranque: $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("Ha ocurrido un error inesperado:`n`n$($_.Exception.Message)`n`nSe ha guardado en el registro de errores.", 'MusicDL', 'OK', 'Error') | Out-Null
} finally {
    if ($script:mutex) { try { $script:mutex.ReleaseMutex() } catch {}; try { $script:mutex.Dispose() } catch {} }
}
#endregion Arrancar

