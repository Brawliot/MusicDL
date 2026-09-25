#region Elegir
# ================================================================
#  Elegir canciones
# ================================================================
function Elegir-Canciones {
    $enlaces = Leer-Enlaces
    if (-not (Comprobar-Enlaces $enlaces)) { return }
    if ($enlaces.Count -gt 1) { Aviso 'Para elegir canciones, deja un solo enlace de lista.'; return }
    if ((Tipo-Enlace $enlaces[0]) -eq 'spotify' -or $enlaces[0] -match '(?i)spotify') {
        Aviso "Con Spotify no se puede elegir canción a canción.`n`nPulsa Descargar: se emparejará la playlist/álbum completa en YouTube y se bajará."
        return
    }
    $ytdlp = Preparar-Ytdlp
    if (-not $ytdlp) { return }

    $url = Arreglar-Enlace $enlaces[0]
    $script:lectura = New-Object System.Collections.ArrayList
    $script:errLectura = $null
    $script:lecturaCancelada = $false
    $lstResultados.Items.Clear()
    Modo 'leyendo'
    Barra-Tarea 1
    Estado 'Leyendo las canciones de la lista...'
    $args2 = [string[]]@('--flat-playlist', '--color', 'never', '--encoding', 'utf-8', '--no-warnings', '--print', '%(playlist_index|0)s|||%(id)s|||%(title|)s', $url)
    $script:urlLectura = $url
    Iniciar-Tarea $ytdlp $args2 `
        {
            param($l)
            if ($l -match '^(\d+)\|\|\|(.*?)\|\|\|(.*)$') { [void]$script:lectura.Add(@{ idx = [int]$matches[1]; id = $matches[2]; titulo = $matches[3] }) }
            elseif ($l -match '^ERROR:') { $script:errLectura = Traducir-Error $l }
        } `
        { param($c) Fin-Lectura } 180 'lectura'
}

function Fin-Lectura {
    Modo $null
    Barra-Tarea 0
    if ($script:lecturaCancelada) { Estado 'Cancelado.'; return }
    $lista = @($script:lectura)
    if ($lista.Count -eq 0) {
        if ($script:errLectura) { Aviso "$($script:errLectura.origen): $($script:errLectura.texto)" 'Warning' }
        else { Aviso 'No se ha podido leer la lista.' 'Warning' }
        Estado 'Listo.'
        return
    }
    if ($lista.Count -eq 1 -or $lista[0].idx -eq 0) {
        Encolar-O-Descargar @($script:urlLectura)
        return
    }
    $elegidas = Mostrar-Selector $lista
    if ($null -eq $elegidas) { Estado 'Listo.'; return }
    if ($elegidas.Count -eq 0) { Estado 'No has marcado ninguna canción.'; return }
    $indices = if ($elegidas.Count -eq $lista.Count) { '' } else { ($elegidas -join ',') }
    Encolar-O-Descargar @($script:urlLectura) $false $indices
}

function Mostrar-Selector($lista) {
    $ya = Ids-Descargados
    $f = New-Object System.Windows.Forms.Form
    Escalar-Dpi $f
    $f.Text = 'Elegir canciones'
    $f.ClientSize = New-Object System.Drawing.Size(520, 560)
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterParent'
    $f.BackColor = $colPanel; $f.ForeColor = $colTexto; $f.Font = $fNormal
    if ($script:icono) { $f.Icon = $script:icono }

    Nueva-Etiqueta $f 'MARCA LAS CANCIONES' 16 14 488 22 $fEtiqueta $colAcento | Out-Null
    $lblCuenta = Nueva-Etiqueta $f '' 16 40 488 22 $fNormal $colSuave

    $cl = New-Object System.Windows.Forms.CheckedListBox
    $cl.Location = New-Object System.Drawing.Point(16, 68)
    $cl.Size = New-Object System.Drawing.Size(488, 400)
    $cl.CheckOnClick = $true
    $cl.BorderStyle = 'FixedSingle'
    $cl.IntegralHeight = $false
    $cl.BackColor = $colCampo
    $cl.ForeColor = $colTexto
    $cl.DrawMode = 'OwnerDrawFixed'
    $cl.ItemHeight = 28
    $cl.Add_DrawItem({
        param($s, $e)
        if ($e.Index -lt 0) { return }
        $g = $e.Graphics
        $g.SmoothingMode = 'AntiAlias'
        $marcado = $s.GetItemChecked($e.Index)
        $sel = (($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0)
        $fondo = if ($sel) { $colHover } else { $colCampo }
        $brF = New-Object System.Drawing.SolidBrush $fondo
        $g.FillRectangle($brF, $e.Bounds)
        $brF.Dispose()
        $box = New-Object System.Drawing.Rectangle(($e.Bounds.X + 6), ($e.Bounds.Y + 6), 16, 16)
        $bg = if ($marcado) { $colAcento } else { $colPanel }
        $brB = New-Object System.Drawing.SolidBrush $bg
        $g.FillRectangle($brB, $box)
        $brB.Dispose()
        $pen = New-Object System.Drawing.Pen $(if ($marcado) { $colAcento } else { $colSuave }), 1.5
        $g.DrawRectangle($pen, $box)
        $pen.Dispose()
        if ($marcado) {
            $pen2 = New-Object System.Drawing.Pen $colBlanco, 2.0
            $pen2.StartCap = 'Round'; $pen2.EndCap = 'Round'
            $ox = $box.X; $oy = $box.Y
            $g.DrawLines($pen2, @(
                (New-Object System.Drawing.Point(($ox + 3), ($oy + 8))),
                (New-Object System.Drawing.Point(($ox + 6), ($oy + 12))),
                (New-Object System.Drawing.Point(($ox + 13), ($oy + 4)))
            ))
            $pen2.Dispose()
        }
        $brT = New-Object System.Drawing.SolidBrush $colTexto
        $tr = New-Object System.Drawing.Rectangle(($e.Bounds.X + 28), $e.Bounds.Y, ($e.Bounds.Width - 32), $e.Bounds.Height)
        $sf = New-Object System.Drawing.StringFormat
        $sf.LineAlignment = 'Center'
        $sf.Trimming = 'EllipsisCharacter'
        $g.DrawString([string]$s.Items[$e.Index], $s.Font, $brT, $tr, $sf)
        $brT.Dispose(); $sf.Dispose()
    })
    $f.Controls.Add($cl)
    foreach ($x in $lista) {
        $t = if ($x.titulo) { $x.titulo } else { "Canción $($x.idx)" }
        $etiqueta = ('{0:00}   {1}' -f $x.idx, $t)
        $tiene = $ya.ContainsKey($x.id)
        if ($tiene) { $etiqueta += '   (ya la tienes en este formato)' }
        [void]$cl.Items.Add($etiqueta, $false)
    }
    $cl.Add_ItemCheck({ param($s, $e)
        $n = $cl.CheckedItems.Count + $(if ($e.NewValue -eq 'Checked') { 1 } else { -1 })
        $lblCuenta.Text = "$n de $($cl.Items.Count) marcadas"
        try { $cl.Invalidate() } catch { Catch-Log 'Mostrar-Selector' $_ }
    })
    $lblCuenta.Text = "$($cl.CheckedItems.Count) de $($cl.Items.Count) marcadas"

    $bTodas = Nuevo-Boton $f 'Marcar todas' 16 480 120 34
    $bTodas.Add_Click({ for ($i = 0; $i -lt $cl.Items.Count; $i++) { $cl.SetItemChecked($i, $true) } })
    $bNinguna = Nuevo-Boton $f 'Ninguna' 144 480 100 34
    $bNinguna.Add_Click({ for ($i = 0; $i -lt $cl.Items.Count; $i++) { $cl.SetItemChecked($i, $false) } })

    $bOk = Nuevo-BotonPrincipal $f 'DESCARGAR MARCADAS' 16 520 330 34 $fBotonMed
    $bOk.DialogResult = 'OK'
    $bCancel = Nuevo-Boton $f 'CANCELAR' 354 520 150 34
    $bCancel.DialogResult = 'Cancel'
    $f.AcceptButton = $bOk; $f.CancelButton = $bCancel

    $owner = if ($script:enMini) { $formMini } else { $form }
    if ($f.ShowDialog($owner) -ne 'OK') { return $null }
    $sel = New-Object System.Collections.ArrayList
    foreach ($i in $cl.CheckedIndices) { [void]$sel.Add($lista[$i].idx) }
    return ,$sel
}
#endregion Elegir

