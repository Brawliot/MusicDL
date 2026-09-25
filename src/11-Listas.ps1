#region Listas
# ================================================================
#  Mis listas
# ================================================================
function Pintar-Listas {
    $lvListas.Items.Clear()
    foreach ($x in $script:listas) {
        $nombre = if ($x.nombre) { $x.nombre } else { '(nombre al actualizarla)' }
        $it = New-Object System.Windows.Forms.ListViewItem($nombre)
        [void]$it.SubItems.Add($(if ($x.ultima) { $x.ultima } else { 'Nunca' }))
        [void]$it.SubItems.Add($(if ($x.ultima) { $x.nuevas } else { '' }))
        [void]$it.SubItems.Add($x.url)
        $it.Tag = $x
        [void]$lvListas.Items.Add($it)
    }
    if ($script:listas.Count -eq 0) { $lblListas.Text = 'Todavía no tienes listas guardadas.' }
    else { $lblListas.Text = (Plural $script:listas.Count 'lista guardada.' 'listas guardadas.') }
}

function Anadir-Lista {
    $u = $txtNuevaLista.Text.Trim()
    if (-not $u) { $u = (Leer-Portapapeles).Trim() }
    if (-not $u) { $lblListas.Text = 'Pega primero el enlace de una lista.'; return }
    if (-not (Es-Enlace-Valido $u)) { Aviso "Enlace no válido:`n`n$u" 'Warning'; return }
    $u = Arreglar-Enlace $u
    $k = Clave-Enlace $u
    if (@($script:listas | Where-Object { (Clave-Enlace $_.url) -eq $k }).Count -gt 0) { $lblListas.Text = 'Esa lista ya está guardada.'; return }
    [void]$script:listas.Add([pscustomobject]@{ url = $u; nombre = ''; ultima = ''; nuevas = '' })
    $txtNuevaLista.Clear()
    Guardar-Config
    Pintar-Listas
    $lblListas.Text = 'Lista añadida. Pulsa Actualizar para bajarla.'
}

function Listas-Elegidas { return @($lvListas.SelectedItems | ForEach-Object { $_.Tag }) }
#endregion Listas

