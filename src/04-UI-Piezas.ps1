#region UI-Piezas
# ================================================================
#  Piezas de la interfaz
# ================================================================
function Nueva-Etiqueta($padre, $texto, $x, $y, $ancho, $alto, $fuente, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $texto
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($ancho, $alto)
    $l.Font = $fuente
    $l.ForeColor = $color
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.AccessibleName = [string]$texto
    $padre.Controls.Add($l)
    return $l
}

function Nuevo-Boton($padre, $texto, $x, $y, $ancho, $alto) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $texto
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($ancho, $alto)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = $colBorde
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.MouseOverBackColor = $colHover
    $b.FlatAppearance.MouseDownBackColor = $colBorde
    $b.BackColor = $colPanel
    $b.ForeColor = $colTexto
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.AccessibleName = [string]$texto
    $b.AccessibleDescription = [string]$texto
    $b.TabStop = $true
    $padre.Controls.Add($b)
    return $b
}

function Nuevo-BotonPrincipal($padre, $texto, $x, $y, $ancho, $alto, $fuente) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $texto
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($ancho, $alto)
    $b.Font = $fuente
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $colAcento
    $b.FlatAppearance.MouseOverBackColor = $colAcentoOsc
    $b.FlatAppearance.MouseDownBackColor = $colAcentoOsc
    $b.ForeColor = $colBlanco
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.AccessibleName = [string]$texto
    $b.AccessibleDescription = [string]$texto
    $b.TabStop = $true
    $padre.Controls.Add($b)
    return $b
}

function Nueva-Casilla($padre, $texto, $x, $y, $marcada, $ancho) {
    # CheckBox plano de WinForms casi no se ve en tema oscuro: caja + visto dibujados a mano.
    $estado = New-Object psobject
    Add-Member -InputObject $estado -NotePropertyName _checked -NotePropertyValue ([bool]$marcada)
    Add-Member -InputObject $estado -NotePropertyName _handlers -NotePropertyValue (New-Object System.Collections.ArrayList)
    Add-Member -InputObject $estado -NotePropertyName Caja -NotePropertyValue $null
    Add-Member -InputObject $estado -NotePropertyName Etiqueta -NotePropertyValue $null
    Add-Member -InputObject $estado -NotePropertyName Wrap -NotePropertyValue $null

    $fondo = try { $padre.BackColor } catch { $colPanel }

    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Location = New-Object System.Drawing.Point($x, $y)
    $wrap.Size = New-Object System.Drawing.Size($ancho, 26)
    $wrap.BackColor = $fondo
    $wrap.Cursor = [System.Windows.Forms.Cursors]::Hand

    $caja = New-Object System.Windows.Forms.Panel
    $caja.Location = New-Object System.Drawing.Point(0, 4)
    $caja.Size = New-Object System.Drawing.Size(18, 18)
    $caja.BackColor = $colCampo
    $caja.Cursor = [System.Windows.Forms.Cursors]::Hand

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $texto
    $lbl.Location = New-Object System.Drawing.Point(26, 3)
    $lbl.Size = New-Object System.Drawing.Size([Math]::Max(40, $ancho - 28), 20)
    $lbl.ForeColor = $colTexto
    $lbl.BackColor = $fondo
    $lbl.Font = $fNormal
    $lbl.Cursor = [System.Windows.Forms.Cursors]::Hand

    $estado.Caja = $caja
    $estado.Etiqueta = $lbl
    $estado.Wrap = $wrap
    $wrap.Tag = $estado
    $caja.Tag = $estado
    $lbl.Tag = $estado
    $wrap.AccessibleName = [string]$texto
    $wrap.AccessibleRole = [System.Windows.Forms.AccessibleRole]::CheckButton
    $lbl.AccessibleName = [string]$texto
    $caja.AccessibleName = [string]$texto
    $wrap.TabStop = $true

    $caja.Add_Paint({
        param($s, $e)
        $est = $s.Tag
        if (-not $est) { return }
        $g = $e.Graphics
        $g.SmoothingMode = 'AntiAlias'
        $g.PixelOffsetMode = 'HighQuality'
        $r = New-Object System.Drawing.Rectangle(1, 1, ($s.Width - 3), ($s.Height - 3))
        $bg = if ($est._checked) { $colAcento } else { $colCampo }
        $br = New-Object System.Drawing.SolidBrush $bg
        $g.FillRectangle($br, $r)
        $br.Dispose()
        $borde = if ($est._checked) { $colAcento } else { $colSuave }
        $pen = New-Object System.Drawing.Pen $borde, 1.5
        $g.DrawRectangle($pen, $r)
        $pen.Dispose()
        if ($est._checked) {
            $pen2 = New-Object System.Drawing.Pen $colBlanco, 2.0
            $pen2.StartCap = 'Round'
            $pen2.EndCap = 'Round'
            $pen2.LineJoin = 'Round'
            $g.DrawLines($pen2, @(
                (New-Object System.Drawing.Point(4, 9)),
                (New-Object System.Drawing.Point(7, 13)),
                (New-Object System.Drawing.Point(14, 5))
            ))
            $pen2.Dispose()
        }
    })

    $toggle = {
        param($sender, $e)
        $est = $sender.Tag
        if (-not $est -or -not $est.Wrap -or -not $est.Wrap.Enabled) { return }
        $est.Checked = -not $est._checked
    }
    $wrap.Add_Click($toggle)
    $caja.Add_Click($toggle)
    $lbl.Add_Click($toggle)
    $wrap.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq 'Space' -or $e.KeyCode -eq 'Enter') {
            $e.SuppressKeyPress = $true
            & $toggle $s $e
        }
    })

    Add-Member -InputObject $estado -MemberType ScriptProperty -Name Checked -Value {
        return [bool]$this._checked
    } -SecondValue {
        param($v)
        $nv = [bool]$v
        if ($this._checked -eq $nv) {
            if ($this.Caja -and -not $this.Caja.IsDisposed) { $this.Caja.Invalidate() }
            return
        }
        $this._checked = $nv
        if ($this.Caja -and -not $this.Caja.IsDisposed) { $this.Caja.Invalidate() }
        foreach ($h in @($this._handlers)) {
            try { & $h $this ([EventArgs]::Empty) } catch { Catch-Log 'Nueva-Casilla' $_ }
        }
    }

    Add-Member -InputObject $estado -MemberType ScriptProperty -Name Enabled -Value {
        return [bool]$this.Wrap.Enabled
    } -SecondValue {
        param($v)
        $en = [bool]$v
        $this.Wrap.Enabled = $en
        $this.Caja.Enabled = $en
        $this.Etiqueta.Enabled = $en
        $this.Etiqueta.ForeColor = $(if ($en) { $colTexto } else { $colTenue })
        if ($this.Caja -and -not $this.Caja.IsDisposed) { $this.Caja.Invalidate() }
    }

    Add-Member -InputObject $estado -MemberType ScriptMethod -Name Add_CheckedChanged -Value {
        param($handler)
        if ($handler) { [void]$this._handlers.Add($handler) }
    }

    $wrap.Controls.Add($caja)
    $wrap.Controls.Add($lbl)
    $padre.Controls.Add($wrap)
    return $estado
}

function Nuevo-Combo($padre, $x, $y, $ancho, $opciones, $sel) {
    # Dropdown 100% oscuro (el ComboBox de Windows deja la flecha blanca)
    $idx = [Math]::Min([Math]::Max([int]$sel, 0), $opciones.Count - 1)
    $estado = New-Object psobject
    Add-Member -InputObject $estado -NotePropertyName SelectedIndex -NotePropertyValue $idx
    Add-Member -InputObject $estado -NotePropertyName Opciones -NotePropertyValue @($opciones)
    Add-Member -InputObject $estado -NotePropertyName Boton -NotePropertyValue $null
    Add-Member -InputObject $estado -NotePropertyName Wrap -NotePropertyValue $null
    Add-Member -InputObject $estado -NotePropertyName Drop -NotePropertyValue $null
    Add-Member -InputObject $estado -NotePropertyName CerrarSinReabrir -NotePropertyValue $false
    Add-Member -InputObject $estado -NotePropertyName AlCambiar -NotePropertyValue $null

    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Location = New-Object System.Drawing.Point($x, $y)
    $wrap.Size = New-Object System.Drawing.Size($ancho, 34)
    $wrap.BackColor = $colBorde
    $estado.Wrap = $wrap

    $btn = New-Object System.Windows.Forms.Button
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.MouseOverBackColor = $colHover
    $btn.Location = New-Object System.Drawing.Point(1, 1)
    $btn.Size = New-Object System.Drawing.Size(($ancho - 2), 32)
    $btn.BackColor = $colCampo
    $btn.ForeColor = $colTexto
    $btn.Font = $fNormal
    $btn.TextAlign = 'MiddleLeft'
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Text = "  $($opciones[$idx])"
    $estado.Boton = $btn
    $btn.AccessibleName = (T 'Lista desplegable' 'Drop-down list')
    $btn.AccessibleDescription = [string]$opciones[$idx]
    $btn.TabStop = $true

    $flecha = New-Object System.Windows.Forms.Label
    $flecha.Text = [string][char]0x25BE
    $flecha.ForeColor = $colAcento
    $flecha.BackColor = $colCampo
    $flecha.TextAlign = 'MiddleCenter'
    $flecha.Size = New-Object System.Drawing.Size(28, 32)
    $flecha.Location = New-Object System.Drawing.Point(($ancho - 30), 1)
    $flecha.Cursor = [System.Windows.Forms.Cursors]::Hand

    $wrap.Tag = $estado
    $btn.Tag = $estado
    $flecha.Tag = $estado

    $antesDeClick = {
        param($sender, $e)
        $est = $sender.Tag
        if (-not $est) { $est = $sender.Parent.Tag }
        if ($est -and $est.Drop -and $est.Drop.Visible) {
            $est.CerrarSinReabrir = $true
        }
    }
    $abrirLista = {
        param($sender, $e)
        $est = $sender.Tag
        if (-not $est) { $est = $sender.Parent.Tag }
        if (-not $est -or -not $est.Boton.Enabled) { return }
        # Clic en flecha/botón con la lista abierta: AutoClose ya la cerró → no reabrir
        if ($est.CerrarSinReabrir) {
            $est.CerrarSinReabrir = $false
            return
        }
        if ($est.Drop -and -not $est.Drop.IsDisposed -and $est.Drop.Visible) {
            $est.Drop.Close()
            return
        }
        if ($script:comboDrop -and -not $script:comboDrop.IsDisposed -and $script:comboDrop.Visible) {
            try { $script:comboDrop.Close() } catch {}
        }

        $marco = $est.Boton.Parent
        $altoItem = 30
        $altoLista = [Math]::Min(280, ($est.Opciones.Count * $altoItem) + 2)

        $lb = New-Object System.Windows.Forms.ListBox
        $lb.BorderStyle = 'None'
        $lb.BackColor = $colCampo
        $lb.ForeColor = $colTexto
        $lb.Font = $fNormal
        $lb.IntegralHeight = $false
        $lb.ItemHeight = $altoItem
        $lb.Size = New-Object System.Drawing.Size(($marco.Width - 2), $altoLista)
        foreach ($o in $est.Opciones) { [void]$lb.Items.Add($o) }
        $lb.SelectedIndex = $est.SelectedIndex

        $drop = New-Object System.Windows.Forms.ToolStripDropDown
        $drop.Padding = New-Object System.Windows.Forms.Padding(0)
        $drop.Margin = New-Object System.Windows.Forms.Padding(0)
        $drop.BackColor = $colBorde
        $drop.AutoClose = $true
        $drop.DropShadowEnabled = $true
        $hostCtrl = New-Object System.Windows.Forms.ToolStripControlHost($lb)
        $hostCtrl.Margin = New-Object System.Windows.Forms.Padding(1)
        $hostCtrl.Padding = New-Object System.Windows.Forms.Padding(0)
        $hostCtrl.AutoSize = $false
        $hostCtrl.Size = New-Object System.Drawing.Size($marco.Width, ($altoLista + 2))
        [void]$drop.Items.Add($hostCtrl)

        $lb.Tag = @{ est = $est; drop = $drop }
        $elegir = {
            param($s2, $e2)
            $info = $s2.Tag
            if ($s2.SelectedIndex -ge 0) {
                $info.est.SelectedIndex = $s2.SelectedIndex
                $info.est.Boton.Text = "  $($info.est.Opciones[$info.est.SelectedIndex])"
                if ($info.est.AlCambiar) {
                    try { & $info.est.AlCambiar $info.est.SelectedIndex } catch { Catch-Log 'Nuevo-Combo' $_ }
                }
            }
            $info.drop.Close()
        }
        $lb.Add_Click($elegir)
        $lb.Add_KeyDown({
            param($s2, $e2)
            $info = $s2.Tag
            if ($e2.KeyCode -eq 'Enter') { & $elegir $s2 $e2 }
            elseif ($e2.KeyCode -eq 'Escape') { $info.drop.Close() }
        })
        $drop.Add_Closed({
            $est.Drop = $null
            if ($script:comboDrop -eq $drop) { $script:comboDrop = $null }
        })

        $est.Drop = $drop
        $script:comboDrop = $drop
        if ($script:hayWin) {
            try { [DMWin]::TemaOscuro($lb.Handle) } catch { Catch-Log 'Nuevo-Combo' $_ }
        }
        $drop.Show($marco, (New-Object System.Drawing.Point(0, $marco.Height)))
        $lb.Focus()
    }
    $btn.Add_MouseDown($antesDeClick)
    $flecha.Add_MouseDown($antesDeClick)
    $btn.Add_Click($abrirLista)
    $flecha.Add_Click($abrirLista)

    Add-Member -InputObject $estado -MemberType ScriptProperty -Name Enabled -Value {
        return $this.Boton.Enabled
    } -SecondValue {
        param($v)
        $this.Boton.Enabled = [bool]$v
    } -Force

    $wrap.Controls.Add($btn)
    $wrap.Controls.Add($flecha)
    $flecha.BringToFront()
    $padre.Controls.Add($wrap)
    return $estado
}

function Nuevo-Enlace($padre, $texto, $x, $y, $ancho, $alineado) {
    $l = New-Object System.Windows.Forms.LinkLabel
    $l.Text = $texto
    $l.TextAlign = $alineado
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($ancho, 24)
    $l.LinkColor = $colAcento
    $l.ActiveLinkColor = $colAviso
    $l.VisitedLinkColor = $colAcento
    $l.BackColor = [System.Drawing.Color]::Transparent
    $padre.Controls.Add($l)
    return $l
}

function Nuevo-Campo($padre, $x, $y, $ancho, $alto, $multi = $false) {
    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Location = New-Object System.Drawing.Point($x, $y)
    $wrap.Size = New-Object System.Drawing.Size($ancho, $alto)
    $wrap.BackColor = $colBorde
    $t = New-Object System.Windows.Forms.TextBox
    $t.BorderStyle = 'None'
    $t.Location = New-Object System.Drawing.Point(2, 2)
    $t.Size = New-Object System.Drawing.Size(($ancho - 4), ($alto - 4))
    $t.BackColor = $colCampo
    $t.ForeColor = $colTexto
    $t.Font = $fNormal
    $t.AccessibleName = if ($multi) { (T 'Campo de enlaces' 'Links field') } else { (T 'Campo de texto' 'Text field') }
    $t.TabStop = $true
    if ($multi) {
        $t.Multiline = $true
        $t.ScrollBars = 'Vertical'
        $t.AcceptsReturn = $true
    } else {
        $t.Multiline = $true
        $t.ScrollBars = 'None'
        $t.WordWrap = $false
        $t.AcceptsReturn = $false
        $t.Add_KeyDown({
            param($s, $e)
            if ($e.KeyCode -eq 'Enter') { $e.SuppressKeyPress = $true }
        })
    }
    $t.Add_HandleCreated({
        if ($script:hayWin) { try { [DMWin]::TemaOscuro($t.Handle) } catch { Catch-Log 'Nuevo-Campo' $_ } }
    })
    $wrap.Controls.Add($t)
    $padre.Controls.Add($wrap)
    return $t
}

function Nueva-BarraProgreso($padre, $x, $y, $ancho, $alto) {
    $track = New-Object System.Windows.Forms.Panel
    $track.Location = New-Object System.Drawing.Point($x, $y)
    $track.Size = New-Object System.Drawing.Size($ancho, $alto)
    $track.BackColor = $colBorde
    $fill = New-Object System.Windows.Forms.Panel
    $fill.Location = New-Object System.Drawing.Point(0, 0)
    $fill.Size = New-Object System.Drawing.Size(0, $alto)
    $fill.BackColor = $colAcento
    $track.Controls.Add($fill)
    $padre.Controls.Add($track)
    return @{ track = $track; fill = $fill; max = 1000; value = 0; ancho = $ancho; alto = $alto }
}

function Set-BarraValor($b, $valor) {
    if (-not $b) { return }
    $v = [int][Math]::Min([Math]::Max($valor, 0), $b.max)
    $b.value = $v
    $w = [int](($b.ancho * $v) / $b.max)
    $b.fill.Width = [Math]::Max(0, $w)
}

# Nuevo-Campo devuelve el TextBox; Location/Size reales viven en el Panel padre (borde).
function Fijar-CampoCaja($campo, $x, $y, $ancho, $alto) {
    if (-not $campo -or $campo.IsDisposed) { return }
    $wrap = $campo.Parent
    if (-not $wrap -or $wrap.IsDisposed) { return }
    $wrap.Location = New-Object System.Drawing.Point($x, $y)
    $wrap.Size = New-Object System.Drawing.Size($ancho, $alto)
    $campo.Location = New-Object System.Drawing.Point(2, 2)
    $campo.Size = New-Object System.Drawing.Size([Math]::Max(10, $ancho - 4), [Math]::Max(10, $alto - 4))
}
function Nuevo-ListBoxOscuro($padre, $x, $y, $ancho, $alto) {
    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Location = New-Object System.Drawing.Point($x, $y)
    $wrap.Size = New-Object System.Drawing.Size($ancho, $alto)
    $wrap.BackColor = $colBorde
    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location = New-Object System.Drawing.Point(1, 1)
    $lb.Size = New-Object System.Drawing.Size(($ancho - 2), ($alto - 2))
    $lb.BorderStyle = 'None'
    $lb.Font = $fMono
    $lb.IntegralHeight = $false
    $lb.HorizontalScrollbar = $true
    $lb.BackColor = $colCampo
    $lb.ForeColor = $colExito
    $lb.Add_HandleCreated({
        if ($script:hayWin) { try { [DMWin]::TemaOscuro($lb.Handle) } catch { Catch-Log 'Nuevo-ListBoxOscuro' $_ } }
    })
    $wrap.Controls.Add($lb)
    $padre.Controls.Add($wrap)
    return $lb
}
#endregion UI-Piezas

