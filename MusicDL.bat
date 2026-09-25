<# :
@echo off
REM ================================================================
REM  MusicDL - aplicacion abierta y legible (no malware).
REM  Este .bat solo arranca PowerShell para mostrar la ventana.
REM  Codigo fuente completo debajo; sin ofuscacion.
REM ================================================================
set "DM_BAT=%~f0"
set "DM_DIR=%APPDATA%\DescargarMusica"
if not exist "%DM_DIR%" mkdir "%DM_DIR%" >nul 2>&1

REM Si una actualizacion anterior no llego a arrancar, restaurar la version previa
if exist "%DM_DIR%\esperando-arranque.flag" (
  if exist "%DM_DIR%\prev-version.bat" (
    copy /y "%DM_DIR%\prev-version.bat" "%DM_BAT%" >nul
    echo Restaurado automaticamente tras un fallo de actualizacion. > "%DM_DIR%\errores.log"
  )
  del /f /q "%DM_DIR%\esperando-arranque.flag" >nul 2>&1
  del /f /q "%DM_DIR%\update-pending.flag" >nul 2>&1
)
if exist "%DM_DIR%\update-pending.flag" (
  echo. > "%DM_DIR%\esperando-arranque.flag"
)

start "" powershell -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -Command "iex ([IO.File]::ReadAllText($env:DM_BAT, [Text.Encoding]::UTF8))"
exit /b
#>

# ================================================================
#  Descargar música  -  YouTube, SoundCloud y Spotify (spotDL)  (v3.8)
#  Usa yt-dlp, FFmpeg, Deno y spotDL (instalación directa; winget como respaldo).
#  Actualizaciones firmadas con clave RSA del autor.
# ================================================================

$versionApp = '3.8'
# Enlace Raw del .bat en GitHub. Si está vacío, no busca versiones nuevas.
$urlApp = 'https://raw.githubusercontent.com/Brawliot/MusicDL/main/MusicDL.bat'
# Enlace Raw de la firma (.sig). Si vacío, se usa $urlApp + '.sig'
$urlFirma = ''

# Clave pública RSA (XML). Solo el autor tiene la privada (clave-privada.xml).
$clavePublicaXml = '<RSAKeyValue><Modulus>po2BhuG7eWT/bc65ZUh8QesDy5VFoG1+xU77YmW9OLWU+w0kZx0N7MfzAD4pSZleTbv3gxm9UwTFFSuApEDlsDYAYemd5WgMU70TgoXV7cEbX/DuvBwRo34ezCCjDafcRkpL5T3cXj1vNcZPIiCOpw1UzjPzUlFT8+fIjsBocmVSat1aKlfZWUXpQtEsF0OgMo1mL+lPMV15RyKUOGZB/QOg0JnUvTux2ywGUQtOo7uvYQN1Cl08X7iKpAObJZXny2Nu2BbDIAYj+IURvvZF3EVArkzhWtNjUSgf2/5e1GD/jTWJeVYbkRnG19fsc2TGonwxZdEGM8aCD0y6ULoVSQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

# ---------- Una sola instancia ----------
$script:mutex = $null
try {
    $created = $false
    $script:mutex = New-Object System.Threading.Mutex($true, 'Global\DescargarMusica.SingleInstance', [ref]$created)
    if (-not $created) {
        Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class DMBring {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lp, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
    public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
    public static void FocusApp() {
        EnumWindows((h, l) => {
            var sb = new System.Text.StringBuilder(256);
            GetWindowText(h, sb, 256);
            string t = sb.ToString();
            if (t == "Descargar música" || t == "Descargar música (mini)") {
                ShowWindow(h, 9); SetForegroundWindow(h); return false;
            }
            return true;
        }, IntPtr.Zero);
    }
}
"@
        try { [DMBring]::FocusApp() } catch {}
        [System.Windows.Forms.MessageBox]::Show(
            'Descargar música ya está abierto. Se ha traído esa ventana al frente.',
            'Descargar música', 'OK', 'Information') | Out-Null
        exit
    }
} catch {}

# Funciones de Windows: barra de tareas, DPI y texto nítido
try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct DMPropKey { public Guid fmtid; public uint pid; }

[StructLayout(LayoutKind.Explicit)]
public struct DMPropVariant {
    [FieldOffset(0)] public ushort vt;
    [FieldOffset(8)] public IntPtr p;
    [FieldOffset(16)] public long relleno;
}

[ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface DMPropertyStore {
    [PreserveSig] int GetCount(out uint cProps);
    [PreserveSig] int GetAt(uint iProp, out DMPropKey pkey);
    [PreserveSig] int GetValue(ref DMPropKey key, out DMPropVariant pv);
    [PreserveSig] int SetValue(ref DMPropKey key, ref DMPropVariant pv);
    [PreserveSig] int Commit();
}

[ComImport, Guid("ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface DMTaskbarList3 {
    [PreserveSig] int HrInit();
    [PreserveSig] int AddTab(IntPtr hwnd);
    [PreserveSig] int DeleteTab(IntPtr hwnd);
    [PreserveSig] int ActivateTab(IntPtr hwnd);
    [PreserveSig] int SetActiveAlt(IntPtr hwnd);
    [PreserveSig] int MarkFullscreenWindow(IntPtr hwnd, [MarshalAs(UnmanagedType.Bool)] bool fFullscreen);
    [PreserveSig] int SetProgressValue(IntPtr hwnd, ulong ullCompleted, ulong ullTotal);
    [PreserveSig] int SetProgressState(IntPtr hwnd, int tbpFlags);
}

[ComImport, Guid("56FDF344-FD6D-11d0-958A-006097C9A090"), ClassInterface(ClassInterfaceType.None)]
public class DMTaskbarListClass { }

public static class DMWin {
    [StructLayout(LayoutKind.Sequential)]
    public struct FLASHWINFO { public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout; }
    [DllImport("user32.dll")] public static extern bool FlashWindowEx(ref FLASHWINFO pwfi);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);
    [DllImport("shell32.dll")] public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string appId);
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    public static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    public static void Flash(IntPtr h) {
        FLASHWINFO f = new FLASHWINFO();
        f.cbSize = (uint)Marshal.SizeOf(f); f.hwnd = h; f.dwFlags = 3 | 12; f.uCount = 0; f.dwTimeout = 0;
        FlashWindowEx(ref f);
    }
    public static void Pista(IntPtr h, string texto) { SendMessage(h, 0x1501, (IntPtr)1, texto); }

    // Scrollbars y controles oscuros (Win10+)
    public static void TemaOscuro(IntPtr h) {
        try {
            SetWindowTheme(h, "DarkMode_Explorer", null);
            int on = 1;
            DwmSetWindowAttribute(h, 20, ref on, 4); // DWMWA_USE_IMMERSIVE_DARK_MODE
        } catch { }
    }

    static DMTaskbarList3 tb;
    public static void Progreso(IntPtr h, int estado, ulong valor, ulong total) {
        try {
            if (tb == null) { tb = (DMTaskbarList3)new DMTaskbarListClass(); tb.HrInit(); }
            tb.SetProgressState(h, estado);
            if (estado == 2 || estado == 4) tb.SetProgressValue(h, valor, total);
        } catch { }
    }

    public static void SetShortcutAppId(string path, string appId) {
        Type t = Type.GetTypeFromCLSID(new Guid("00021401-0000-0000-C000-000000000046"));
        object link = Activator.CreateInstance(t);
        try {
            IPersistFile pf = (IPersistFile)link;
            pf.Load(path, 2);
            DMPropertyStore ps = (DMPropertyStore)link;
            DMPropKey key = new DMPropKey();
            key.fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
            key.pid = 5;
            DMPropVariant v = new DMPropVariant();
            v.vt = 31;
            v.p = Marshal.StringToCoTaskMemUni(appId);
            try { ps.SetValue(ref key, ref v); ps.Commit(); }
            finally { Marshal.FreeCoTaskMem(v.p); }
            pf.Save(path, true);
        } finally { Marshal.ReleaseComObject(link); }
    }
}
"@
    [void][DMWin]::SetProcessDPIAware()
    [void][DMWin]::SetCurrentProcessExplicitAppUserModelID('DescargarMusica.App')
    $script:hayWin = $true
} catch { $script:hayWin = $false }

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetUnhandledExceptionMode('CatchException')
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# ---------- Rutas y ajustes ----------
$dirApp        = Join-Path $env:APPDATA 'DescargarMusica'
$dirBin        = Join-Path $dirApp 'bin'
New-Item -ItemType Directory -Force -Path $dirApp, $dirBin | Out-Null
$archConfig    = Join-Path $dirApp 'config.json'
$archConfigTmp = Join-Path $dirApp 'config.json.tmp'
$archConfigBak = Join-Path $dirApp 'config.json.bak'
$archIcono     = Join-Path $dirApp 'icono.ico'
$archInforme   = Join-Path $dirApp 'ultima-descarga.txt'
$archErrores   = Join-Path $dirApp 'errores.log'
$archPrevBat   = Join-Path $dirApp 'prev-version.bat'
$env:PYTHONIOENCODING = 'utf-8'

# Formatos: original = sin convertir (mejor calidad real de la fuente)
$formatos = @('original', 'mp3', 'm4a', 'opus', 'flac', 'wav')
$formatosEtiqueta = @(
    'Original (sin convertir)',
    'MP3 (recomendado)',
    'M4A (iPhone)',
    'OPUS (poca espacio)',
    'FLAC (sin pérdida)',
    'WAV (sin comprimir)'
)

$config = [ordered]@{
    formato            = 0
    organizar          = 1
    carpeta            = (Join-Path ([Environment]::GetFolderPath('MyMusic')) 'Música descargada')
    portada            = $true
    limpiar            = $true
    saltar             = $true
    accesoCreado       = $false
    listas             = @()
    noPreguntarBorradas = $false
    bajarAlCopiar      = $false
    ventanaMini        = $false
}
function Cargar-Config {
    $ruta = $null
    if (Test-Path -LiteralPath $archConfig) { $ruta = $archConfig }
    elseif (Test-Path -LiteralPath $archConfigBak) { $ruta = $archConfigBak }
    if (-not $ruta) { return }
    try {
        $leido = Get-Content -LiteralPath $ruta -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $leido.PSObject.Properties) {
            if ($config.Contains($p.Name)) { $config[$p.Name] = $p.Value }
            if ($p.Name -eq 'carpetas' -and -not $p.Value) { $config.organizar = 0 }
        }
        # Migración: formatos antiguos (0=mp3...) → nuevos (0=original, 1=mp3...)
        if ($null -ne $leido.formato) {
            $f = [int]$leido.formato
            if (-not ($leido.PSObject.Properties.Name -contains 'formatoV3')) {
                $config.formato = [Math]::Min($f + 1, $formatos.Count - 1)
            }
        }
    } catch {
        Registrar-Error "No se pudo leer config: $($_.Exception.Message)"
    }
}

function Registrar-Error($msg) {
    try {
        $linea = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
        Add-Content -LiteralPath $archErrores -Value $linea -Encoding UTF8
    } catch {}
}

function Guardar-Config-Disco {
    if ($script:desinstalado) { return }
    try {
        $config.formatoV3 = $true
        $json = ($config | ConvertTo-Json -Depth 5)
        [IO.File]::WriteAllText($archConfigTmp, $json, [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $archConfig) {
            Copy-Item -LiteralPath $archConfig -Destination $archConfigBak -Force -ErrorAction SilentlyContinue
        }
        Move-Item -LiteralPath $archConfigTmp -Destination $archConfig -Force
    } catch {
        Registrar-Error "Error al guardar config: $($_.Exception.Message)"
    }
}

Cargar-Config

# Migrar historial antiguo (sin formato) → mp3
$archHistViejo = Join-Path $dirApp 'ya-descargadas.txt'
$archHistMp3 = Join-Path $dirApp 'ya-descargadas-mp3.txt'
if ((Test-Path -LiteralPath $archHistViejo) -and -not (Test-Path -LiteralPath $archHistMp3)) {
    try { Move-Item -LiteralPath $archHistViejo -Destination $archHistMp3 -Force } catch {}
}

$script:listas = New-Object System.Collections.ArrayList
foreach ($x in @($config.listas)) {
    if ($x -and $x.url) {
        [void]$script:listas.Add([pscustomobject]@{ url = [string]$x.url; nombre = [string]$x.nombre; ultima = [string]$x.ultima; nuevas = [string]$x.nuevas })
    }
}

# Herramientas: descarga directa (URLs) + id winget de respaldo
$herramientas = @(
    @{
        cmd = 'yt-dlp'; id = 'yt-dlp.yt-dlp'; nombre = 'el descargador'
        url = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
        tipo = 'exe'; destino = 'yt-dlp.exe'
    },
    @{
        cmd = 'ffmpeg'; id = 'Gyan.FFmpeg'; nombre = 'el conversor de audio'
        url = 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip'
        tipo = 'zip-ffmpeg'; destino = 'ffmpeg.exe'
    },
    @{
        cmd = 'deno'; id = 'DenoLand.Deno'; nombre = 'el complemento para YouTube'
        url = 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip'
        tipo = 'zip-deno'; destino = 'deno.exe'
    }
)

# ---------- Colores y fuentes (estilo deck / Rekordbox) ----------
$colFondo     = [System.Drawing.ColorTranslator]::FromHtml('#0E0E10')
$colPanel     = [System.Drawing.ColorTranslator]::FromHtml('#1A1A1E')
$colCampo     = [System.Drawing.ColorTranslator]::FromHtml('#121216')
$colTexto     = [System.Drawing.ColorTranslator]::FromHtml('#F2F2F4')
$colSuave     = [System.Drawing.ColorTranslator]::FromHtml('#9A9AA3')
$colTenue     = [System.Drawing.ColorTranslator]::FromHtml('#5C5C66')
$colBorde     = [System.Drawing.ColorTranslator]::FromHtml('#2C2C34')
$colHover     = [System.Drawing.ColorTranslator]::FromHtml('#26262E')
$colAcento    = [System.Drawing.ColorTranslator]::FromHtml('#FF6A00')   # naranja Pioneer
$colAcentoOsc = [System.Drawing.ColorTranslator]::FromHtml('#CC5500')
$colCancelar  = [System.Drawing.ColorTranslator]::FromHtml('#3A3A44')
$colBlanco    = [System.Drawing.Color]::White
$colExito     = [System.Drawing.ColorTranslator]::FromHtml('#3DDC97')
$colAviso     = [System.Drawing.ColorTranslator]::FromHtml('#FFB020')

$fNormal   = New-Object System.Drawing.Font('Segoe UI', 9.5)
$fPequena  = New-Object System.Drawing.Font('Segoe UI', 8.5)
$fTitulo   = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$fSeccion  = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$fEtiqueta = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
$fBoton    = New-Object System.Drawing.Font('Segoe UI Semibold', 12)
$fBotonMed = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5)
$fPopup    = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$fMiniTit  = New-Object System.Drawing.Font('Segoe UI Semibold', 13)
$fMono     = New-Object System.Drawing.Font('Consolas', 8.5)

# ================================================================
#  Utilidades
# ================================================================
function Q($s) { '"' + ($s -replace '"', '\"') + '"' }

function Refrescar-Path {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $links = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    $env:Path = "$dirBin;$links;$m;$u"
}

function Ruta-De($cmd) {
    $local = Join-Path $dirBin "$cmd.exe"
    if (Test-Path -LiteralPath $local) { return $local }
    $c = Get-Command $cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Source } else { return $null }
}

function Faltan { return @($herramientas | Where-Object { -not (Ruta-De $_.cmd) }) }

function Url-Spotdl-Windows {
    try {
        $cli = New-Object System.Net.Http.HttpClient
        $cli.Timeout = [TimeSpan]::FromSeconds(25)
        $cli.DefaultRequestHeaders.UserAgent.ParseAdd('DescargarMusica/3.6')
        $json = $cli.GetStringAsync('https://api.github.com/repos/spotDL/spotify-downloader/releases/latest').GetAwaiter().GetResult()
        $cli.Dispose()
        $rel = $json | ConvertFrom-Json
        $asset = @($rel.assets | Where-Object { $_.name -like '*win32.exe' }) | Select-Object -First 1
        if ($asset -and $asset.browser_download_url) { return [string]$asset.browser_download_url }
    } catch {
        Registrar-Error "URL spotDL: $($_.Exception.Message)"
    }
    return 'https://github.com/spotDL/spotify-downloader/releases/download/v4.5.2/spotdl-4.5.2-win32.exe'
}

function Instalar-Spotdl {
    $destino = Join-Path $dirBin 'spotdl.exe'
    if (Test-Path -LiteralPath $destino) { return $true }
    $url = Url-Spotdl-Windows
    $tmp = Join-Path $dirApp 'dl-spotdl.tmp'
    if (-not (Descargar-Http $url $tmp)) { return $false }
    try {
        Move-Item -LiteralPath $tmp -Destination $destino -Force
        return $true
    } catch {
        Registrar-Error "Instalar spotDL: $($_.Exception.Message)"
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Preparar-Spotdl {
    if ($script:tarea -and $script:modo -eq $null) { Abandonar-Tarea; $lblAct.Text = '' }
    Refrescar-Path
    $s = Ruta-De 'spotdl'
    if ($s) { return $s }

    $script:pop = Nuevo-Popup 'Instalando spotDL' "Hace falta para descargar desde Spotify.`nSe baja una sola vez (~45 MB). No cierres esta ventana."
    $script:pop.form.ShowInTaskbar = $true
    $script:pop.form.Add_Shown({
        $script:pop.paso.Text = 'Descargando spotDL desde GitHub...'
        [System.Windows.Forms.Application]::DoEvents()
        $ok = Instalar-Spotdl
        if (-not $ok) { $script:pop.paso.Text = 'Error al descargar spotDL.' }
        Start-Sleep -Milliseconds 400
        Cerrar-Popup
    })
    [void]$script:pop.form.ShowDialog()
    Refrescar-Path
    $s = Ruta-De 'spotdl'
    if (-not $s) {
        Aviso "No se pudo instalar spotDL.`n`nComprueba internet y vuelve a intentarlo." 'Warning'
    }
    return $s
}

function Plural($n, $uno, $varios) { if ($n -eq 1) { "1 $uno" } else { "$n $varios" } }

function Escalar-Dpi($f) {
    $f.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $f.AutoScaleMode = 'Dpi'
}

function Hoy { (Get-Date).ToString('dd/MM/yyyy HH:mm') }

function Archivo-Historial($fmt) {
    return (Join-Path $dirApp ("ya-descargadas-$fmt.txt"))
}

# Enlaces: YouTube / SoundCloud / Spotify (descarga Spotify vía spotDL → YouTube)
function Es-Enlace-Spotify($e) {
    if (-not $e) { return $false }
    if ($e -match '^https://open\.spotify\.com/(intl-[a-z]{2}/)?(track|album|playlist|artist)/[a-zA-Z0-9]+') { return $true }
    if ($e -match '^https://spotify\.link/[a-zA-Z0-9]+') { return $true }
    return $false
}

function Tipo-Enlace($e) {
    if ($e -match '^https://(www\.)?(youtube\.com|youtu\.be|music\.youtube\.com)/') { return 'youtube' }
    if ($e -match '^https://(www\.|m\.)?soundcloud\.com/') { return 'soundcloud' }
    if (Es-Enlace-Spotify $e) { return 'spotify' }
    return 'desconocido'
}

function Es-Enlace-Valido($e) {
    if (-not $e) { return $false }
    if ($e -notmatch '^https://') { return $false }
    # Bloquear metacaracteres peligrosos; ? y & son normales en URLs (watch?v=...&list=...)
    if ($e -match '[\s\"''`|;<>\*\{\}\[\]\\]') { return $false }
    if ($e -match '[^\x20-\x7E]') { return $false }  # solo ASCII imprimible
    $t = Tipo-Enlace $e
    return ($t -ne 'desconocido')
}

function Parsear-Spotify($e) {
    # Devuelve @{ tipo = track|album|playlist|artist|corto; id = '...' } o $null
    if ($e -match '^https://spotify\.link/([a-zA-Z0-9]+)') {
        return @{ tipo = 'corto'; id = $matches[1] }
    }
    if ($e -match '^https://open\.spotify\.com/(?:intl-[a-z]{2}/)?(track|album|playlist|artist)/([a-zA-Z0-9]+)') {
        return @{ tipo = $matches[1]; id = $matches[2] }
    }
    return $null
}

function Clave-Enlace($e) {
    if ($e -match '[?&]list=((?!RD)[^&]+)') { return 'lista:' + $matches[1] }
    if ($e -match '(?:youtu\.be/|[?&]v=|/shorts/)([\w-]{11})') { return 'yt:' + $matches[1] }
    if ($e -match 'soundcloud\.com/([^?#]+)') { return 'sc:' + $matches[1].TrimEnd('/').ToLower() }
    $sp = Parsear-Spotify $e
    if ($sp) { return "sp:$($sp.tipo):$($sp.id)" }
    return ($e -replace '[?#].*$', '').TrimEnd('/').ToLower()
}

function Quitar-Repetidos($lista) {
    $vistos = @{}
    foreach ($e in $lista) {
        $k = Clave-Enlace $e
        if (-not $vistos.ContainsKey($k)) { $vistos[$k] = $true; $e }
    }
}

function Arreglar-Enlace($e) {
    if ($e -match 'youtube\.com/watch' -and $e -match '[?&]list=RD') {
        $e = ($e -replace '[?&](list|start_radio|index)=[^&]*', '')
        if ($e -notmatch '\?') { $e = $e -replace '&', '?' }
    }
    return $e
}

function Parece-Lista($e) {
    if ($e -match '[?&]list=' -and $e -notmatch '[?&]list=RD') { return $true }
    if ($e -match 'youtube\.com/(playlist|channel|c/|@|user/)') { return $true }
    if ($e -match 'soundcloud\.com/.+/(sets|albums)/') { return $true }
    if ($e -match 'soundcloud\.com/[^/]+/?$' ) { return $true }  # perfil
    $sp = Parsear-Spotify $e
    if ($sp -and $sp.tipo -in @('album', 'playlist', 'artist', 'corto')) { return $true }
    return $false
}

function Verificar-Firma($bytes, $firmaB64) {
    try {
        $rsa = [System.Security.Cryptography.RSA]::Create()
        $rsa.FromXmlString($clavePublicaXml)
        $firma = [Convert]::FromBase64String(($firmaB64 -replace '\s', ''))
        return $rsa.VerifyData($bytes, $firma, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } catch {
        Registrar-Error "Verificar firma: $($_.Exception.Message)"
        return $false
    }
}

function Marcar-Arranque-Ok {
    Remove-Item -LiteralPath (Join-Path $dirApp 'esperando-arranque.flag') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $dirApp 'update-pending.flag') -Force -ErrorAction SilentlyContinue
}

# ---------- Icono ----------
function Crear-Icono {
    try {
        $bmp = New-Object System.Drawing.Bitmap 64, 64
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = 'AntiAlias'
        $g.TextRenderingHint = 'AntiAlias'
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush $colAcento), 2, 2, 60, 60)
        $f = New-Object System.Drawing.Font('Segoe UI Symbol', 34, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
        $g.DrawString([string][char]0x266B, $f, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 3, 64, 64)), $sf)
        $g.Dispose()
        $script:bmpIcono = $bmp
        $script:icono = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
        $ms = New-Object IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $png = $ms.ToArray()
        $out = New-Object IO.MemoryStream
        $w = New-Object IO.BinaryWriter($out)
        $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]1)
        $w.Write([byte]64); $w.Write([byte]64); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$png.Length); $w.Write([uint32]22)
        $w.Write($png); $w.Flush()
        [IO.File]::WriteAllBytes($archIcono, $out.ToArray())
    } catch { Registrar-Error "Icono: $($_.Exception.Message)" }
}

# ================================================================
#  Tareas en segundo plano
# ================================================================
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300
$script:tarea = $null
$script:colaDescargas = New-Object System.Collections.Queue
$script:versionYtdlp = $null

function Iniciar-Tarea($exe, $argumentos, $alLinea, $alTerminar, $limiteSeg = 0, $nombre = 'tarea') {
    $rS = Join-Path $dirApp "$nombre-salida.txt"
    $rE = Join-Path $dirApp "$nombre-errores.txt"
    Remove-Item -LiteralPath $rS, $rE -Force -ErrorAction SilentlyContinue
    try {
        $p = Start-Process -FilePath $exe -ArgumentList $argumentos -NoNewWindow -PassThru `
                -RedirectStandardOutput $rS -RedirectStandardError $rE
        $null = $p.Handle
    } catch {
        Registrar-Error "No se pudo iniciar $exe : $($_.Exception.Message)"
        & $alTerminar -999
        return
    }
    $script:tarea = @{
        proc = $p; alLinea = $alLinea; alTerminar = $alTerminar
        limite = $limiteSeg; inicio = Get-Date
        rutaS = $rS; posS = [long]0; restoS = ''
        rutaE = $rE; posE = [long]0; restoE = ''
    }
    $timer.Start()
}

function Leer-Lineas($t, $k, $final) {
    $ruta = $t["ruta$k"]
    $nuevo = ''
    if (Test-Path -LiteralPath $ruta) {
        try {
            $fs = [IO.File]::Open($ruta, 'Open', 'Read', 'ReadWrite')
            try {
                [void]$fs.Seek($t["pos$k"], 'Begin')
                $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)
                $nuevo = $sr.ReadToEnd()
                $t["pos$k"] = $fs.Position
            } finally { $fs.Close() }
        } catch {}
    }
    $texto = $t["resto$k"] + $nuevo
    $partes = $texto -split "`r`n|`n|`r"
    if ($final) {
        $t["resto$k"] = ''
    } else {
        $t["resto$k"] = $partes[-1]
        if ($partes.Count -gt 1) { $partes = $partes[0..($partes.Count - 2)] } else { $partes = @() }
    }
    return @($partes | Where-Object { $_ -ne '' })
}

function Matar-Tarea {
    $t = $script:tarea
    if ($t -and -not $t.proc.HasExited) {
        Start-Process taskkill -ArgumentList "/PID $($t.proc.Id) /T /F" -WindowStyle Hidden -Wait
    }
}

function Abandonar-Tarea {
    if ($script:tarea) {
        Matar-Tarea
        $timer.Stop()
        $script:tarea = $null
    }
}

$timer.Add_Tick({
    $t = $script:tarea
    if (-not $t) { $timer.Stop(); return }
    $terminado = $t.proc.HasExited
    foreach ($l in (Leer-Lineas $t 'S' $terminado)) { & $t.alLinea $l }
    foreach ($l in (Leer-Lineas $t 'E' $terminado)) { & $t.alLinea $l }
    if ($terminado) {
        $timer.Stop()
        $script:tarea = $null
        & $t.alTerminar $t.proc.ExitCode
    } elseif ($t.limite -gt 0 -and ((Get-Date) - $t.inicio).TotalSeconds -gt $t.limite) {
        Matar-Tarea
    }
})

# ================================================================
#  Descarga directa de herramientas (sin depender de winget)
# ================================================================
function Descargar-Http($url, $destino) {
    $cliente = New-Object System.Net.Http.HttpClient
    $cliente.Timeout = [TimeSpan]::FromMinutes(15)
    $cliente.DefaultRequestHeaders.UserAgent.ParseAdd('DescargarMusica/3.0')
    try {
        $bytes = $cliente.GetByteArrayAsync($url).GetAwaiter().GetResult()
        [IO.File]::WriteAllBytes($destino, $bytes)
        return $true
    } catch {
        Registrar-Error "Descarga $url : $($_.Exception.Message)"
        return $false
    } finally { $cliente.Dispose() }
}

function Extraer-Zip-Selectivo($zipPath, $patronExe, $destinoExe) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $tmp = Join-Path $dirApp ('tmp-extract-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        [IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tmp)
        $encontrado = Get-ChildItem -LiteralPath $tmp -Recurse -File -Filter $patronExe | Select-Object -First 1
        if (-not $encontrado) { return $false }
        Copy-Item -LiteralPath $encontrado.FullName -Destination $destinoExe -Force
        # Copiar DLLs hermanas de ffmpeg si las hay
        if ($patronExe -eq 'ffmpeg.exe') {
            $dirOrigen = $encontrado.DirectoryName
            foreach ($extra in @('ffprobe.exe', 'ffplay.exe')) {
                $e = Join-Path $dirOrigen $extra
                if (Test-Path -LiteralPath $e) {
                    Copy-Item -LiteralPath $e -Destination (Join-Path $dirBin $extra) -Force
                }
            }
        }
        return $true
    } catch {
        Registrar-Error "Extraer zip: $($_.Exception.Message)"
        return $false
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Instalar-Herramienta-Directa($h) {
    $destino = Join-Path $dirBin $h.destino
    $tmp = Join-Path $dirApp ('dl-' + $h.cmd + '.tmp')
    if (-not (Descargar-Http $h.url $tmp)) { return $false }
    try {
        if ($h.tipo -eq 'exe') {
            Move-Item -LiteralPath $tmp -Destination $destino -Force
            return $true
        }
        if ($h.tipo -eq 'zip-ffmpeg') {
            $ok = Extraer-Zip-Selectivo $tmp 'ffmpeg.exe' $destino
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            return $ok
        }
        if ($h.tipo -eq 'zip-deno') {
            $ok = Extraer-Zip-Selectivo $tmp 'deno.exe' $destino
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            return $ok
        }
    } catch {
        Registrar-Error "Instalar $($h.cmd): $($_.Exception.Message)"
        return $false
    }
    return $false
}

function Nuevo-Popup($titulo, $texto) {
    $p = New-Object System.Windows.Forms.Form
    Escalar-Dpi $p
    $p.Text = 'Descargar música'
    $p.ClientSize = New-Object System.Drawing.Size(500, 220)
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
    $barraTop.Size = New-Object System.Drawing.Size(500, 4)
    $p.Controls.Add($barraTop)

    if ($script:bmpIcono) {
        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image = $script:bmpIcono
        $pic.SizeMode = 'Zoom'
        $pic.Location = New-Object System.Drawing.Point(28, 32)
        $pic.Size = New-Object System.Drawing.Size(48, 48)
        $p.Controls.Add($pic)
    }
    $l1 = New-Object System.Windows.Forms.Label
    $l1.Text = $titulo; $l1.Font = $fPopup; $l1.ForeColor = $colTexto
    $l1.Location = New-Object System.Drawing.Point(96, 28); $l1.Size = New-Object System.Drawing.Size(380, 30)
    $p.Controls.Add($l1)

    $l2 = New-Object System.Windows.Forms.Label
    $l2.Text = $texto; $l2.ForeColor = $colSuave
    $l2.Location = New-Object System.Drawing.Point(96, 62); $l2.Size = New-Object System.Drawing.Size(380, 70)
    $p.Controls.Add($l2)

    $l3 = New-Object System.Windows.Forms.Label
    $l3.Text = 'Empezando...'; $l3.Font = $fEtiqueta; $l3.ForeColor = $colAcento
    $l3.Location = New-Object System.Drawing.Point(96, 140); $l3.Size = New-Object System.Drawing.Size(380, 22)
    $p.Controls.Add($l3)

    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Style = 'Marquee'
    $pb.MarqueeAnimationSpeed = 30
    $pb.Location = New-Object System.Drawing.Point(96, 170); $pb.Size = New-Object System.Drawing.Size(380, 10)
    $p.Controls.Add($pb)

    $script:popupOcupado = $true
    $p.Add_FormClosing({ param($s, $e) if ($script:popupOcupado -and $e.CloseReason -eq 'UserClosing') { $e.Cancel = $true } })
    return @{ form = $p; paso = $l3 }
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
    if ($script:pop) { $script:pop.form.Close(); $script:pop = $null }
}

function Instalar-Si-Falta {
    Refrescar-Path
    $falta = Faltan
    if ($falta.Count -eq 0) { return $true }

    $script:pop = Nuevo-Popup 'Preparando Descargar música' "Es la primera vez (o faltan piezas). Se descargarán desde internet de forma directa.`nPuede tardar unos minutos. No cierres esta ventana."
    $script:pop.form.ShowInTaskbar = $true
    $script:pop.form.Add_Shown({
        $i = 0
        foreach ($h in (Faltan)) {
            $i++
            $script:pop.paso.Text = "Paso $i : descargando $($h.nombre)..."
            [System.Windows.Forms.Application]::DoEvents()
            $ok = Instalar-Herramienta-Directa $h
            if (-not $ok) {
                # Respaldo winget si existe
                $wg = Ruta-De 'winget'
                if (-not $wg) { $wg = (Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1).Source }
                if ($wg) {
                    $script:pop.paso.Text = "Paso $i : intentando con el instalador de Windows..."
                    [System.Windows.Forms.Application]::DoEvents()
                    try {
                        Start-Process -FilePath $wg -ArgumentList "install --id $($h.id) -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
                    } catch { Registrar-Error "winget $($h.cmd): $($_.Exception.Message)" }
                }
            }
            Refrescar-Path
        }
        Cerrar-Popup
    })
    [void]$script:pop.form.ShowDialog()

    Refrescar-Path
    $falta = Faltan
    if ($falta.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No se pudo instalar $($falta[0].nombre).`n`nComprueba internet y vuelve a abrir el programa.`nSi tu PC de empresa bloquea descargas, pide a informática que permita yt-dlp, FFmpeg y Deno.",
            'Descargar música', 'OK', 'Warning') | Out-Null
        return $false
    }
    return $true
}

function Actualizar-Herramientas-Directas {
    # Como máximo una vez al día: yt-dlp -U (rápido) o redescarga si falla
    $stamp = Join-Path $dirApp 'ultimo-update-ytdlp.txt'
    try {
        if (Test-Path -LiteralPath $stamp) {
            $rawStamp = (Get-Content -LiteralPath $stamp -Raw -ErrorAction SilentlyContinue)
            if ($rawStamp) {
                $hace = (Get-Date) - [datetime]($rawStamp.Trim())
                if ($hace.TotalHours -lt 20) { $lblAct.Text = 'Todo al día'; return }
            }
        }
    } catch {}
    $y = Ruta-De 'yt-dlp'
    if (-not $y) { $lblAct.Text = 'Todo al día'; return }
    try {
        $p = Start-Process -FilePath $y -ArgumentList @('-U') -Wait -PassThru -WindowStyle Hidden
        $script:versionYtdlp = $null
        try { Set-Content -LiteralPath $stamp -Value ((Get-Date).ToString('o')) -Encoding UTF8 } catch {}
        if ($null -ne $p -and $p.ExitCode -eq 0) { $lblAct.Text = 'Actualizado' } else { $lblAct.Text = 'Todo al día' }
    } catch {
        Registrar-Error "Actualizar yt-dlp (-U): $($_.Exception.Message)"
        try {
            $h = $herramientas | Where-Object { $_.cmd -eq 'yt-dlp' } | Select-Object -First 1
            if ($h -and (Instalar-Herramienta-Directa $h)) {
                Refrescar-Path
                $script:versionYtdlp = $null
                $lblAct.Text = 'Actualizado'
                Set-Content -LiteralPath $stamp -Value ((Get-Date).ToString('o')) -Encoding UTF8
            } else {
                $lblAct.Text = 'Todo al día'
            }
        } catch {
            $lblAct.Text = 'Todo al día'
            Registrar-Error "Actualizar yt-dlp (directa): $($_.Exception.Message)"
        }
    }
}

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
    $padre.Controls.Add($b)
    return $b
}

function Nueva-Casilla($padre, $texto, $x, $y, $marcada, $ancho) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $texto
    $c.Location = New-Object System.Drawing.Point($x, $y)
    $c.Size = New-Object System.Drawing.Size($ancho, 24)
    $c.Checked = [bool]$marcada
    $c.ForeColor = $colTexto
    $c.BackColor = [System.Drawing.Color]::Transparent
    $c.FlatStyle = 'Flat'
    $c.FlatAppearance.BorderSize = 0
    $padre.Controls.Add($c)
    return $c
}

function Nuevo-Combo($padre, $x, $y, $ancho, $opciones, $sel) {
    # Dropdown 100% oscuro (el ComboBox de Windows deja la flecha blanca)
    $idx = [Math]::Min([Math]::Max([int]$sel, 0), $opciones.Count - 1)
    $estado = New-Object psobject
    Add-Member -InputObject $estado -NotePropertyName SelectedIndex -NotePropertyValue $idx
    Add-Member -InputObject $estado -NotePropertyName Opciones -NotePropertyValue @($opciones)
    Add-Member -InputObject $estado -NotePropertyName Boton -NotePropertyValue $null
    Add-Member -InputObject $estado -NotePropertyName Drop -NotePropertyValue $null
    Add-Member -InputObject $estado -NotePropertyName CerrarSinReabrir -NotePropertyValue $false

    $wrap = New-Object System.Windows.Forms.Panel
    $wrap.Location = New-Object System.Drawing.Point($x, $y)
    $wrap.Size = New-Object System.Drawing.Size($ancho, 34)
    $wrap.BackColor = $colBorde

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
            try { [DMWin]::TemaOscuro($lb.Handle) } catch {}
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
        if ($script:hayWin) { try { [DMWin]::TemaOscuro($t.Handle) } catch {} }
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
        if ($script:hayWin) { try { [DMWin]::TemaOscuro($lb.Handle) } catch {} }
    })
    $wrap.Controls.Add($lb)
    $padre.Controls.Add($wrap)
    return $lb
}

# ================================================================
#  Ventana principal
# ================================================================
$form = New-Object System.Windows.Forms.Form
Escalar-Dpi $form
$form.Text = 'Descargar música'
$form.ClientSize = New-Object System.Drawing.Size(780, 1000)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $colFondo
$form.ForeColor = $colTexto
$form.Font = $fNormal

$tips = New-Object System.Windows.Forms.ToolTip
$tips.AutoPopDelay = 15000
$tips.BackColor = $colPanel
$tips.ForeColor = $colTexto

$hdrBar = New-Object System.Windows.Forms.Panel
$hdrBar.BackColor = $colAcento
$hdrBar.Location = New-Object System.Drawing.Point(0, 0)
$hdrBar.Size = New-Object System.Drawing.Size(780, 3)
$form.Controls.Add($hdrBar)

Nueva-Etiqueta $form 'DESCARGAR MÚSICA' 28 18 480 34 $fTitulo $colTexto | Out-Null
Nueva-Etiqueta $form 'YouTube  ·  SoundCloud  ·  Spotify' 30 54 400 20 $fPequena $colSuave | Out-Null
$lblSello = Nueva-Etiqueta $form 'Made by WLY' 430 54 150 20 $fPequena $colTenue
$lblSello.TextAlign = 'MiddleRight'

$btnMini = Nuevo-Boton $form 'MINI' 600 20 54 32
$tips.SetToolTip($btnMini, 'Ventana pequeña con cola y bajar al copiar')
$btnAyuda = Nuevo-Boton $form '?' 662 20 36 32
$btnAyuda.Font = $fBotonMed
$tips.SetToolTip($btnAyuda, 'Ayuda')
$btnMas = Nuevo-Boton $form ([string][char]0x22EF) 706 20 36 32
$btnMas.Font = $fBotonMed
$tips.SetToolTip($btnMas, 'Más opciones')

# Pestañas propias (el TabControl de Windows deja una franja blanca)
$script:pestanaActual = 1
$barPestanas = New-Object System.Windows.Forms.Panel
$barPestanas.Location = New-Object System.Drawing.Point(20, 90)
$barPestanas.Size = New-Object System.Drawing.Size(740, 40)
$barPestanas.BackColor = $colFondo
$form.Controls.Add($barPestanas)

$btnTabDesc = Nuevo-Boton $barPestanas 'DESCARGAR' 0 4 160 32
$btnTabList = Nuevo-Boton $barPestanas 'MIS LISTAS' 168 4 160 32
$btnTabDesc.FlatAppearance.BorderSize = 0
$btnTabList.FlatAppearance.BorderSize = 0

$tabHost = New-Object System.Windows.Forms.Panel
$tabHost.Location = New-Object System.Drawing.Point(20, 130)
$tabHost.Size = New-Object System.Drawing.Size(740, 790)
$tabHost.BackColor = $colPanel
$form.Controls.Add($tabHost)

$tab1 = New-Object System.Windows.Forms.Panel
$tab1.Dock = 'Fill'
$tab1.BackColor = $colPanel
$tab1.ForeColor = $colTexto
$tabHost.Controls.Add($tab1)

$tab2 = New-Object System.Windows.Forms.Panel
$tab2.Dock = 'Fill'
$tab2.BackColor = $colPanel
$tab2.ForeColor = $colTexto
$tab2.Visible = $false
$tabHost.Controls.Add($tab2)

function Pintar-Pestanas {
    $activo = { param($b, $on)
        if ($on) {
            $b.ForeColor = $colAcento
            $b.BackColor = $colPanel
            $b.FlatAppearance.MouseOverBackColor = $colPanel
        } else {
            $b.ForeColor = $colSuave
            $b.BackColor = $colFondo
            $b.FlatAppearance.MouseOverBackColor = $colHover
        }
    }
    & $activo $btnTabDesc ($script:pestanaActual -eq 1)
    & $activo $btnTabList ($script:pestanaActual -eq 2)
}

function Mostrar-Pestana($n) {
    $script:pestanaActual = $n
    $tab1.Visible = ($n -eq 1)
    $tab2.Visible = ($n -eq 2)
    if ($n -eq 1) { $tab1.BringToFront() } else { $tab2.BringToFront() }
    Pintar-Pestanas
}

$btnTabDesc.Add_Click({ Mostrar-Pestana 1 })
$btnTabList.Add_Click({ Mostrar-Pestana 2 })
Pintar-Pestanas

Nueva-Etiqueta $tab1 'ENLACES' 24 20 220 18 $fEtiqueta $colAcento | Out-Null
$txtEnlace = Nuevo-Campo $tab1 24 44 560 100 $true

$lblAyuda = New-Object System.Windows.Forms.Label
$lblAyuda.Text = "Pega enlaces de YouTube, SoundCloud o Spotify.`r`nVarios: uno por línea."
$lblAyuda.ForeColor = $colTenue
$lblAyuda.BackColor = $colCampo
$lblAyuda.Location = New-Object System.Drawing.Point(8, 8)
$lblAyuda.Size = New-Object System.Drawing.Size(520, 44)
$lblAyuda.Cursor = [System.Windows.Forms.Cursors]::IBeam
$txtEnlace.Controls.Add($lblAyuda)

$btnPegar  = Nuevo-Boton $tab1 'PEGAR'  600 44 116 42
$btnBorrar = Nuevo-Boton $tab1 'BORRAR' 600 96 116 42

Nueva-Etiqueta $tab1 'SALIDA' 24 164 220 18 $fEtiqueta $colAcento | Out-Null
Nueva-Etiqueta $tab1 'FORMATO' 24 190 340 16 $fEtiqueta $colTenue | Out-Null
$cmbFormato = Nuevo-Combo $tab1 24 210 340 $formatosEtiqueta $config.formato
$tips.SetToolTip($cmbFormato, "Original: deja el audio tal como lo envía la web (mejor opción para DJs).`nConvertir a FLAC/WAV/MP3 320 NO mejora el sonido de YouTube ni SoundCloud.")

Nueva-Etiqueta $tab1 'CARPETAS' 384 190 340 16 $fEtiqueta $colTenue | Out-Null
$cmbOrganizar = Nuevo-Combo $tab1 384 210 332 @(
    'Todas las canciones juntas',
    'Una carpeta por cada lista',
    'Una carpeta por cada artista'
) $config.organizar

Nueva-Etiqueta $tab1 'DESTINO' 24 260 220 16 $fEtiqueta $colTenue | Out-Null
$txtCarpeta = Nuevo-Campo $tab1 24 280 560 34 $false
$txtCarpeta.ReadOnly = $true
$txtCarpeta.Text = [string]$config.carpeta
$btnCambiar = Nuevo-Boton $tab1 'CAMBIAR' 600 280 116 34

$chkPortada = Nueva-Casilla $tab1 'Portada y metadatos (artista, título)' 24 332 $config.portada 680
$chkLimpiar = Nueva-Casilla $tab1 'Limpiar nombres (Official Video, Lyrics, HD…)' 24 360 $config.limpiar 680
$chkSaltar  = Nueva-Casilla $tab1 'No repetir descargas (historial por formato)' 24 388 $config.saltar 480
$lnkOlvidar = Nuevo-Enlace $tab1 'Olvidar historial' 520 388 196 'MiddleRight'

$btnDescargar = Nuevo-BotonPrincipal $tab1 'DESCARGAR' 24 434 360 52 $fBoton
$btnCancelar  = Nuevo-Boton $tab1 'CANCELAR' 400 434 140 52
$btnCancelar.Enabled = $false
$btnElegir = Nuevo-Boton $tab1 'ELEGIR…' 556 434 160 52
$tips.SetToolTip($btnElegir, 'Muestra las canciones de la lista para marcar solo las que quieras')
$tips.SetToolTip($btnDescargar, 'Si ya hay una descarga, el enlace se añade a la cola')

$lblCola = Nueva-Etiqueta $tab1 '' 24 500 690 20 $fPequena $colSuave

$barra = Nueva-BarraProgreso $tab1 24 528 692 10
$lblEstado = Nueva-Etiqueta $tab1 'Listo. Pega un enlace y pulsa Descargar.' 24 550 692 40 $fNormal $colTexto
$lblEstado.AutoEllipsis = $true
$lblCalidad = Nueva-Etiqueta $tab1 '' 24 594 692 20 $fPequena $colAcento

$lstResultados = Nuevo-ListBoxOscuro $tab1 24 624 692 130

Nueva-Etiqueta $tab2 'LISTAS GUARDADAS' 24 20 400 18 $fEtiqueta $colAcento | Out-Null
Nueva-Etiqueta $tab2 'Al actualizar se bajan solo las canciones nuevas del formato elegido.' 24 46 690 22 $fPequena $colSuave | Out-Null

$txtNuevaLista = Nuevo-Campo $tab2 24 80 560 34 $false
$btnAnadir = Nuevo-Boton $tab2 'AÑADIR' 600 80 116 34

$lvWrap = New-Object System.Windows.Forms.Panel
$lvWrap.Location = New-Object System.Drawing.Point(24, 130)
$lvWrap.Size = New-Object System.Drawing.Size(692, 360)
$lvWrap.BackColor = $colBorde
$tab2.Controls.Add($lvWrap)

$lvListas = New-Object System.Windows.Forms.ListView
$lvListas.Location = New-Object System.Drawing.Point(1, 1)
$lvListas.Size = New-Object System.Drawing.Size(690, 358)
$lvListas.View = 'Details'
$lvListas.FullRowSelect = $true
$lvListas.HideSelection = $false
$lvListas.BorderStyle = 'None'
$lvListas.BackColor = $colCampo
$lvListas.ForeColor = $colTexto
$lvListas.Font = $fPequena
[void]$lvListas.Columns.Add('Lista', 260)
[void]$lvListas.Columns.Add('Última vez', 140)
[void]$lvListas.Columns.Add('Nuevas', 80)
[void]$lvListas.Columns.Add('Enlace', 400)
$lvWrap.Controls.Add($lvListas)

$btnSyncTodas = Nuevo-BotonPrincipal $tab2 'ACTUALIZAR TODAS' 24 510 300 48 $fBotonMed
$btnSyncUna   = Nuevo-Boton $tab2 'ACTUALIZAR' 340 510 180 48
$btnQuitar    = Nuevo-Boton $tab2 'QUITAR' 536 510 180 48
$chkNoPreguntar = Nueva-Casilla $tab2 'No preguntar si faltan temas (si los mueves a Rekordbox)' 24 576 $config.noPreguntarBorradas 680
Nueva-Etiqueta $tab2 'Usa formato, carpetas y opciones de la pestaña Descargar.' 24 612 690 20 $fPequena $colTenue | Out-Null
$lblListas = Nueva-Etiqueta $tab2 '' 24 640 690 22 $fNormal $colTexto

$btnAbrirUltima = Nuevo-Boton $form 'Última descarga' 20 940 170 36
$btnAbrirUltima.Enabled = $false
$btnAbrir = Nuevo-Boton $form 'Carpeta de música' 204 940 180 36
$lblAct = Nueva-Etiqueta $form '' 420 946 340 24 $fPequena $colTenue
$lblAct.TextAlign = 'MiddleRight'

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Font = $fNormal
$menu.BackColor = $colPanel
$menu.ForeColor = $colTexto
$miDetalles    = $menu.Items.Add('Ver detalles técnicos de la última descarga')
$miErrores     = $menu.Items.Add('Ver registro de errores internos')
$miActApp      = $menu.Items.Add('Buscar una versión nueva del programa')
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miDesinstalar = $menu.Items.Add('Desinstalar Descargar música...')
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miVersion     = $menu.Items.Add("Versión $versionApp")
$miVersion.Enabled = $false

# ================================================================
#  Ventana mini
# ================================================================
$formMini = New-Object System.Windows.Forms.Form
Escalar-Dpi $formMini
$formMini.Text = 'Descargar música (mini)'
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

Nueva-Etiqueta $formMini 'DESCARGAR MÚSICA' 18 18 300 28 $fMiniTit $colTexto | Out-Null
$btnExpandir = Nuevo-Boton $formMini 'GRANDE' 350 16 90 30
$chkBajarCopiar = Nueva-Casilla $formMini 'Bajar al copiar enlace (YouTube, SoundCloud o Spotify)' 18 56 $config.bajarAlCopiar 420
$txtMini = Nuevo-Campo $formMini 18 94 320 34 $false
$btnMiniDl = Nuevo-BotonPrincipal $formMini 'AÑADIR' 350 94 90 34 $fBotonMed
$lstMiniCola = Nuevo-ListBoxOscuro $formMini 18 142 422 100
$barraMini = Nueva-BarraProgreso $formMini 18 256 422 10
$lblMiniEstado = Nueva-Etiqueta $formMini 'Listo.' 18 276 422 30 $fPequena $colTexto
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
    [System.Windows.Forms.MessageBox]::Show($owner, $texto, 'Descargar música', 'OK', $icono) | Out-Null
}
function Pregunta($texto) {
    $owner = if ($script:enMini) { $formMini } else { $form }
    return ([System.Windows.Forms.MessageBox]::Show($owner, $texto, 'Descargar música', 'YesNo', 'Question') -eq 'Yes')
}
function Resultado($texto) {
    [void]$lstResultados.Items.Add($texto)
    $lstResultados.TopIndex = [Math]::Max(0, $lstResultados.Items.Count - 1)
}
function Barra-Tarea($estado, $valor = 0) {
    $h = if ($script:enMini) { $formMini.Handle } else { $form.Handle }
    if ($script:hayWin) { try { [DMWin]::Progreso($h, $estado, [uint64]$valor, [uint64]1000) } catch {} }
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
    $config.carpeta   = $txtCarpeta.Text
    $config.portada   = $chkPortada.Checked
    $config.limpiar   = $chkLimpiar.Checked
    $config.saltar    = $chkSaltar.Checked
    $config.noPreguntarBorradas = $chkNoPreguntar.Checked
    $config.bajarAlCopiar = $chkBajarCopiar.Checked
    $config.ventanaMini = $script:enMini
    $config.listas    = @($script:listas)
    Guardar-Config-Disco
}
function Actualizar-Ayuda { $lblAyuda.Visible = ($txtEnlace.Text -eq '') }

function Modo($m) {
    $script:modo = $m
    $ocupado = ($m -ne $null)
    foreach ($c in @($cmbFormato, $cmbOrganizar, $btnCambiar, $chkPortada, $chkLimpiar,
                     $chkSaltar, $lnkOlvidar, $btnElegir, $txtNuevaLista, $btnAnadir, $btnSyncTodas, $btnSyncUna, $btnQuitar, $chkNoPreguntar)) {
        $c.Enabled = -not $ocupado
    }
    # Enlaces y pegar siguen activos para poder encolar
    $txtEnlace.Enabled = $true
    $btnPegar.Enabled = $true
    $btnBorrar.Enabled = (-not $ocupado)
    $btnDescargar.Enabled = $true
    $btnCancelar.Enabled = $ocupado
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
    } catch {}
    $activo = [System.Windows.Forms.Form]::ActiveForm
    $frm = if ($script:enMini) { $formMini } else { $form }
    if ($script:hayWin -and $activo -ne $frm) {
        try { [DMWin]::Flash($frm.Handle) } catch {}
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
    } catch {}
    if (-not $script:versionYtdlp) { $script:versionYtdlp = '?' }
    return $script:versionYtdlp
}

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
        $script:http.DefaultRequestHeaders.UserAgent.ParseAdd('DescargarMusica/3.0')
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
    if (-not (Verificar-Firma $bytes $firma)) {
        Aviso 'La versión nueva no tiene una firma válida. Por seguridad no se instalará. Avisa a quien te pasó el programa.' 'Warning'
        Registrar-Error 'Actualización rechazada: firma inválida'
        return
    }
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
    if ($script:modo -ne $null -and -not $script:checkManual) { return }
    if (-not (Pregunta "Hay una versión nueva de Descargar música ($nueva), firmada por el autor. Tú tienes la $versionApp.`n`n¿Actualizar ahora?")) { return }
    Instalar-VersionApp $texto
})

function Instalar-VersionApp($texto) {
    try {
        $bat = $env:DM_BAT
        # Guardar versión anterior para rollback
        Copy-Item -LiteralPath $bat -Destination $archPrevBat -Force
        $texto = $texto -replace "(?<!`r)`n", "`r`n"
        [IO.File]::WriteAllText($bat, $texto, (New-Object System.Text.UTF8Encoding($false)))
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

# ================================================================
#  Descarga
# ================================================================
function Traducir-Error($l) {
    $web = if ($l -match '\[youtube') { 'YouTube' } elseif ($l -match '\[soundcloud') { 'SoundCloud' } else { 'La web' }
    switch -Regex ($l) {
        'Unsupported URL|is not a valid URL|no suitable extractor' {
            return @{ origen = 'El enlace'; texto = 'No es de una canción ni de una lista de YouTube o SoundCloud.' } }
        'getaddrinfo|Failed to resolve|timed out|Connection refused|No route to host|Network is unreachable|Connection reset|RemoteDisconnected' {
            return @{ origen = 'Tu conexión'; texto = 'No hay internet o va muy lenta. Comprueba la conexión y vuelve a intentarlo.' } }
        'DRM protected|DRM-protected' {
            return @{ origen = $web; texto = 'Está protegida contra copia (DRM) y la web no permite descargarla.' } }
        'Private video|This video is private|Video unavailable|not available|has been removed|HTTP Error 404' {
            return @{ origen = $web; texto = 'La canción no está disponible o es privada.' } }
        'not a bot|Sign in to confirm|HTTP Error 429|Too Many Requests' {
            return @{ origen = $web; texto = 'Ha bloqueado las descargas por un rato. Espera unos minutos y vuelve a intentarlo.' } }
        'age-restricted|confirm your age|inappropriate' {
            return @{ origen = $web; texto = 'La canción tiene restricción de edad y no se puede descargar.' } }
        'ffmpeg not found|ffprobe not found|Postprocessing|Permission denied|No space left|WinError' {
            return @{ origen = 'El programa'; texto = 'Fallo al guardar o convertir la canción. Cierra y vuelve a abrir el programa.' } }
        'HTTP Error 403|Unable to extract|nsig|Signature|Requested format|JavaScript|jsc' {
            return @{ origen = "$web (ha cambiado algo)"; texto = 'Cierra el programa y vuelve a abrirlo: se actualizará solo.' } }
        default {
            return @{ origen = 'Desconocido'; texto = 'Error no reconocido. Menú → Ver detalles técnicos.' } }
    }
}

function Poner-Barra($pct) {
    $d = $script:dl
    if ($d.total -gt 1) { $v = (($d.actual - 1) + $pct / 100) / $d.total } else { $v = $pct / 100 }
    $valor = [int][Math]::Min([Math]::Max($v * 1000, 0), 1000)
    Set-BarraValor $barra $valor
    Set-BarraValor $barraMini $valor
    Barra-Tarea 2 $valor
}

function Procesar-Linea($l) {
    $d = $script:dl
    if ($l -match '^\[DM\](.*?)\|(.*?)\|(.*?)\|(.*)$') {
        $gPct = $matches[1]; $gIdx = $matches[2]; $gTot = $matches[3]; $gTit = $matches[4]
        $pct = 0.0
        [void][double]::TryParse(($gPct -replace '[^\d\.]', ''), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$pct)
        if ($gIdx -match '^\d+$' -and $gTot -match '^\d+$') { $d.actual = [int]$gIdx; $d.total = [int]$gTot }
        $d.titulo = $gTit
        Poner-Barra $pct
        $cual = if ($d.total -gt 1) { "canción $($d.actual) de $($d.total)" } else { 'canción' }
        Estado ("Descargando {0} ({1:0}%):`n{2}" -f $cual, $pct, $d.titulo)
        return
    }
    if ($l -match 'Downloading format (\d+)[^\]]*?(?:audio only)?.*?(\d+k?|~\d+k)') {
        $d.calidad = $matches[2]
        $lblCalidad.Text = "Calidad real de la fuente: $($d.calidad)"
        return
    }
    if ($l -match '\[info\].*?(\d{2,4}k)\b' -or $l -match 'abr[^\d]*(\d{2,4})') {
        if (-not $d.calidad) {
            $d.calidad = $matches[1]
            if ($d.calidad -notmatch 'k$') { $d.calidad = $d.calidad + 'k' }
            $lblCalidad.Text = "Calidad real de la fuente: ~$($d.calidad) (YouTube/SoundCloud no dan más)"
        }
        return
    }
    if ($l -match '^\[[\w:]+\] Extracting URL: (\S+)') {
        $u = $matches[1]
        if ($d.porUrl.ContainsKey($u)) { $d.listaActual = $u }
        return
    }
    if ($l -match '^\[download\] Downloading playlist: (.+)$') {
        $nombreLista = $matches[1].Trim()
        Resultado ([string][char]0x25B8 + '  Lista: ' + $nombreLista)
        if ($d.listaActual) { $d.porUrl[$d.listaActual].nombre = $nombreLista }
        return
    }
    if ($l -match 'Downloading (?:item|video) (\d+) of (\d+)') {
        $d.actual = [int]$matches[1]; $d.total = [int]$matches[2]
        $d.yaEstaba = $false; $d.titulo = ''; $d.calidad = $null
        $lblCalidad.Text = ''
        Poner-Barra 0
        return
    }
    if ($l -match '^\[download\] .+ has already been downloaded') {
        $d.yaEstaba = $true; $d.saltadas++
        Resultado ('–  Ya estaba en la carpeta: ' + $d.titulo)
        return
    }
    if ($l -match '^Deleting original file') { $d.enCurso = $null; return }
    if ($l -match '^\[ExtractAudio\] Destination: (.+)$' -or $l -match '^\[ExtractAudio\] Not converting audio (.+?); file is already' -or
        $l -match '^\[download\] Destination: (.+)$' -or $l -match '\[Merger\] Merging formats into "(.+)"') {
        $ruta = $matches[1].Trim('"')
        if ($d.yaEstaba) { $d.yaEstaba = $false; return }
        $nombre = [IO.Path]::GetFileNameWithoutExtension($ruta)
        try { $script:ultimaCarpetaReal = Split-Path -Parent $ruta } catch {}
        $d.enCurso = $ruta
        $d.nuevas++
        if ($d.listaActual) { $d.nuevasPorLista[$d.listaActual] = 1 + [int]$d.nuevasPorLista[$d.listaActual] }
        $extra = if ($d.calidad) { "  [$($d.calidad)]" } else { '' }
        Resultado ([string][char]0x2713 + '  ' + $nombre + $extra)
        Estado "Guardando:`n$nombre"
        return
    }
    if ($l -match 'has already been recorded in the archive') {
        if ($l -match '^\[download\] (\S+): has already') { [void]$d.idsSaltados.Add($matches[1]) }
        $d.saltadas++
        Resultado ('–  Ya la tenías en este formato, se ha saltado')
        return
    }
    if ($l -match '^ERROR:') {
        $err = Traducir-Error $l
        $txt = "$($err.origen): $($err.texto)"
        $d.nErrores++
        $quien = if ($d.titulo) { $d.titulo } elseif ($d.total -gt 1) { "Canción $($d.actual) de $($d.total)" } else { 'La canción' }
        Resultado ([string][char]0x2717 + '  ' + $quien + '  —  ' + $txt)
        if (-not $d.errores.Contains($txt)) { [void]$d.errores.Add($txt) }
    }
}

$reLimpiar = '(?i)\s*[\(\[][^\)\]]*\b(official|oficial|videoclip|video|vídeo|audio|lyrics?|letra|visuali[sz]er|hd|hq|4k|mv)\b[^\)\]]*[\)\]]'
$reLimpiarCola = '(?i)\s*[|｜]\s*(official|oficial|video|vídeo|audio|lyrics?|letra).*$'

function Leer-Enlaces {
    return @(Quitar-Repetidos @($txtEnlace.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }))
}

function Comprobar-Enlaces($enlaces) {
    if ($enlaces.Count -eq 0) {
        Estado 'Primero pega un enlace de YouTube, SoundCloud o Spotify.'
        $txtEnlace.Focus()
        return $false
    }
    foreach ($e in $enlaces) {
        if (-not (Es-Enlace-Valido $e)) {
            Aviso "Enlace no válido o no permitido:`n`n$e`n`nSolo se aceptan enlaces https:// de YouTube, SoundCloud o Spotify, sin caracteres raros." 'Warning'
            return $false
        }
    }
    return $true
}

function Preparar-Ytdlp {
    if ($script:tarea -and $script:modo -eq $null) { Abandonar-Tarea; $lblAct.Text = '' }
    Refrescar-Path
    $ytdlp = Ruta-De 'yt-dlp'
    if (-not $ytdlp) { Aviso 'Falta el descargador. Cierra el programa y vuelve a abrirlo para que se instale.' 'Warning' }
    return $ytdlp
}

function Construir-Args($enlaces, $sync, $indices) {
    $fmt = $formatos[$cmbFormato.SelectedIndex]
    $carpeta = $txtCarpeta.Text.TrimEnd('\')
    $a = New-Object System.Collections.Generic.List[string]
    $a.AddRange([string[]]@('--newline', '--color', 'never', '--no-mtime', '--encoding', 'utf-8', '--windows-filenames'))
    $a.Add('--concurrent-fragments'); $a.Add('4')

    $hayYt = @($enlaces | Where-Object { $_ -match 'youtube\.com|youtu\.be' }).Count -gt 0
    if ($hayYt) {
        $a.Add('--sleep-interval'); $a.Add('1')
        $a.Add('--max-sleep-interval'); $a.Add('3')
        $a.Add('--sleep-requests'); $a.Add('0.5')
    }

    if ($fmt -eq 'original') {
        $a.AddRange([string[]]@('-f', 'bestaudio/best', '--no-keep-video'))
    } else {
        $a.AddRange([string[]]@('-x', '--audio-format', $fmt, '--audio-quality', '0'))
    }

    $a.Add('-P'); $a.Add((Q $carpeta))
    $a.Add('--progress-template'); $a.Add((Q 'download:[DM]%(progress._percent_str)s|%(info.playlist_index)s|%(info.playlist_count)s|%(info.title)s'))

    if ($cmbOrganizar.SelectedIndex -eq 2) {
        $a.Add('--parse-metadata'); $a.Add((Q 'title:(?P<artist>.+?) - (?P<title>.+)'))
        $a.Add('--replace-in-metadata'); $a.Add('uploader'); $a.Add((Q '(?i)\s*(- topic|vevo)$')); $a.Add('""')
    }
    if ($chkLimpiar.Checked) {
        $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add((Q $reLimpiar));     $a.Add('""')
        $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add((Q $reLimpiarCola)); $a.Add('""')
        $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add((Q '\s{2,}'));       $a.Add((Q ' '))
    }
    # Truncar títulos largos (evitar límite 260 de Windows)
    $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add((Q '^(.{1,120}).+$')); $a.Add((Q '\1'))
    $a.Add('--replace-in-metadata'); $a.Add('playlist_title'); $a.Add((Q '^(.{1,80}).+$')); $a.Add((Q '\1'))
    $a.Add('--replace-in-metadata'); $a.Add('artist'); $a.Add((Q '^(.{1,60}).+$')); $a.Add((Q '\1'))
    $a.Add('--replace-in-metadata'); $a.Add('uploader'); $a.Add((Q '^(.{1,60}).+$')); $a.Add((Q '\1'))

    if ($chkPortada.Checked) {
        if ($fmt -ne 'wav' -and $fmt -ne 'original') { $a.AddRange([string[]]@('--embed-thumbnail', '--convert-thumbnails', 'jpg')) }
        elseif ($fmt -eq 'original') { $a.Add('--embed-metadata') }
        else { $a.Add('--embed-metadata') }
        if ($fmt -ne 'original') { $a.Add('--embed-metadata') }
    }

    switch ($cmbOrganizar.SelectedIndex) {
        0 { $plantilla = '%(title).120B.%(ext)s' }
        1 { $plantilla = '%(playlist_title).80B/%(playlist_index&{} - |)s%(title).100B.%(ext)s' }
        2 { $plantilla = '%(artist,uploader).60B/%(title).100B.%(ext)s' }
    }
    $a.Add('-o'); $a.Add((Q $plantilla))

    $archHist = Archivo-Historial $fmt
    if ($chkSaltar.Checked -or $sync) { $a.Add('--download-archive'); $a.Add((Q $archHist)) }
    if ($indices) { $a.Add('-I'); $a.Add($indices) }

    $finales = @($enlaces | ForEach-Object { Arreglar-Enlace $_ })
    foreach ($e in $finales) { $a.Add((Q $e)) }
    return @{ args = $a; finales = $finales; fmt = $fmt; carpeta = $carpeta }
}

function Lanzar-Descarga($enlaces, $sync = $false, $indices = '') {
    $ytdlp = Preparar-Ytdlp
    if (-not $ytdlp) { return }

    $carpeta = $txtCarpeta.Text.TrimEnd('\')
    try { New-Item -ItemType Directory -Force -Path $carpeta -ErrorAction Stop | Out-Null } catch {
        Aviso 'No se puede usar esa carpeta. Pulsa "Cambiar..." y elige otra.' 'Warning'; return
    }
    Guardar-Config

    $built = Construir-Args $enlaces $sync $indices
    $porUrl = @{}
    if ($sync) { foreach ($x in $script:listas) { if ($built.finales -contains $x.url) { $porUrl[$x.url] = $x } } }

    $script:dl = @{
        nuevas = 0; saltadas = 0; nErrores = 0; errores = New-Object System.Collections.ArrayList
        actual = 1; total = 1; titulo = ''; cancelada = $false; yaEstaba = $false; enCurso = $null
        idsSaltados = New-Object System.Collections.ArrayList
        sync = $sync; porUrl = $porUrl; listaActual = $null; nuevasPorLista = @{}
        inicio = Get-Date; carpeta = $built.carpeta; formato = $built.fmt; calidad = $null
        carpetaEscaneo = $null; motor = 'yt-dlp'
    }
    $script:ultimaPeticion = @{ enlaces = $enlaces; sync = $sync; indices = $indices; motor = 'yt-dlp' }
    $script:ultimosArgs = ($built.args -join ' ')

    Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
    $lstResultados.Items.Clear()
    $lblCalidad.Text = ''
    if (-not $script:enMini) { Mostrar-Pestana 1 }
    Modo 'descarga'
    Barra-Tarea 1
    Estado 'Empezando la descarga...'
    Iniciar-Tarea $ytdlp $script:ultimosArgs { param($l) Procesar-Linea $l } { param($c) Terminar-Descarga $c } 0 'descarga'
}

function Construir-Args-Spotdl($enlaces, $sync) {
    $fmtUI = $formatos[$cmbFormato.SelectedIndex]
    $fmt = if ($fmtUI -eq 'original') { 'm4a' } else { $fmtUI }
    $carpeta = $txtCarpeta.Text.TrimEnd('\')
    $a = New-Object System.Collections.Generic.List[string]
    [void]$a.Add('download')
    foreach ($e in $enlaces) { [void]$a.Add((Q $e)) }
    [void]$a.Add('--format'); [void]$a.Add($fmt)
    if ($fmtUI -eq 'original' -or $fmt -in @('m4a', 'opus')) {
        [void]$a.Add('--bitrate'); [void]$a.Add('disable')
    }
    $ff = Ruta-De 'ffmpeg'
    if ($ff) { [void]$a.Add('--ffmpeg'); [void]$a.Add((Q $ff)) }

    switch ($cmbOrganizar.SelectedIndex) {
        0 { $plantilla = '{title}.{output-ext}' }
        1 { $plantilla = '{list-name}/{list-position} - {title}.{output-ext}' }
        2 { $plantilla = '{artist}/{title}.{output-ext}' }
    }
    $salida = $carpeta.TrimEnd('\') + '\' + $plantilla
    [void]$a.Add('--output'); [void]$a.Add((Q $salida))

    if ($chkSaltar.Checked -or $sync) {
        [void]$a.Add('--overwrite'); [void]$a.Add('skip')
        [void]$a.Add('--archive'); [void]$a.Add((Q (Archivo-Historial "spotify-$fmt")))
    } else {
        [void]$a.Add('--overwrite'); [void]$a.Add('force')
    }
    [void]$a.Add('--print-errors')
    [void]$a.Add('--simple-tui')

    return @{ args = ($a -join ' '); fmt = $fmt; carpeta = $carpeta; fmtUI = $fmtUI }
}

function Procesar-Linea-Spotdl($l) {
    $d = $script:dl
    if (-not $l) { return }
    if ($l -match '(?i)Downloaded\s+[""'']?(.+?)[""'']?\s*:' ) {
        $nombre = $matches[1].Trim()
        $d.nuevas++
        $d.titulo = $nombre
        try { $script:ultimaCarpetaReal = $d.carpeta } catch {}
        Resultado ([string][char]0x2713 + '  ' + $nombre + '  [Spotify→YT]')
        Estado "Guardado:`n$nombre"
        if ($d.total -gt 1) { Poner-Barra (100.0 * $d.nuevas / [Math]::Max($d.total, 1)) }
        else { Poner-Barra 90 }
        return
    }
    if ($l -match '(?i)Skipping|already (downloaded|exists)|Song already') {
        $d.saltadas++
        Resultado ('–  Ya la tenías (spotDL): ' + $l.Trim())
        return
    }
    if ($l -match '(?i)Found\s+(\d+)\s+songs?' -or $l -match '(?i)Downloading\s+(\d+)\s+songs?') {
        $d.total = [int]$matches[1]
        Estado "Spotify: $($d.total) canciones a procesar..."
        return
    }
    if ($l -match '(?i)^Downloading\s+(.+)$' -or $l -match '(?i)Searching for\s+(.+)$') {
        $d.titulo = $matches[1].Trim()
        $d.actual++
        Estado ("Descargando vía Spotify→YouTube:`n{0}" -f $d.titulo)
        if ($d.total -gt 1) { Poner-Barra (100.0 * ($d.actual - 1) / $d.total) }
        else { Poner-Barra ([Math]::Min(80, $d.actual * 10)) }
        return
    }
    if ($l -match '(?i)(Error|FAILED|Could not|LookupError|HTTP Error)') {
        $d.nErrores++
        $txt = $l.Trim()
        if ($txt.Length -gt 180) { $txt = $txt.Substring(0, 180) + '…' }
        Resultado ([string][char]0x2717 + '  ' + $txt)
        if (-not $d.errores.Contains($txt)) { [void]$d.errores.Add($txt) }
    }
}

function Lanzar-Descarga-Spotify($enlaces, $sync = $false) {
    $spotdl = Preparar-Spotdl
    if (-not $spotdl) { return }
    # spotDL necesita FFmpeg; yt-dlp suele venir embebido en el .exe, pero si está en bin lo usamos vía PATH
    if (-not (Ruta-De 'ffmpeg')) {
        Aviso 'Falta FFmpeg (necesario para spotDL). Cierra y vuelve a abrir el programa para instalarlo.' 'Warning'
        return
    }
    Refrescar-Path

    $carpeta = $txtCarpeta.Text.TrimEnd('\')
    try { New-Item -ItemType Directory -Force -Path $carpeta -ErrorAction Stop | Out-Null } catch {
        Aviso 'No se puede usar esa carpeta. Pulsa "Cambiar..." y elige otra.' 'Warning'; return
    }
    Guardar-Config

    $built = Construir-Args-Spotdl $enlaces $sync
    $porUrl = @{}
    if ($sync) { foreach ($x in $script:listas) { if ($enlaces -contains $x.url) { $porUrl[$x.url] = $x } } }

    $script:dl = @{
        nuevas = 0; saltadas = 0; nErrores = 0; errores = New-Object System.Collections.ArrayList
        actual = 0; total = [Math]::Max($enlaces.Count, 1); titulo = ''; cancelada = $false; yaEstaba = $false; enCurso = $null
        idsSaltados = New-Object System.Collections.ArrayList
        sync = $sync; porUrl = $porUrl; listaActual = $null; nuevasPorLista = @{}
        inicio = Get-Date; carpeta = $built.carpeta; formato = $built.fmt; calidad = 'Spotify→YouTube'
        carpetaEscaneo = $null; motor = 'spotdl'
    }
    $script:ultimaPeticion = @{ enlaces = $enlaces; sync = $sync; indices = ''; motor = 'spotdl' }
    $script:ultimosArgs = $built.args

    Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
    $lstResultados.Items.Clear()
    $lblCalidad.Text = 'Spotify → YouTube (spotDL). La calidad es la del vídeo encontrado.'
    if (-not $script:enMini) { Mostrar-Pestana 1 }
    Modo 'descarga'
    Barra-Tarea 1
    Estado 'Spotify: resolviendo y descargando con spotDL...'
    Iniciar-Tarea $spotdl $script:ultimosArgs { param($l) Procesar-Linea-Spotdl $l } { param($c) Terminar-Descarga $c } 0 'descarga'
}

function Encolar-O-Descargar($enlaces, $sync = $false, $indices = '') {
    if (-not (Comprobar-Enlaces $enlaces)) { return }
    $sp = @($enlaces | Where-Object { (Tipo-Enlace $_) -eq 'spotify' })
    $otros = @($enlaces | Where-Object { (Tipo-Enlace $_) -ne 'spotify' })

    if ($script:modo -eq 'descarga' -or $script:modo -eq 'leyendo') {
        $script:colaDescargas.Enqueue(@{ enlaces = $enlaces; sync = $sync; indices = $indices })
        Pintar-Cola
        Estado "Añadido a la cola ($(Plural $script:colaDescargas.Count 'pendiente' 'pendientes'))."
        if (-not $script:enMini) { $txtEnlace.Clear() }
        else { $txtMini.Clear() }
        return
    }

    if ($sp.Count -gt 0 -and $otros.Count -gt 0) {
        $script:colaDescargas.Enqueue(@{ enlaces = $otros; sync = $sync; indices = $indices })
        Pintar-Cola
        Estado 'Spotify primero; YouTube/SoundCloud irán después en la cola.'
        Lanzar-Descarga-Spotify $sp $sync
        return
    }
    if ($sp.Count -gt 0) {
        Lanzar-Descarga-Spotify $sp $sync
        return
    }
    Lanzar-Descarga $otros $sync $indices
}

function Empezar-Descarga {
    $enlaces = Leer-Enlaces
    Encolar-O-Descargar $enlaces
}

function Procesar-Cola {
    if ($script:colaDescargas.Count -eq 0) { return $false }
    $item = $script:colaDescargas.Dequeue()
    Pintar-Cola
    $sp = @($item.enlaces | Where-Object { (Tipo-Enlace $_) -eq 'spotify' })
    if ($sp.Count -gt 0 -and $sp.Count -eq $item.enlaces.Count) {
        Lanzar-Descarga-Spotify $item.enlaces $item.sync
    } elseif ($sp.Count -gt 0) {
        $otros = @($item.enlaces | Where-Object { (Tipo-Enlace $_) -ne 'spotify' })
        if ($otros.Count -gt 0) {
            $script:colaDescargas.Enqueue(@{ enlaces = $otros; sync = $item.sync; indices = $item.indices })
            Pintar-Cola
        }
        Lanzar-Descarga-Spotify $sp $item.sync
    } else {
        Lanzar-Descarga $item.enlaces $item.sync $item.indices
    }
    return $true
}

function Guardar-Informe($codigo) {
    try {
        $rS = Join-Path $dirApp 'descarga-salida.txt'
        $rE = Join-Path $dirApp 'descarga-errores.txt'
        $ver = Obtener-Version-Ytdlp
        $txt = New-Object System.Collections.Generic.List[string]
        $txt.Add('Descarga del ' + (Hoy))
        $txt.Add("Versión del programa: $versionApp")
        $motor = if ($script:dl -and $script:dl.motor) { $script:dl.motor } else { 'yt-dlp' }
        $txt.Add("Versión de yt-dlp: $ver")
        $txt.Add("Motor: $motor")
        $txt.Add("Código de salida: $codigo")
        $txt.Add('')
        $txt.Add('Comando:')
        $prefijo = if ($motor -eq 'spotdl') { 'spotdl ' } else { 'yt-dlp ' }
        $txt.Add($prefijo + $script:ultimosArgs)
        $txt.Add('')
        $txt.Add('===== Lo que ha ido haciendo =====')
        if (Test-Path -LiteralPath $rS) { foreach ($x in (Get-Content -LiteralPath $rS -Encoding UTF8)) { $txt.Add($x) } }
        $txt.Add('')
        $txt.Add('===== Errores y avisos =====')
        if (Test-Path -LiteralPath $rE) { foreach ($x in (Get-Content -LiteralPath $rE -Encoding UTF8)) { $txt.Add($x) } }
        Set-Content -LiteralPath $archInforme -Value $txt -Encoding UTF8
    } catch { Registrar-Error "Informe: $($_.Exception.Message)" }
}

function Limpiar-Restos($d) {
    Start-Sleep -Milliseconds 600
    $desde = $d.inicio.AddSeconds(-5)
    $base = if ($script:ultimaCarpetaReal -and (Test-Path -LiteralPath $script:ultimaCarpetaReal)) { $script:ultimaCarpetaReal } else { $d.carpeta }
    $audio = @('.m4a', '.opus', '.ogg', '.aac', '.mp3', '.flac', '.wav', '.webm', '.mp4')
    try {
        Get-ChildItem -LiteralPath $base -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $desde } |
            Where-Object {
                $n = $_.Name.ToLower(); $e = $_.Extension.ToLower()
                ($n -match '\.part($|-frag)') -or ($e -in @('.part', '.ytdl', '.temp')) -or ($n -match '\.temp\.') -or
                ($e -in @('.webp', '.jpg', '.jpeg', '.png')) -or ($e -in $audio -and $d.formato -ne 'original' -and $e -ne ".$($d.formato)")
            } | Remove-Item -Force -ErrorAction SilentlyContinue
        if ($d.enCurso -and (Test-Path -LiteralPath $d.enCurso)) { Remove-Item -LiteralPath $d.enCurso -Force -ErrorAction SilentlyContinue }
        Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTime -ge $desde } |
            Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    } catch { Registrar-Error "Limpiar restos: $($_.Exception.Message)" }
}

function Terminar-Descarga($codigo) {
    $d = $script:dl
    Guardar-Informe $codigo
    $btnAbrirUltima.Enabled = [bool]($script:ultimaCarpetaReal -and (Test-Path -LiteralPath $script:ultimaCarpetaReal))

    if ($d.cancelada) {
        Estado 'Cancelando: limpiando los archivos a medias...'
        Limpiar-Restos $d
        Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
        Barra-Tarea 0
        Modo $null
        Estado 'Descarga cancelada. Las canciones terminadas siguen en la carpeta.'
        $script:colaDescargas.Clear()
        Pintar-Cola
        return
    }
    if ($codigo -eq -999) {
        Barra-Tarea 0
        Modo $null
        Estado 'El programa: no se pudo iniciar la descarga.'
        return
    }

    if ($d.sync) {
        foreach ($u in $d.porUrl.Keys) {
            $x = $d.porUrl[$u]
            $x.ultima = Hoy
            if ($d.motor -eq 'spotdl') {
                $x.nuevas = [string][int]$d.nuevas
            } else {
                $x.nuevas = [string][int]$d.nuevasPorLista[$u]
            }
        }
        Guardar-Config
        Pintar-Listas
    }

    Set-BarraValor $barra 1000; Set-BarraValor $barraMini 1000
    $partes = @()
    if ($d.nuevas -gt 0)   { $partes += (Plural $d.nuevas 'canción nueva' 'canciones nuevas') }
    if ($d.saltadas -gt 0) { $partes += (Plural $d.saltadas 'ya la tenías' 'ya las tenías') }
    if ($d.nErrores -gt 0) { $partes += (Plural $d.nErrores 'con problemas' 'con problemas') }

    if ($partes.Count -eq 0) {
        if ($codigo -ne 0) { Estado 'Algo ha fallado. Comprueba el enlace o reinicia para actualizar.' }
        else { Estado 'Terminado.' }
    } elseif ($d.nuevas -eq 0 -and $d.nErrores -eq 0) {
        Estado 'No hay canciones nuevas: ya tenías todas en este formato.'
    } else {
        Estado ('Terminado: ' + ($partes -join ', ') + '.')
    }
    if ($d.nuevas -gt 0 -and -not $d.sync) { $txtEnlace.Clear(); $txtMini.Clear() }

    $conProblemas = ($d.nErrores -gt 0 -or ($partes.Count -eq 0 -and $codigo -ne 0))
    Barra-Tarea $(if ($conProblemas) { 4 } else { 2 }) 1000
    Avisar-Final $conProblemas

    # No preguntar en Mis listas, ni si el usuario lo desactivó
    $preguntar = (-not $d.sync) -and (-not $chkNoPreguntar.Checked) -and (-not $config.noPreguntarBorradas)
    if ($preguntar) {
        $borradas = Canciones-Borradas $d
        if ($borradas) { Ofrecer-Rebajar $d }
    }
    if ($d.errores.Count -gt 0) {
        Aviso ("Algunas canciones no se han podido descargar:`n`n- " + ($d.errores -join "`n- ")) 'Warning'
    }
    Barra-Tarea 0
    Modo $null

    if (Procesar-Cola) { return }
}

function Canciones-Borradas($d) {
    if ($d.idsSaltados.Count -eq 0) { return $false }
    $ext = @('.mp3', '.m4a', '.opus', '.flac', '.wav', '.webm', '.ogg', '.aac')
    $base = if ($script:ultimaCarpetaReal -and (Test-Path -LiteralPath $script:ultimaCarpetaReal)) {
        $script:ultimaCarpetaReal
    } else { $d.carpeta }
    $hay = 0
    try {
        # Solo la carpeta de esta descarga (no toda la biblioteca)
        $hay = @(Get-ChildItem -LiteralPath $base -File -ErrorAction SilentlyContinue |
            Where-Object { $ext -contains $_.Extension.ToLower() }).Count
    } catch {}
    return ($hay -lt [Math]::Min($d.idsSaltados.Count, 3) -and $hay -eq 0)
}

function Ids-Descargados {
    $fmt = $formatos[$cmbFormato.SelectedIndex]
    $ids = @{}
    $arch = Archivo-Historial $fmt
    if (Test-Path -LiteralPath $arch) {
        foreach ($x in (Get-Content -LiteralPath $arch -Encoding UTF8)) {
            $p = $x.Trim() -split '\s+'
            if ($p.Count -ge 2) { $ids[$p[1]] = $true }
        }
    }
    return $ids
}

function Olvidar-Ids($ids) {
    $fmt = $formatos[$cmbFormato.SelectedIndex]
    $arch = Archivo-Historial $fmt
    if (-not (Test-Path -LiteralPath $arch)) { return }
    $quitar = @{}
    foreach ($i in $ids) { $quitar[[string]$i] = $true }
    $lineas = @(Get-Content -LiteralPath $arch -Encoding UTF8 | Where-Object {
        $partes = $_.Trim() -split '\s+'
        -not ($partes.Count -ge 2 -and $quitar.ContainsKey($partes[1]))
    })
    Set-Content -LiteralPath $arch -Value $lineas -Encoding UTF8
}

function Ofrecer-Rebajar($d) {
    $n = $d.idsSaltados.Count
    $r = [System.Windows.Forms.MessageBox]::Show(
        $(if ($script:enMini) { $formMini } else { $form }),
        "Se han saltado $(Plural $n 'canción' 'canciones') porque ya las descargaste en este formato, pero no están en la carpeta de esta descarga.`n`nSí = volver a descargarlas`nNo = dejarlas saltadas`nCancelar = no volver a preguntar (útil si las moviste a Rekordbox)",
        'Descargar música', 'YesNoCancel', 'Question')
    if ($r -eq 'Cancel') {
        $chkNoPreguntar.Checked = $true
        $config.noPreguntarBorradas = $true
        Guardar-Config
        return
    }
    if ($r -ne 'Yes') { return }
    Olvidar-Ids $d.idsSaltados
    $p = $script:ultimaPeticion
    if ($p.motor -eq 'spotdl') { Lanzar-Descarga-Spotify $p.enlaces $p.sync }
    else { Lanzar-Descarga $p.enlaces $p.sync $p.indices }
}

# ================================================================
#  Elegir canciones
# ================================================================
function Elegir-Canciones {
    $enlaces = Leer-Enlaces
    if (-not (Comprobar-Enlaces $enlaces)) { return }
    if ($enlaces.Count -gt 1) { Aviso 'Para elegir canciones, deja un solo enlace de lista.'; return }
    if ((Tipo-Enlace $enlaces[0]) -eq 'spotify') {
        Aviso "Con Spotify no se puede elegir canción a canción.`n`nPulsa Descargar: spotDL bajará la pista, el álbum o la playlist completa (buscando cada tema en YouTube)."
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
    $args2 = '--flat-playlist --color never --encoding utf-8 --no-warnings --print ' + (Q '%(playlist_index|0)s|||%(id)s|||%(title|)s') + ' ' + (Q $url)
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
    $f.Controls.Add($cl)
    foreach ($x in $lista) {
        $t = if ($x.titulo) { $x.titulo } else { "Canción $($x.idx)" }
        $etiqueta = ('{0:00}   {1}' -f $x.idx, $t)
        $tiene = $ya.ContainsKey($x.id)
        if ($tiene) { $etiqueta += '   (ya la tienes en este formato)' }
        [void]$cl.Items.Add($etiqueta, (-not $tiene))
    }
    $cl.Add_ItemCheck({ param($s, $e)
        $n = $cl.CheckedItems.Count + $(if ($e.NewValue -eq 'Checked') { 1 } else { -1 })
        $lblCuenta.Text = "$n de $($cl.Items.Count) marcadas"
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
        if (Parece-Lista $c) {
            if (-not (Pregunta "Has copiado una lista (puede tener muchas canciones).`n`n¿Descargarla / añadirla a la cola?")) { return }
        }
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

# ================================================================
#  Ayuda / Desinstalar / Accesos
# ================================================================
function Mostrar-Ayuda {
    $f = New-Object System.Windows.Forms.Form
    Escalar-Dpi $f
    $f.Text = 'Ayuda - Descargar música'
    $f.ClientSize = New-Object System.Drawing.Size(560, 560)
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterParent'
    $f.BackColor = $colPanel; $f.ForeColor = $colTexto; $f.Font = $fNormal
    if ($script:icono) { $f.Icon = $script:icono }
    $t = New-Object System.Windows.Forms.TextBox
    $t.Multiline = $true; $t.ReadOnly = $true; $t.ScrollBars = 'Vertical'
    $t.BorderStyle = 'None'; $t.BackColor = $colPanel; $t.ForeColor = $colTexto
    $t.TabStop = $false
    $t.HideSelection = $true
    $t.Location = New-Object System.Drawing.Point(20, 18)
    $t.Size = New-Object System.Drawing.Size(520, 480)
    $t.Text = @"
CÓMO DESCARGAR
1. Copia el enlace de YouTube, SoundCloud o Spotify.
2. Pégalo aquí (o usa la ventana Mini con "Bajar al copiar").
3. Pulsa Descargar. Si ya está descargando, se añade a la cola.

Spotify: se descarga con spotDL (se instala solo la primera vez). Busca cada canción en YouTube/YouTube Music y la guarda con metadatos de Spotify. La calidad es la del vídeo encontrado, no la de Spotify Premium.

FORMATO PARA DJs
- "Original (sin convertir)" guarda el audio tal cual lo envía la web: es la mejor calidad posible.
- Con Spotify, "Original" se guarda como M4A sin re-codificar.
- FLAC/WAV/MP3 320 NO mejoran el sonido de YouTube ni SoundCloud (suelen ser 128–160 kbps).

MIS LISTAS
Guarda playlists y actualízalas: solo bajan canciones nuevas de ese formato.
También vale con listas de Spotify.
Si mueves temas a Rekordbox, marca "No preguntar si faltan canciones...".

SEGURIDAD
Las actualizaciones del programa deben ir firmadas por el autor. Sin firma válida no se instalan.
Solo se aceptan enlaces https de YouTube, SoundCloud y Spotify.

Si algo falla: menú → Ver detalles técnicos / Ver registro de errores.
"@ -replace "(?<!`r)`n", "`r`n"
    $f.Controls.Add($t)
    $b = Nuevo-BotonPrincipal $f 'ENTENDIDO' 400 510 140 36 $fBotonMed
    $b.DialogResult = 'OK'
    $f.AcceptButton = $b
    $f.Add_Shown({
        $t.SelectionStart = 0
        $t.SelectionLength = 0
        $b.Focus()
    })
    $owner = if ($script:enMini) { $formMini } else { $form }
    [void]$f.ShowDialog($owner)
}

function Desinstalar {
    if ($script:modo -ne $null) { Aviso 'Espera a que termine o cancela antes de desinstalar.'; return }
    if (-not (Pregunta "¿Desinstalar Descargar música?`n`nSe quitarán accesos directos, ajustes, listas e historial.`nTu música NO se borra.")) { return }
    $quitarPiezas = Pregunta "¿Quitar también yt-dlp, FFmpeg, Deno y spotDL de la carpeta del programa?"
    Abandonar-Tarea
    if ($quitarPiezas) {
        Mostrar-Popup-Encima 'Desinstalando' 'Quitando las piezas descargadas...'
        try { Remove-Item -LiteralPath $dirBin -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        Cerrar-Popup
    }
    Terminar-Desinstalacion
}

function Terminar-Desinstalacion {
    $script:desinstalado = $true
    foreach ($lnk in @(
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'MusicDL.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Programs')) 'MusicDL.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Descargar música.lnk'),
        (Join-Path ([Environment]::GetFolderPath('Programs')) 'Descargar música.lnk'))) {
        Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $dirApp -Recurse -Force -ErrorAction SilentlyContinue
    $form.Enabled = $true
    Aviso "MusicDL se ha desinstalado. Tu música sigue en su carpeta.`n`nSe cerrará y se borrará este archivo."
    $bat = $env:DM_BAT
    if ($bat -and (Test-Path -LiteralPath $bat)) {
        Start-Process cmd.exe -ArgumentList "/c ping 127.0.0.1 -n 3 > nul & del /f /q `"$bat`"" -WindowStyle Hidden
    }
    $form.Close(); $formMini.Close()
}

function Escribir-Acceso($lnk, $bat) {
    $sh = New-Object -ComObject WScript.Shell
    $s = $sh.CreateShortcut($lnk)
    $s.TargetPath = $bat
    $s.WorkingDirectory = Split-Path $bat
    if (Test-Path -LiteralPath $archIcono) { $s.IconLocation = "$archIcono,0" }
    $s.Description = 'MusicDL — YouTube, SoundCloud y Spotify'
    $s.WindowStyle = 7
    $s.Save()
    if ($script:hayWin) { try { [DMWin]::SetShortcutAppId($lnk, 'DescargarMusica.App') } catch {} }
}

function Crear-Acceso {
    $bat = $env:DM_BAT
    if (-not $bat -or -not (Test-Path -LiteralPath $bat)) { return }
    try { Escribir-Acceso (Join-Path ([Environment]::GetFolderPath('Programs')) 'MusicDL.lnk') $bat } catch {}
    try {
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'MusicDL.lnk'
        if ($config.accesoCreado -and -not (Test-Path -LiteralPath $lnk)) { return }
        Escribir-Acceso $lnk $bat
        $config.accesoCreado = $true
        Guardar-Config
    } catch {}
}

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
    $dlg.Description = 'Elige la carpeta donde se guardará la música'
    if (Test-Path -LiteralPath $txtCarpeta.Text) { $dlg.SelectedPath = $txtCarpeta.Text }
    if ($dlg.ShowDialog($form) -eq 'OK') { $txtCarpeta.Text = $dlg.SelectedPath; Guardar-Config }
})

$lnkOlvidar.Add_LinkClicked({
    $fmt = $formatos[$cmbFormato.SelectedIndex]
    if (Pregunta "¿Olvidar el historial del formato '$fmt'?`n`nLa próxima vez se volverán a descargar esas canciones en este formato. Los archivos no se borran.") {
        Remove-Item -LiteralPath (Archivo-Historial $fmt) -Force -ErrorAction SilentlyContinue
        Estado "Historial de $fmt borrado."
    }
})

$btnDescargar.Add_Click({ Empezar-Descarga })
$btnCancelar.Add_Click({
    if ($script:modo -eq 'descarga') {
        $script:dl.cancelada = $true
        Estado 'Cancelando...'
        $btnCancelar.Enabled = $false
        Matar-Tarea
    } elseif ($script:modo -eq 'leyendo') {
        $script:lecturaCancelada = $true
        $btnCancelar.Enabled = $false
        Matar-Tarea
    }
})
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
    $c = $txtCarpeta.Text
    try { New-Item -ItemType Directory -Force -Path $c | Out-Null } catch {}
    Start-Process explorer.exe (Q $c)
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
    try {
        Marcar-Arranque-Ok
        if ($script:hayWin) {
            try { [DMWin]::TemaOscuro($form.Handle) } catch {}
            try { [DMWin]::TemaOscuro($txtEnlace.Handle) } catch {}
            try { [DMWin]::TemaOscuro($txtCarpeta.Handle) } catch {}
            try { [DMWin]::TemaOscuro($txtNuevaLista.Handle) } catch {}
            try { [DMWin]::TemaOscuro($lstResultados.Handle) } catch {}
            try { [DMWin]::TemaOscuro($lvListas.Handle) } catch {}
            try { [DMWin]::Pista($txtNuevaLista.Handle, 'Pega aquí el enlace de una lista') } catch {}
        }
        Crear-Acceso
        Actualizar-Ayuda
        Pintar-Listas
        Pintar-Cola
        Comprobar-App
        try { Refrescar-Path } catch {}
        $lblAct.Text = 'Todo listo'

        # Usar $script: para que el Tick no pierda la referencia (bug típico de PowerShell)
        if ($script:timerAct) { try { $script:timerAct.Stop(); $script:timerAct.Dispose() } catch {} }
        $script:timerAct = New-Object System.Windows.Forms.Timer
        $script:timerAct.Interval = 2000
        $script:timerAct.Add_Tick({
            try {
                if ($script:timerAct) { $script:timerAct.Stop() }
                $lblAct.Text = 'Comprobando descargador...'
                [System.Windows.Forms.Application]::DoEvents()
                Actualizar-Herramientas-Directas
            } catch {
                $lblAct.Text = 'Todo al día'
                Registrar-Error "Timer actualización: $($_.Exception.Message)"
            }
        })
        $script:timerAct.Start()

        if ($config.ventanaMini) { Mostrar-Mini }
    } catch {
        Registrar-Error "Al mostrar ventana: $($_.Exception.Message)"
        try { $lblAct.Text = 'Listo' } catch {}
    }
})

# ================================================================
#  Arrancar
# ================================================================
[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $e)
    Registrar-Error "UI: $($e.Exception.Message)"
})
[AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $e)
    try { Registrar-Error "Fatal: $($e.ExceptionObject)" } catch {}
})

try {
    Crear-Icono
    if ($script:icono) { $form.Icon = $script:icono; $formMini.Icon = $script:icono }
    if (Instalar-Si-Falta) {
        $form.ShowInTaskbar = $true
        Marcar-Arranque-Ok
        [System.Windows.Forms.Application]::Run($form)
    }
} catch {
    Registrar-Error "Arranque: $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show("Ha ocurrido un error inesperado:`n`n$($_.Exception.Message)`n`nSe ha guardado en el registro de errores.", 'Descargar música', 'OK', 'Error') | Out-Null
} finally {
    if ($script:mutex) { try { $script:mutex.ReleaseMutex() } catch {}; try { $script:mutex.Dispose() } catch {} }
}
