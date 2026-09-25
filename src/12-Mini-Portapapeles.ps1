#region Mini-Portapapeles
# ================================================================
#  Mini / Grande y portapapeles
# ================================================================
function Mostrar-Mini {
    $script:enMini = $true
    $config.ventanaMini = $true
    Guardar-Config
    $form.Hide()
    $formMini.Location = New-Object System.Drawing.Point(
        [Math]::Max(40, $form.Left + 80),
        [Math]::Max(40, $form.Top + 80))
    if ($script:icono) { $formMini.Icon = $script:icono }
    $formMini.Show()
    $formMini.Activate()
}
function Mostrar-Grande {
    $script:enMini = $false
    $config.ventanaMini = $false
    Guardar-Config
    $formMini.Hide()
    $form.Show()
    $form.Activate()
}

function Intentar-Bajar-Desde-Portapapeles($forzar = $false) {
    $c = (Leer-Portapapeles).Trim()
    if (-not $c -or $c -eq $script:ultimoPortapapeles) { return }
    if (-not (Es-Enlace-Valido $c)) { return }
    $script:ultimoPortapapeles = $c

    $usarAuto = $chkBajarCopiar.Checked -or $forzar
    if ($script:enMini -and $usarAuto) {
        $msg = if (Parece-Lista $c) {
            "Has copiado una lista (puede tener muchas canciones).`n`n¿Descargarla / añadirla a la cola?"
        } else {
            "Has copiado un enlace.`n`n¿Descargarlo / añadirlo a la cola?"
        }
        if (-not (Pregunta $msg)) { return }
        Encolar-O-Descargar @(Arreglar-Enlace $c)
        return
    }
    if (-not $script:enMini -and $script:modo -eq $null -and $script:pestanaActual -eq 1 -and $txtEnlace.Text.Trim() -eq '') {
        $txtEnlace.Text = $c
        Estado 'He pegado el enlace que tenías copiado. Pulsa Descargar.'
    }
}

$script:ultimoPortapapeles = ''
$timerClip = New-Object System.Windows.Forms.Timer
$timerClip.Interval = 800
$timerClip.Add_Tick({
    if (-not $chkBajarCopiar.Checked) { return }
    if (-not $script:enMini -and -not $form.Visible) { return }
    Intentar-Bajar-Desde-Portapapeles $false
})
$timerClip.Start()
#endregion Mini-Portapapeles

