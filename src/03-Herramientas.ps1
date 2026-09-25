#region Herramientas
# ================================================================
#  Descarga directa de herramientas (sin depender de winget)
# ================================================================
function Descargar-Http($url, $destino, $alProgreso = $null) {
    return Con-ErrorActionStop {
    # Streaming + espera con DoEvents para no congelar el popup (sobre todo al conectar).
    $cliente = New-Object System.Net.Http.HttpClient
    $cliente.Timeout = [TimeSpan]::FromMinutes(5)
    $cliente.DefaultRequestHeaders.UserAgent.ParseAdd('MusicDL/3.40')
    $cts = New-Object System.Threading.CancellationTokenSource
    $script:downloadCts = $cts
    try {
        if ($script:pop -and $script:pop.paso) {
            $script:pop.paso.Text = 'Conectando con GitHub...'
            if ($script:pop.pct) { $script:pop.pct.Text = '' }
            Poner-Popup-Barra $null
            Bombeo-Ui
        }

        $task = $cliente.GetAsync($url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cts.Token)
        while (-not $task.IsCompleted) {
            if ($script:popupCancelado) { try { $cts.Cancel() } catch { Catch-Log 'Descargar-Http' $_ }; return $false }
            try { [void]$task.Wait(200) } catch { break }
            Bombeo-Ui
        }
        if ($script:popupCancelado) { return $false }
        if ($task.IsCanceled) { return $false }
        if ($task.IsFaulted) { throw $task.Exception.GetBaseException() }
        $resp = $task.Result
        [void]$resp.EnsureSuccessStatusCode()
        $total = $resp.Content.Headers.ContentLength
        $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $fs = [IO.File]::Create($destino)
        try {
            $buf = New-Object byte[] 131072
            $leido = [long]0
            $ultimoUi = [datetime]::MinValue
            while ($true) {
                if ($script:popupCancelado) { try { $cts.Cancel() } catch { Catch-Log 'Descargar-Http' $_ }; return $false }
                $readTask = $stream.ReadAsync($buf, 0, $buf.Length, $cts.Token)
                while (-not $readTask.IsCompleted) {
                    if ($script:popupCancelado) { try { $cts.Cancel() } catch { Catch-Log 'Descargar-Http' $_ }; return $false }
                    try { [void]$readTask.Wait(200) } catch { break }
                    Bombeo-Ui
                }
                if ($readTask.IsCanceled) { return $false }
                if ($readTask.IsFaulted) { throw $readTask.Exception.GetBaseException() }
                $n = [int]$readTask.Result
                if ($n -le 0) { break }
                $fs.Write($buf, 0, $n)
                $leido += $n
                $ahora = Get-Date
                if (($ahora - $ultimoUi).TotalMilliseconds -ge 250) {
                    $ultimoUi = $ahora
                    if ($alProgreso) { try { & $alProgreso $leido $total } catch { Catch-Log 'Descargar-Http' $_ } }
                    Bombeo-Ui
                }
            }
            if ($alProgreso) { try { & $alProgreso $leido $total } catch { Catch-Log 'Descargar-Http' $_ } }
        } finally {
            try { $fs.Close() } catch {}
            try { $stream.Dispose() } catch {}
            try { $resp.Dispose() } catch {}
        }
        if ($script:popupCancelado) {
            try { Remove-Item -LiteralPath $destino -Force -ErrorAction SilentlyContinue } catch { Catch-Log 'Descargar-Http' $_ }
            return $false
        }
        return $true
    } catch {
        if (-not $script:popupCancelado) {
            Registrar-Error "Descarga $url : $($_.Exception.Message)"
        }
        try { Remove-Item -LiteralPath $destino -Force -ErrorAction SilentlyContinue } catch { Catch-Log 'Descargar-Http' $_ }
        return $false
    } finally {
        $script:downloadCts = $null
        try { $cts.Dispose() } catch {}
        $cliente.Dispose()
    }

    }
}

function Extraer-Zip-Selectivo($zipPath, $patronExe, $destinoExe) {
    return Con-ErrorActionStop {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    function Es-Entrada-Zip-Segura([string]$nombreEntrada, [string]$dirDestino) {
        if ([string]::IsNullOrWhiteSpace($nombreEntrada)) { return $false }
        $n = $nombreEntrada -replace '\\', '/'
        if ($n.Contains('..')) { return $false }
        if ($n -match '^[a-zA-Z]:' -or $n.StartsWith('/')) { return $false }
        $rel = ($n -replace '/', [IO.Path]::DirectorySeparatorChar)
        $full = [IO.Path]::GetFullPath((Join-Path $dirDestino $rel))
        $root = [IO.Path]::GetFullPath(($dirDestino.TrimEnd('\') + '\'))
        return $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)
    }
    function Extraer-Entrada-Zip($entry, $rutaSalida) {
        $dir = Split-Path -Parent $rutaSalida
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        $src = $entry.Open()
        try {
            $dst = [IO.File]::Create($rutaSalida)
            try { $src.CopyTo($dst) } finally { $dst.Dispose() }
        } finally { $src.Dispose() }
    }
    $tmp = Join-Path $dirApp ('tmp-extract-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $fs = $null
    $zip = $null
    try {
        $fs = [IO.File]::OpenRead($zipPath)
        $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Read)
        $entry = $zip.Entries | Where-Object {
            $_.Name -and (
                $_.Name -eq $patronExe -or
                $_.FullName.EndsWith('/' + $patronExe) -or
                $_.FullName.EndsWith('\' + $patronExe)
            )
        } | Select-Object -First 1
        if (-not $entry) { return $false }
        if (-not (Es-Entrada-Zip-Segura $entry.FullName $tmp)) {
            Registrar-Error "ZIP entrada insegura: $($entry.FullName)"
            return $false
        }
        $outExe = Join-Path $tmp $patronExe
        Extraer-Entrada-Zip $entry $outExe
        Copy-Item -LiteralPath $outExe -Destination $destinoExe -Force
        if ($patronExe -eq 'ffmpeg.exe') {
            $dirEntry = ($entry.FullName -replace '[\\/][^\\/]+$', '')
            foreach ($extra in @('ffprobe.exe', 'ffplay.exe')) {
                $sib = $zip.Entries | Where-Object {
                    $_.Name -eq $extra -and (($_.FullName -replace '[\\/][^\\/]+$', '') -eq $dirEntry)
                } | Select-Object -First 1
                if (-not $sib) { continue }
                if (-not (Es-Entrada-Zip-Segura $sib.FullName $tmp)) { continue }
                $sibOut = Join-Path $tmp $extra
                Extraer-Entrada-Zip $sib $sibOut
                Copy-Item -LiteralPath $sibOut -Destination (Join-Path $dirBin $extra) -Force
            }
        }
        return $true
    } catch {
        Registrar-Error "Extraer zip: $($_.Exception.Message)"
        return $false
    } finally {
        if ($zip) { try { $zip.Dispose() } catch {} }
        if ($fs) { try { $fs.Dispose() } catch {} }
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    }
}

function Instalar-Herramienta-Directa($h) {
    return Con-ErrorActionStop {
    $destino = Join-Path $dirBin $h.destino
    $tmp = Join-Path $dirApp ('dl-' + $h.cmd + '.tmp')
    $url = [string]$h.url
    if (-not $url -or -not $h.sha256) {
        Registrar-Error "Instalar $($h.cmd): falta url o sha256 en la tabla de herramientas"
        return $false
    }
    $script:dlNombrePieza = [string]$h.nombre
    $progreso = {
        param($leido, $total)
        if (-not $script:pop -or -not $script:pop.paso) { return }
        $nombrePieza = $script:dlNombrePieza
        $mb = [Math]::Round($leido / 1MB, 1)
        if ($total -and $total -gt 0) {
            $pct = [int]((100.0 * $leido) / [double]$total)
            if ($pct -gt 100) { $pct = 100 }
            $totMb = [Math]::Round(([double]$total) / 1MB, 1)
            $script:pop.paso.Text = "Descargando $nombrePieza...`n$mb / $totMb MB"
            if ($script:pop.pct) { $script:pop.pct.Text = "$pct %" }
            Poner-Popup-Barra $pct
        } else {
            $script:pop.paso.Text = "Descargando $nombrePieza...`n$mb MB (tamaño total desconocido)"
            if ($script:pop.pct) { $script:pop.pct.Text = "$mb MB" }
            Poner-Popup-Barra $null
        }
        try { $script:pop.paso.Refresh() } catch {}
        try { if ($script:pop.pct) { $script:pop.pct.Refresh() } } catch {}
        try { if ($script:pop.form) { $script:pop.form.Refresh() } } catch {}
    }
    if (-not (Descargar-Http $url $tmp $progreso)) { return $false }
    try {
        if ($script:pop -and $script:pop.paso) {
            $script:pop.paso.Text = "Comprobando integridad de $($script:dlNombrePieza)..."
            Bombeo-Ui
        }
        if (-not (Verificar-Sha256 $tmp $h.sha256)) {
            $script:falloIntegridad = $true
            $got = ''
            try { $got = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash } catch { Catch-Log 'Instalar-Herramienta-Directa' $_ }
            Registrar-Error "SHA256 inválido para $($h.cmd). Esperado=$($h.sha256) Obtenido=$got"
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            return $false
        }
        if ($h.tipo -eq 'exe') {
            if ($script:pop -and $script:pop.paso) {
                $script:pop.paso.Text = "Instalando $($script:dlNombrePieza)..."
                Bombeo-Ui
            }
            Move-Item -LiteralPath $tmp -Destination $destino -Force
            return $true
        }
        if ($h.tipo -eq 'zip-ffmpeg') {
            if ($script:pop -and $script:pop.paso) {
                $script:pop.paso.Text = "Extrayendo $($script:dlNombrePieza) (puede tardar)..."
                if ($script:pop.pct) { $script:pop.pct.Text = '' }
                Poner-Popup-Barra $null
                Bombeo-Ui
            }
            $ok = Extraer-Zip-Selectivo $tmp 'ffmpeg.exe' $destino
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            if ($ok -and $h.sha256exe -and -not (Verificar-Sha256 $destino $h.sha256exe)) {
                $script:falloIntegridad = $true
                Registrar-Error "SHA256 exe inválido para $($h.cmd) tras extraer ZIP"
                Remove-Item -LiteralPath $destino -Force -ErrorAction SilentlyContinue
                return $false
            }
            return $ok
        }
        if ($h.tipo -eq 'zip-deno') {
            if ($script:pop -and $script:pop.paso) {
                $script:pop.paso.Text = "Extrayendo $($script:dlNombrePieza)..."
                Bombeo-Ui
            }
            $ok = Extraer-Zip-Selectivo $tmp 'deno.exe' $destino
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            if ($ok -and $h.sha256exe -and -not (Verificar-Sha256 $destino $h.sha256exe)) {
                $script:falloIntegridad = $true
                Registrar-Error "SHA256 exe inválido para $($h.cmd) tras extraer ZIP"
                Remove-Item -LiteralPath $destino -Force -ErrorAction SilentlyContinue
                return $false
            }
            return $ok
        }
    } catch {
        Registrar-Error "Instalar $($h.cmd): $($_.Exception.Message)"
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        return $false
    }
    return $false

    }
}

function Poner-Popup-Barra($pct) {
    # $null = animación indefinida; 0..100 = progreso real
    if ($null -eq $pct) {
        $script:popupBarraPct = $null
        if ($script:popupAnimFill -and -not $script:popupAnimFill.IsDisposed) {
            $script:popupAnimFill.Width = 90
        }
        return
    }
    $v = [double]$pct
    if ($v -lt 0) { $v = 0 }
    if ($v -gt 100) { $v = 100 }
    $script:popupBarraPct = $v
    if ($script:popupAnimFill -and $script:popupAnimTrack -and -not $script:popupAnimFill.IsDisposed) {
        $w = [int]($script:popupAnimTrack.Width * $v / 100.0)
        if ($w -lt 6) { $w = 6 }
        $script:popupAnimFill.Left = 0
        $script:popupAnimFill.Width = [Math]::Min($w, $script:popupAnimTrack.Width)
    }
}

function Nuevo-Popup($titulo, $texto, $conCancelar = $false) {
    $p = New-Object System.Windows.Forms.Form
    # Sin AutoScale DPI: si no, en pantallas escaladas el título/texto se cortan
    $p.AutoScaleMode = 'None'
    $p.Text = 'MusicDL'
    $ancho = 620
    $alto = if ($conCancelar) { 380 } else { 320 }
    $p.ClientSize = New-Object System.Drawing.Size($ancho, $alto)
    $p.FormBorderStyle = 'FixedDialog'
    $p.ControlBox = $false
    $p.StartPosition = 'CenterScreen'
    $p.BackColor = $colPanel
    $p.ForeColor = $colTexto
    $p.Font = $fNormal
    if ($script:icono) { $p.Icon = $script:icono }

    $barraTop = New-Object System.Windows.Forms.Panel
    $barraTop.BackColor = $colAcento
    $barraTop.Location = New-Object System.Drawing.Point(0, 0)
    $barraTop.Size = New-Object System.Drawing.Size($ancho, 4)
    $p.Controls.Add($barraTop)

    if ($script:bmpIcono) {
        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image = $script:bmpIcono
        $pic.SizeMode = 'Zoom'
        $pic.Location = New-Object System.Drawing.Point(24, 20)
        $pic.Size = New-Object System.Drawing.Size(44, 44)
        $p.Controls.Add($pic)
    }
    $l1 = New-Object System.Windows.Forms.Label
    $l1.Text = $titulo
    $l1.Font = $fPopup
    $l1.ForeColor = $colTexto
    $l1.AutoSize = $false
    $l1.Location = New-Object System.Drawing.Point(80, 24)
    $l1.Size = New-Object System.Drawing.Size(520, 40)
    $p.Controls.Add($l1)

    $l2 = New-Object System.Windows.Forms.Label
    $l2.Text = $texto
    $l2.ForeColor = $colSuave
    $l2.Font = $fPequena
    $l2.Location = New-Object System.Drawing.Point(24, 78)
    $l2.Size = New-Object System.Drawing.Size(572, 70)
    $p.Controls.Add($l2)

    $l3 = New-Object System.Windows.Forms.Label
    $l3.Text = 'Empezando...'
    $l3.Font = $fNormal
    $l3.ForeColor = $colAcento
    $l3.Location = New-Object System.Drawing.Point(24, 164)
    $l3.Size = New-Object System.Drawing.Size(450, 48)
    $l3.AutoEllipsis = $false
    $p.Controls.Add($l3)

    $lblPct = New-Object System.Windows.Forms.Label
    $lblPct.Text = ''
    $lblPct.Font = $fEtiqueta
    $lblPct.ForeColor = $colSuave
    $lblPct.TextAlign = 'MiddleRight'
    $lblPct.Location = New-Object System.Drawing.Point(480, 172)
    $lblPct.Size = New-Object System.Drawing.Size(116, 32)
    $p.Controls.Add($lblPct)

    $track = New-Object System.Windows.Forms.Panel
    $track.Location = New-Object System.Drawing.Point(24, 224)
    $track.Size = New-Object System.Drawing.Size(572, 18)
    $track.BackColor = $colBorde
    $fill = New-Object System.Windows.Forms.Panel
    $fill.BackColor = $colAcento
    $fill.Location = New-Object System.Drawing.Point(0, 0)
    $fill.Size = New-Object System.Drawing.Size(90, 18)
    $track.Controls.Add($fill)
    $p.Controls.Add($track)

    $anim = New-Object System.Windows.Forms.Timer
    $anim.Interval = 40
    $script:popupAnimPos = 0
    $script:popupAnimDir = 1
    $script:popupAnimFill = $fill
    $script:popupAnimTrack = $track
    $script:popupBarraPct = $null
    $script:popupLblPct = $lblPct
    $anim.Add_Tick({
        if (-not $script:popupAnimFill -or $script:popupAnimFill.IsDisposed) { return }
        if ($null -ne $script:popupBarraPct) {
            $w = [int]($script:popupAnimTrack.Width * [double]$script:popupBarraPct / 100.0)
            if ($w -lt 6) { $w = 6 }
            $script:popupAnimFill.Left = 0
            $script:popupAnimFill.Width = [Math]::Min($w, $script:popupAnimTrack.Width)
            return
        }
        if ($script:popupAnimFill.Width -ne 90) { $script:popupAnimFill.Width = 90 }
        $max = $script:popupAnimTrack.Width - $script:popupAnimFill.Width
        if ($max -lt 1) { return }
        $script:popupAnimPos += (10 * $script:popupAnimDir)
        if ($script:popupAnimPos -ge $max) { $script:popupAnimPos = $max; $script:popupAnimDir = -1 }
        if ($script:popupAnimPos -le 0) { $script:popupAnimPos = 0; $script:popupAnimDir = 1 }
        $script:popupAnimFill.Left = [int]$script:popupAnimPos
    })
    $p.Add_Shown({
        try {
            if ($anim -and -not $anim.Enabled) { $anim.Start() }
        } catch {
            try { Registrar-Error "Popup anim Shown: $($_.Exception.Message)" } catch { Catch-Log 'Nuevo-Popup' $_ }
        }
    })
    $p.Add_FormClosed({
        try { if ($anim) { $anim.Stop(); $anim.Dispose() } } catch {}
        $script:popupAnimFill = $null
        $script:popupAnimTrack = $null
        $script:popupLblPct = $null
        $script:popupBarraPct = $null
    })

    $btnCancel = $null
    if ($conCancelar) {
        $btnCancel = Nuevo-Boton $p 'CANCELAR' 240 300 140 42
        $btnCancel.Add_Click({
            $script:popupCancelado = $true
            $script:popupOcupado = $false
            if ($script:downloadCts) {
                try { $script:downloadCts.Cancel() } catch { Catch-Log 'Nuevo-Popup' $_ }
            }
            if ($script:popupProc -and -not $script:popupProc.HasExited) {
                try {
                    Start-Process taskkill -ArgumentList "/PID $($script:popupProc.Id) /T /F" -WindowStyle Hidden -Wait
                } catch { Catch-Log 'Nuevo-Popup' $_ }
            }
            if ($script:pop -and $script:pop.paso) {
                try { $script:pop.paso.Text = 'Cancelando...' } catch { Catch-Log 'Nuevo-Popup' $_ }
            }
            if ($script:popupProc) {
                try { if ($script:pop) { $script:pop.form.Close() } } catch {}
            }
        })
    }

    $script:popupOcupado = $true
    $p.Add_FormClosing({ param($s, $e) if ($script:popupOcupado -and $e.CloseReason -eq 'UserClosing') { $e.Cancel = $true } })
    return @{ form = $p; paso = $l3; pct = $lblPct; cancelar = $btnCancel; anim = $anim }
}

function Mostrar-Popup-Encima($titulo, $texto) {
    $form.Enabled = $false
    $script:pop = Nuevo-Popup $titulo $texto
    $script:pop.form.StartPosition = 'Manual'
    $script:pop.form.ShowInTaskbar = $false
    $x = $form.Left + [int](($form.Width - $script:pop.form.Width) / 2)
    $y = $form.Top + [int](($form.Height - $script:pop.form.Height) / 2)
    $script:pop.form.Location = New-Object System.Drawing.Point($x, $y)
    $script:pop.form.Show($form)
}

function Cerrar-Popup {
    $script:popupOcupado = $false
    if ($script:pop) { try { $script:pop.form.Close() } catch {}; $script:pop = $null }
    try { if ($form -and -not $form.IsDisposed) { $form.Enabled = $true } } catch {}
}

function Instalar-Si-Falta {
    Refrescar-Path
    $falta = Faltan
    if ($falta.Count -eq 0) { return $true }

    $script:popupCancelado = $false
    $script:pop = Nuevo-Popup 'Preparando MusicDL' "Primera vez: se descargan yt-dlp, FFmpeg, Deno y spotDL.`nCada archivo se comprueba con SHA256 antes de instalarlo.`nFFmpeg ocupa ~100 MB. Puedes pulsar CANCELAR." $true
    # Capturas locales: en eventos de WinForms $script:pop a veces llega nulo y el Shown aborta sin descargar.
    $popForm = $script:pop.form
    $popPaso = $script:pop.paso
    $popPct = $script:pop.pct
    $popForm.ShowInTaskbar = $true
    $script:installStarted = $false
    $arrancarInstalacion = {
        if ($script:installStarted) { return }
        $script:installStarted = $true
        try {
            if ($popPaso -and -not $popPaso.IsDisposed) { $popPaso.Text = 'Iniciando instalación...' }
            if ($popPct -and -not $popPct.IsDisposed) { $popPct.Text = '' }
            Poner-Popup-Barra $null
            try { if ($popPaso) { $popPaso.Refresh() }; if ($popForm) { $popForm.Refresh() } } catch {}
        } catch {
            Registrar-Error "Instalación UI: $($_.Exception.Message)"
        }
        if ($script:timerInstalar) { try { $script:timerInstalar.Stop(); $script:timerInstalar.Dispose() } catch {} }
        $script:timerInstalar = New-Object System.Windows.Forms.Timer
        $script:timerInstalar.Interval = 80
        $script:timerInstalar.Add_Tick({
            try {
                if ($script:timerInstalar) { $script:timerInstalar.Stop(); $script:timerInstalar.Dispose(); $script:timerInstalar = $null }
            } catch {}
            try {
                $i = 0
                $todas = @($script:herramientas | Where-Object { -not (Ruta-De $_.cmd) })
                if ($todas.Count -eq 0) { $todas = @(Faltan) }
                $totalPasos = [Math]::Max($todas.Count, 1)
                foreach ($h in $todas) {
                    if ($script:popupCancelado) { break }
                    $i++
                    if ($script:pop -and $script:pop.paso) {
                        $script:pop.paso.Text = "Paso $i de $totalPasos : conectando ($($h.nombre))..."
                        if ($script:pop.pct) { $script:pop.pct.Text = '' }
                    }
                    Poner-Popup-Barra $null
                    try { if ($script:pop -and $script:pop.paso) { $script:pop.paso.Refresh() } } catch {}
                    Bombeo-Ui
                    $script:falloIntegridad = $false
                    $ok = Instalar-Herramienta-Directa $h
                    if ($script:popupCancelado) { break }
                    if (-not $ok) {
                        if ($script:falloIntegridad) {
                            Registrar-Error "Instalación abortada: integridad SHA256 fallida para $($h.cmd) (no se usa winget ni PATH sin pin)"
                        } else {
                            Registrar-Error "Instalación directa fallida para $($h.cmd) (solo URL pinneada + SHA256; sin winget)"
                        }
                    }
                    Refrescar-Path
                }
            } catch {
                Registrar-Error "Instalación: $($_.Exception.Message)"
            } finally {
                Cerrar-Popup
            }
        })
        $script:timerInstalar.Start()
    }
    $popForm.Add_Shown({
        try {
            & $arrancarInstalacion
        } catch {
            Registrar-Error "Instalación Shown: $($_.Exception.Message)"
            try { & $arrancarInstalacion } catch { Registrar-Error "Instalación retry: $($_.Exception.Message)"; try { Cerrar-Popup } catch { Catch-Log 'Instalar-Si-Falta' $_ } }
        }
    })
    # Respaldo: si Shown falla/no dispara, arrancar igual a los 200 ms
    $script:timerInstalarWatchdog = New-Object System.Windows.Forms.Timer
    $script:timerInstalarWatchdog.Interval = 200
    $script:timerInstalarWatchdog.Add_Tick({
        try { $script:timerInstalarWatchdog.Stop(); $script:timerInstalarWatchdog.Dispose(); $script:timerInstalarWatchdog = $null } catch {}
        if (-not $script:installStarted) {
            try { & $arrancarInstalacion } catch { Registrar-Error "Watchdog instalación: $($_.Exception.Message)" }
        }
    })
    $script:timerInstalarWatchdog.Start()
    [void]$popForm.ShowDialog()
    try { if ($script:timerInstalarWatchdog) { $script:timerInstalarWatchdog.Stop(); $script:timerInstalarWatchdog.Dispose(); $script:timerInstalarWatchdog = $null } } catch {}

    Refrescar-Path
    if ($script:popupCancelado) {
        [System.Windows.Forms.MessageBox]::Show(
            "Instalación cancelada.`n`nVuelve a abrir MusicDL cuando tengas internet (hace falta llegar a GitHub).",
            'MusicDL', 'OK', 'Information') | Out-Null
        return $false
    }
    $falta = Faltan
    if ($falta.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            (T `
                ("No se pudo instalar $($falta[0].nombre).`n`nComprueba internet (GitHub) y el antivirus.`nSi tu PC de empresa bloquea descargas, pide a informática que permita yt-dlp, FFmpeg, Deno y spotDL.`n`nDetalle en:`n$archErrores") `
                ("Could not install $($falta[0].nombre).`n`nCheck your internet (GitHub) and antivirus.`nIf a managed PC blocks downloads, ask IT to allow yt-dlp, FFmpeg, Deno and spotDL.`n`nDetails:`n$archErrores")),
            'MusicDL', 'OK', 'Warning') | Out-Null
        return $false
    }
    return $true
}

function Actualizar-Herramientas-Directas([switch]$Forzar) {
    # Reinstala yt-dlp fijado (URL+SHA256). Sin yt-dlp -U (descargaría sin nuestro pin).
    $stamp = Join-Path $dirApp 'ultimo-update-ytdlp.txt'
    if (-not $Forzar) {
        try {
            if (Test-Path -LiteralPath $stamp) {
                $rawStamp = (Get-Content -LiteralPath $stamp -Raw -ErrorAction SilentlyContinue)
                if ($rawStamp) {
                    $hace = (Get-Date) - [datetime]($rawStamp.Trim())
                    if ($hace.TotalHours -lt 20) {
                        $lblAct.Text = 'yt-dlp al día'
                        return
                    }
                }
            }
        } catch { Catch-Log 'Actualizar-Herramientas-Directas' $_ }
    }
    $lblAct.Text = 'Comprobando yt-dlp...'
    Bombeo-Ui
    $ok = $false
    $h = $script:herramientas | Where-Object { $_.cmd -eq 'yt-dlp' } | Select-Object -First 1
    if ($h) {
        $local = Join-Path $dirBin $h.destino
        if ((Test-Path -LiteralPath $local) -and (Verificar-Sha256 $local $h.sha256)) {
            $ok = $true
            $lblAct.Text = 'yt-dlp verificado'
        } else {
            $lblAct.Text = 'Actualizando yt-dlp...'
            Bombeo-Ui
            try { $ok = Instalar-Herramienta-Directa $h } catch {
                Registrar-Error "Actualizar yt-dlp (directa): $($_.Exception.Message)"
            }
        }
    }
    Refrescar-Path
    $script:versionYtdlp = $null
    $ver = Obtener-Version-Ytdlp
    try { Set-Content -LiteralPath $stamp -Value ((Get-Date).ToString('o')) -Encoding UTF8 } catch { Catch-Log 'Actualizar-Herramientas-Directas' $_ }
    if ($ok) {
        $lblAct.Text = "yt-dlp $ver"
    } else {
        $lblAct.Text = "yt-dlp $ver (sin actualizar)"
        Registrar-Error 'No se pudo verificar/actualizar yt-dlp con SHA256'
    }
}
#endregion Herramientas

