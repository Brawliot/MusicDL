#region UI-Mini
# ================================================================
#  Ventana mini
# ================================================================
$formMini = New-Object System.Windows.Forms.Form
Escalar-Dpi $formMini
$formMini.Text = 'MusicDL (mini)'
$formMini.ClientSize = New-Object System.Drawing.Size(460, 320)
$formMini.FormBorderStyle = 'FixedSingle'
$formMini.MaximizeBox = $false
$formMini.StartPosition = 'Manual'
$formMini.BackColor = $colFondo
$formMini.ForeColor = $colTexto
$formMini.Font = $fNormal
$formMini.ShowInTaskbar = $true

$miniBar = New-Object System.Windows.Forms.Panel
$miniBar.BackColor = $colAcento
$miniBar.Dock = 'Top'
$miniBar.Height = 3
$formMini.Controls.Add($miniBar)

Nueva-Etiqueta $formMini 'MusicDL' 18 18 300 28 $fMiniTit $colTexto | Out-Null
$btnExpandir = Nuevo-Boton $formMini 'GRANDE' 350 16 90 30
$chkBajarCopiar = Nueva-Casilla $formMini 'Al copiar enlace, preguntar antes de descargar (Mini)' 18 56 $config.bajarAlCopiar 420
$txtMini = Nuevo-Campo $formMini 18 94 250 34 $false
$btnMiniDl = Nuevo-BotonPrincipal $formMini 'AÑADIR' 278 94 80 34 $fBotonMed
$btnMiniCancel = Nuevo-Boton $formMini 'CANCELAR' 364 94 78 34
$btnMiniCancel.Enabled = $false
$lstMiniCola = Nuevo-ListBoxOscuro $formMini 18 142 422 100
$barraMini = Nueva-BarraProgreso $formMini 18 256 422 10
$lblMiniEstado = Nueva-Etiqueta $formMini 'Listo.' 18 276 422 30 $fPequena $colTexto
#endregion UI-Mini

