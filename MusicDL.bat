<# :
@echo off
REM ================================================================
REM  MusicDL - aplicacion abierta y legible (no malware).
REM  Este .bat solo arranca PowerShell para mostrar la ventana.
REM  Codigo fuente completo debajo; sin ofuscacion.
REM ================================================================
set "DM_BAT=%~f0"
set "DM_DIR=%APPDATA%\MusicDL"
set "DM_PUB_B64=PFJTQUtleVZhbHVlPjxNb2R1bHVzPnBvMkJodUc3ZVdUL2JjNjVaVWg4UWVzRHk1VkZvRzEreFU3N1ltVzlPTFdVK3cwa1p4ME43TWZ6QUQ0cFNabGVUYnYzZ3htOVV3VEZGU3VBcEVEbHNEWUFZZW1kNVdnTVU3MFRnb1hWN2NFYlgvRHV2QndSbzM0ZXpDQ2pEYWZjUmtwTDVUM2NYajF2TmNaUElpQ09wdzFVempQelVsRlQ4K2ZJanNCb2NtVlNhdDFhS2xmWldVWHBRdEVzRjBPZ01vMW1MK2xQTVYxNVJ5S1VPR1pCL1FPZzBKblV2VHV4Mnl3R1VRdE9vN3V2WVFOMUNsMDhYN2lLcEFPYkpaWG55Mk51MkJiRElBWWorSVVSdnZaRjNFVkFya3poV3ROalVTZ2YyLzVlMUdEL2pUV0plVllia1JuRzE5ZnNjMlRHb253eFpkRUdNOGFDRDB5NlVMb1ZTUT09PC9Nb2R1bHVzPjxFeHBvbmVudD5BUUFCPC9FeHBvbmVudD48L1JTQUtleVZhbHVlPg=="
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

REM Sin -ExecutionPolicy Bypass ni iex: ScriptBlock.Create + verifica .sig si existe
start "" powershell -NoProfile -STA -WindowStyle Hidden -Command "& { $ErrorActionPreference='Stop'; $bat=$env:DM_BAT; $raw=[IO.File]::ReadAllText($bat,[Text.Encoding]::UTF8); $sig=$bat+'.sig'; if (Test-Path -LiteralPath $sig) { $pub=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:DM_PUB_B64)); $rsa=[Security.Cryptography.RSA]::Create(); $rsa.FromXmlString($pub); $bytes=[IO.File]::ReadAllBytes($bat); $firma=[Convert]::FromBase64String(((Get-Content -LiteralPath $sig -Raw) -replace '\s','')); if (-not $rsa.VerifyData($bytes,$firma,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)) { Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show('La firma de MusicDL no es valida. No se inicia.','MusicDL',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error); exit 1 } }; $sb=[scriptblock]::Create($raw); & $sb }"
exit /b
#>

# ================================================================
#  MusicDL  -  YouTube, SoundCloud y Spotify (spotDL)  (v3.36)
#  Usa yt-dlp, FFmpeg, Deno y spotDL (URL fija + SHA256; winget como respaldo).
#  Actualizaciones firmadas con clave RSA del autor.
#  Arquitectura: un solo archivo a proposito (distribucion simple); secciones
#  marcadas con #region / #endregion. Sin ofuscacion.
# ================================================================

$versionApp = '3.36'
$script:sugerirUpdateYtdlp = $false
$script:yaOfrecioUpdateSesion = $false
# Enlace Raw del .bat en GitHub. Si está vacío, no busca versiones nuevas.
$urlApp = 'https://raw.githubusercontent.com/Brawliot/MusicDL/main/MusicDL.bat'
# Enlace Raw de la firma (.sig). Si vacío, se usa $urlApp + '.sig'
$urlFirma = ''

# Clave pública RSA (XML). Solo el autor tiene la privada (clave-privada.xml).
$clavePublicaXml = '<RSAKeyValue><Modulus>po2BhuG7eWT/bc65ZUh8QesDy5VFoG1+xU77YmW9OLWU+w0kZx0N7MfzAD4pSZleTbv3gxm9UwTFFSuApEDlsDYAYemd5WgMU70TgoXV7cEbX/DuvBwRo34ezCCjDafcRkpL5T3cXj1vNcZPIiCOpw1UzjPzUlFT8+fIjsBocmVSat1aKlfZWUXpQtEsF0OgMo1mL+lPMV15RyKUOGZB/QOg0JnUvTux2ywGUQtOo7uvYQN1Cl08X7iKpAObJZXny2Nu2BbDIAYj+IURvvZF3EVArkzhWtNjUSgf2/5e1GD/jTWJeVYbkRnG19fsc2TGonwxZdEGM8aCD0y6ULoVSQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'

# Preferencia global Continue: timers/UI WinForms no deben tumbar el proceso
# por errores no fatales. Las rutas críticas (SHA256, firma, I/O de instalación)
# usan try/catch + Catch-Log y, donde aplica, -ErrorAction Stop explícito.
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

# ---------- Una sola instancia ----------
$script:mutex = $null
try {
    $created = $false
    $script:mutex = New-Object System.Threading.Mutex($true, 'Global\MusicDL.SingleInstance', [ref]$created)
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
            if (t == "MusicDL" || t == "MusicDL (mini)" || t == "Descargar música" || t == "Descargar música (mini)") {
                ShowWindow(h, 9); SetForegroundWindow(h); return false;
            }
            return true;
        }, IntPtr.Zero);
    }
}
"@
        try { [DMBring]::FocusApp() } catch { Catch-Log 'bloque' $_ }
        [System.Windows.Forms.MessageBox]::Show(
            'MusicDL ya está abierto. Se ha traído esa ventana al frente.',
            'MusicDL', 'OK', 'Information') | Out-Null
        exit
    }
} catch { Catch-Log 'bloque' $_ }

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
        } catch { Catch-Log 'bloque' $_ }
    }

    static DMTaskbarList3 tb;
    public static void Progreso(IntPtr h, int estado, ulong valor, ulong total) {
        try {
            if (tb == null) { tb = (DMTaskbarList3)new DMTaskbarListClass(); tb.HrInit(); }
            tb.SetProgressState(h, estado);
            if (estado == 2 || estado == 4) tb.SetProgressValue(h, valor, total);
        } catch { Catch-Log 'bloque' $_ }
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
    [void][DMWin]::SetCurrentProcessExplicitAppUserModelID('MusicDL.App')
    $script:hayWin = $true
} catch { $script:hayWin = $false }

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetUnhandledExceptionMode('CatchException')
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# ---------- Rutas y ajustes ----------
$dirApp        = Join-Path $env:APPDATA 'MusicDL'
$dirAppViejo   = Join-Path $env:APPDATA 'DescargarMusica'
if ((Test-Path -LiteralPath $dirAppViejo) -and -not (Test-Path -LiteralPath $dirApp)) {
    try { Move-Item -LiteralPath $dirAppViejo -Destination $dirApp -Force } catch { Catch-Log 'bloque' $_ }
}

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


function Raices-Destino-Permitidas {
    $raices = New-Object System.Collections.Generic.List[string]
    foreach ($p in @(
            [Environment]::GetFolderPath('UserProfile'),
            [Environment]::GetFolderPath('MyMusic'),
            [Environment]::GetFolderPath('MyDocuments'),
            [Environment]::GetFolderPath('Desktop'),
            (Join-Path $env:USERPROFILE 'Downloads')
        )) {
        if (-not $p) { continue }
        try {
            $full = [IO.Path]::GetFullPath(($p.TrimEnd('\') + '\'))
            if (-not $raices.Contains($full)) { [void]$raices.Add($full) }
        } catch { Catch-Log 'Raices-Destino-Permitidas' $_ }
    }
    return @($raices)
}

function Carpeta-Destino-Por-Defecto {
    return (Join-Path ([Environment]::GetFolderPath('MyMusic')) 'Música descargada')
}

function Es-Carpeta-Destino-Segura($ruta) {
    if (-not $ruta) { return $false }
    try {
        $full = [IO.Path]::GetFullPath(($ruta.TrimEnd('\') + '\'))
        foreach ($r in (Raices-Destino-Permitidas)) {
            if ($full.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
    } catch { Catch-Log 'Es-Carpeta-Destino-Segura' $_ }
    return $false
}

function Normalizar-Carpeta-Destino($ruta) {
    if (Es-Carpeta-Destino-Segura $ruta) {
        try { return [IO.Path]::GetFullPath($ruta.TrimEnd('\')) } catch { return (Carpeta-Destino-Por-Defecto) }
    }
    return (Carpeta-Destino-Por-Defecto)
}

$config = [ordered]@{
    formato            = 0
    organizar          = 1
    carpeta            = (Carpeta-Destino-Por-Defecto)
    portada            = $false
    limpiar            = $false
    saltar             = $false
    accesoCreado       = $false
    listas             = @()
    noPreguntarBorradas = $false
    noPreguntarDrmYt   = $false
    saltarDrmYtAuto    = $true
    bajarAlCopiar      = $false
    ventanaMini        = $false
    avisoLegalAceptado = $false
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
        # v3.10: las casillas no se premarcan; el usuario elige
        if (-not ($leido.PSObject.Properties.Name -contains 'checksManuales')) {
            $config.portada = $false
            $config.limpiar = $false
            $config.saltar = $false
        }
        $config.carpeta = Normalizar-Carpeta-Destino $config.carpeta
    } catch {
        Registrar-Error "No se pudo leer config: $($_.Exception.Message)"
        $config.carpeta = Carpeta-Destino-Por-Defecto
    }
}

function Registrar-Error($msg) {
    try {
        $linea = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
        Add-Content -LiteralPath $archErrores -Value $linea -Encoding UTF8
    } catch { Catch-Log 'Registrar-Error' $_ }
}

function Catch-Log([string]$contexto, $err) {
  try {
    if (-not $err) { return }
    $msg = [string]$err.Exception.Message
    if (-not $msg) { return }
    if ($msg -match '(?i)cancel|abort|disposed|se ha eliminado el identificador|thread was being aborted') { return }
    Registrar-Error "$contexto : $msg"
  } catch { Catch-Log 'Catch-Log' $_ }
}


function Guardar-Config-Disco {
    if ($script:desinstalado) { return }
    try {
        $config.formatoV3 = $true
        $config.checksManuales = $true
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
    try { Move-Item -LiteralPath $archHistViejo -Destination $archHistMp3 -Force } catch { Catch-Log 'Guardar-Config-Disco' $_ }
}

$script:listas = New-Object System.Collections.ArrayList
foreach ($x in @($config.listas)) {
    if ($x -and $x.url) {
        [void]$script:listas.Add([pscustomobject]@{ url = [string]$x.url; nombre = [string]$x.nombre; ultima = [string]$x.ultima; nuevas = [string]$x.nuevas })
    }
}

# Herramientas: URL fija + SHA256 (no "latest"). Al subir versiones nuevas, actualiza url+sha256 y firma el .bat.
$herramientas = @(
    @{
        cmd = 'yt-dlp'; id = 'yt-dlp.yt-dlp'; nombre = 'el descargador'
        url = 'https://github.com/yt-dlp/yt-dlp/releases/download/2026.08.19/yt-dlp.exe'
        sha256 = '66674953FE251B89F4D08C5F0E35E0728679BD67AB3D7D05C0562AF101DD3E7A'
        tipo = 'exe'; destino = 'yt-dlp.exe'
    },
    @{
        cmd = 'ffmpeg'; id = 'Gyan.FFmpeg'; nombre = 'el conversor de audio'
        url = 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2026-09-24-18-44/ffmpeg-N-126838-g9058b3622e-win64-gpl.zip'
        sha256 = 'CB5020C310EB2439322CB65CF32AF89FC714A78061B464BFDB7D1EEAA1B232C7'
        tipo = 'zip-ffmpeg'; destino = 'ffmpeg.exe'
    },
    @{
        cmd = 'deno'; id = 'DenoLand.Deno'; nombre = 'el complemento para YouTube'
        url = 'https://github.com/denoland/deno/releases/download/v2.9.7/deno-x86_64-pc-windows-msvc.zip'
        sha256 = 'A0C3101B4158D1DFB7D6A78A7BF0F3DE80C96BB423C152BEEC8BEB22786F2238'
        tipo = 'zip-deno'; destino = 'deno.exe'
    },
    @{
        cmd = 'spotdl'; id = ''; nombre = 'spotDL (Spotify)'
        url = 'https://github.com/spotDL/spotify-downloader/releases/download/v4.5.2/spotdl-4.5.2-win32.exe'
        sha256 = '4490AE3B38C4321173E17975A9990A130CF9A9AEA8132EE2978AFECEFBEEB477'
        tipo = 'exe'; destino = 'spotdl.exe'
    }
)
$script:herramientas = $herramientas

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

#region Utilidades
# ================================================================
#  Utilidades
# ================================================================
function Q($s) { '"' + ($s -replace '"', '\"') + '"' }

function Formato-Args-Informe($argsLista) {
    if ($null -eq $argsLista) { return '' }
    $parts = foreach ($a in @($argsLista)) {
        $s = [string]$a
        if ($s -match '[\s"]') { '"' + ($s -replace '"', '\"') + '"' } else { $s }
    }
    return ($parts -join ' ')
}


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

function Faltan { return @($script:herramientas | Where-Object { -not (Ruta-De $_.cmd) }) }

function Verificar-Sha256($ruta, $esperado) {
    if (-not $esperado) { return $false }
    if (-not $ruta -or -not (Test-Path -LiteralPath $ruta)) { return $false }
    try {
        $real = (Get-FileHash -LiteralPath $ruta -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
        $want = ([string]$esperado).Trim().ToUpperInvariant()
        return ($real -eq $want)
    } catch {
        Registrar-Error "SHA256 $($ruta): $($_.Exception.Message)"
        return $false
    }
}

function Instalar-Spotdl {
    $h = $script:herramientas | Where-Object { $_.cmd -eq 'spotdl' } | Select-Object -First 1
    if (-not $h) { return $false }
    if (Test-Path -LiteralPath (Join-Path $dirBin 'spotdl.exe')) { return $true }
    return (Instalar-Herramienta-Directa $h)
}

function Preparar-Spotdl {
    if ($script:tarea -and $script:modo -eq $null) { Abandonar-Tarea; $lblAct.Text = '' }
    Refrescar-Path
    $s = Ruta-De 'spotdl'
    if ($s -and (Ruta-De 'ffmpeg') -and (Ruta-De 'deno')) { return $s }
    if (-not (Instalar-Si-Falta)) { return $null }
    Refrescar-Path
    $s = Ruta-De 'spotdl'
    if (-not $s) {
        Aviso "No se pudo instalar spotDL.`n`nComprueba internet y vuelve a abrir el programa." 'Warning'
    } elseif (-not (Ruta-De 'ffmpeg') -or -not (Ruta-De 'deno')) {
        Aviso "Faltan FFmpeg o Deno (necesarios para Spotify). Cierra y vuelve a abrir el programa." 'Warning'
        return $null
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
    # (?i) = mayúsculas/minúsculas; admite /embed/, /user/.../playlist/, query ?si=
    if ($e -match '(?i)^https://open\.spotify\.com/') { return $true }
    if ($e -match '(?i)^https://(www\.)?spotify\.com/') { return $true }
    if ($e -match '(?i)^https://spotify\.link/') { return $true }
    return $false
}

function Tipo-Enlace($e) {
    if ($e -match '(?i)^https://(www\.)?(youtube\.com|youtu\.be|music\.youtube\.com)/') { return 'youtube' }
    if ($e -match '(?i)^https://(www\.|m\.)?soundcloud\.com/') { return 'soundcloud' }
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
    if ($e -match '(?i)^https://spotify\.link/([a-zA-Z0-9]+)') {
        return @{ tipo = 'corto'; id = $matches[1] }
    }
    if ($e -match '(?i)^https://open\.spotify\.com/(?:intl-[a-z]{2}/)?(?:embed/)?(track|album|playlist|artist)/([a-zA-Z0-9]+)') {
        return @{ tipo = $matches[1].ToLower(); id = $matches[2] }
    }
    if ($e -match '(?i)^https://open\.spotify\.com/(?:intl-[a-z]{2}/)?user/[^/]+/(playlist)/([a-zA-Z0-9]+)') {
        return @{ tipo = 'playlist'; id = $matches[2] }
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
#endregion Utilidades

#region Tareas
# ================================================================
#  Tareas en segundo plano
# ================================================================
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300
$script:tarea = $null
$script:colaDescargas = New-Object System.Collections.Queue
$script:versionYtdlp = $null

function Iniciar-Tarea($exe, $argumentos, $alLinea, $alTerminar, $limiteSeg = 0, $nombre = 'tarea') {
    if ($argumentos -is [string]) {
        Registrar-Error "Iniciar-Tarea: ArgumentList debe ser [string[]], no un string unido"
        & $alTerminar -999
        return
    }
    $listaArgs = [string[]]@($argumentos)
    $rS = Join-Path $dirApp "$nombre-salida.txt"
    $rE = Join-Path $dirApp "$nombre-errores.txt"
    Remove-Item -LiteralPath $rS, $rE -Force -ErrorAction SilentlyContinue
    try {
        $p = Start-Process -FilePath $exe -ArgumentList $listaArgs -NoNewWindow -PassThru `
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
#endregion Tareas

#region Herramientas
# ================================================================
#  Descarga directa de herramientas (sin depender de winget)
# ================================================================
function Descargar-Http($url, $destino, $alProgreso = $null) {
    # Streaming + espera con DoEvents para no congelar el popup (sobre todo al conectar).
    $cliente = New-Object System.Net.Http.HttpClient
    $cliente.Timeout = [TimeSpan]::FromMinutes(5)
    $cliente.DefaultRequestHeaders.UserAgent.ParseAdd('MusicDL/3.36')
    $cts = New-Object System.Threading.CancellationTokenSource
    $script:downloadCts = $cts
    try {
        if ($script:pop -and $script:pop.paso) {
            $script:pop.paso.Text = 'Conectando con GitHub...'
            if ($script:pop.pct) { $script:pop.pct.Text = '' }
            Poner-Popup-Barra $null
            try { [System.Windows.Forms.Application]::DoEvents() } catch {}
        }

        $task = $cliente.GetAsync($url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cts.Token)
        while (-not $task.IsCompleted) {
            if ($script:popupCancelado) { try { $cts.Cancel() } catch { Catch-Log 'Descargar-Http' $_ }; return $false }
            try { [void]$task.Wait(200) } catch { break }
            try { [System.Windows.Forms.Application]::DoEvents() } catch {}
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
                    try { [System.Windows.Forms.Application]::DoEvents() } catch {}
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
                    try { [System.Windows.Forms.Application]::DoEvents() } catch {}
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
            try { [System.Windows.Forms.Application]::DoEvents() } catch {}
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
                try { [System.Windows.Forms.Application]::DoEvents() } catch {}
            }
            Move-Item -LiteralPath $tmp -Destination $destino -Force
            return $true
        }
        if ($h.tipo -eq 'zip-ffmpeg') {
            if ($script:pop -and $script:pop.paso) {
                $script:pop.paso.Text = "Extrayendo $($script:dlNombrePieza) (puede tardar)..."
                if ($script:pop.pct) { $script:pop.pct.Text = '' }
                Poner-Popup-Barra $null
                try { [System.Windows.Forms.Application]::DoEvents() } catch {}
            }
            $ok = Extraer-Zip-Selectivo $tmp 'ffmpeg.exe' $destino
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            return $ok
        }
        if ($h.tipo -eq 'zip-deno') {
            if ($script:pop -and $script:pop.paso) {
                $script:pop.paso.Text = "Extrayendo $($script:dlNombrePieza)..."
                try { [System.Windows.Forms.Application]::DoEvents() } catch {}
            }
            $ok = Extraer-Zip-Selectivo $tmp 'deno.exe' $destino
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            return $ok
        }
    } catch {
        Registrar-Error "Instalar $($h.cmd): $($_.Exception.Message)"
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        return $false
    }
    return $false
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
                    [System.Windows.Forms.Application]::DoEvents()
                    $script:falloIntegridad = $false
                    $ok = Instalar-Herramienta-Directa $h
                    if ($script:popupCancelado) { break }
                    if (-not $ok) {
                        if ($script:falloIntegridad) {
                            Registrar-Error "Sin winget: integridad fallida para $($h.cmd)"
                        } else {
                            $wg = Ruta-De 'winget'
                            if (-not $wg) { $wg = (Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1).Source }
                            if ($wg -and $h.id) {
                                if ($script:pop -and $script:pop.paso) {
                                    $script:pop.paso.Text = "Paso $i de $totalPasos : intentando con el instalador de Windows..."
                                }
                                [System.Windows.Forms.Application]::DoEvents()
                                try {
                                    Start-Process -FilePath $wg -ArgumentList "install --id $($h.id) -e --silent --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
                                } catch { Registrar-Error "winget $($h.cmd): $($_.Exception.Message)" }
                            }
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
            "No se pudo instalar $($falta[0].nombre).`n`nComprueba internet (GitHub) y el antivirus.`nSi tu PC de empresa bloquea descargas, pide a informática que permita yt-dlp, FFmpeg, Deno y spotDL.`n`nDetalle en: %APPDATA%\MusicDL\errores.log",
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
    try { [System.Windows.Forms.Application]::DoEvents() } catch {}
    $ok = $false
    $h = $script:herramientas | Where-Object { $_.cmd -eq 'yt-dlp' } | Select-Object -First 1
    if ($h) {
        $local = Join-Path $dirBin $h.destino
        if ((Test-Path -LiteralPath $local) -and (Verificar-Sha256 $local $h.sha256)) {
            $ok = $true
            $lblAct.Text = 'yt-dlp verificado'
        } else {
            $lblAct.Text = 'Actualizando yt-dlp...'
            try { [System.Windows.Forms.Application]::DoEvents() } catch {}
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
    Add-Member -InputObject $estado -NotePropertyName Drop -NotePropertyValue $null
    Add-Member -InputObject $estado -NotePropertyName CerrarSinReabrir -NotePropertyValue $false
    Add-Member -InputObject $estado -NotePropertyName AlCambiar -NotePropertyValue $null

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

#region UI-Principal
# ================================================================
#  Ventana principal
# ================================================================
$form = New-Object System.Windows.Forms.Form
Escalar-Dpi $form
$form.Text = 'MusicDL'
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

Nueva-Etiqueta $form 'MusicDL' 28 18 480 34 $fTitulo $colTexto | Out-Null
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

$btnTabDesc = Nuevo-Boton $barPestanas 'DESCARGAR' 0 4 150 32
$btnTabList = Nuevo-Boton $barPestanas 'MIS LISTAS' 158 4 150 32
$btnTabAjustes = Nuevo-Boton $barPestanas 'AJUSTES' 316 4 150 32
$btnTabDesc.FlatAppearance.BorderSize = 0
$btnTabList.FlatAppearance.BorderSize = 0
$btnTabAjustes.FlatAppearance.BorderSize = 0

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

$tab3 = New-Object System.Windows.Forms.Panel
$tab3.Dock = 'Fill'
$tab3.BackColor = $colPanel
$tab3.ForeColor = $colTexto
$tab3.Visible = $false
$tabHost.Controls.Add($tab3)

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
    & $activo $btnTabAjustes ($script:pestanaActual -eq 3)
}

function Mostrar-Pestana($n) {
    $script:pestanaActual = $n
    $tab1.Visible = ($n -eq 1)
    $tab2.Visible = ($n -eq 2)
    $tab3.Visible = ($n -eq 3)
    if ($n -eq 1) { $tab1.BringToFront() }
    elseif ($n -eq 2) { $tab2.BringToFront() }
    else { $tab3.BringToFront() }
    Pintar-Pestanas
}

$btnTabDesc.Add_Click({ Mostrar-Pestana 1 })
$btnTabList.Add_Click({ Mostrar-Pestana 2 })
$btnTabAjustes.Add_Click({ Mostrar-Pestana 3 })
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
$tips.SetToolTip($cmbFormato.Boton, "Original: deja el audio tal como lo envía la web (mejor opción para DJs).`nConvertir a FLAC/WAV/MP3 320 NO mejora el sonido de YouTube ni SoundCloud.")

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
$tips.SetToolTip($btnElegir, 'YouTube/SoundCloud: elige canciones de la lista. Spotify: usa Descargar (no admite elección una a una).')
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

# --- Pestaña AJUSTES ---
function Indice-Drm-Yt {
    if (-not $config.noPreguntarDrmYt) { return 0 }
    if ($config.saltarDrmYtAuto) { return 1 }
    return 2
}
function Aplicar-Indice-Drm-Yt($idx) {
    switch ([int]$idx) {
        1 { $config.noPreguntarDrmYt = $true;  $config.saltarDrmYtAuto = $true }
        2 { $config.noPreguntarDrmYt = $true;  $config.saltarDrmYtAuto = $false }
        default { $config.noPreguntarDrmYt = $false }
    }
}
function Sync-Cmb-Drm-Yt {
    if (-not $script:cmbDrmYt) { return }
    $script:syncDrmUi = $true
    try {
        $idx = Indice-Drm-Yt
        $script:cmbDrmYt.SelectedIndex = $idx
        $script:cmbDrmYt.Boton.Text = "  $($script:cmbDrmYt.Opciones[$idx])"
    } finally { $script:syncDrmUi = $false }
}

Nueva-Etiqueta $tab3 'AJUSTES' 24 20 400 18 $fEtiqueta $colAcento | Out-Null
Nueva-Etiqueta $tab3 'PROTECCIÓN DRM' 24 64 400 18 $fEtiqueta $colAcento | Out-Null
Nueva-Etiqueta $tab3 "Si una canción tiene DRM (protección anticopia) y no se puede bajar de la fuente,`nMusicDL puede buscar la misma en YouTube." 24 90 690 44 $fPequena $colSuave | Out-Null
Nueva-Etiqueta $tab3 'COMPORTAMIENTO' 24 150 400 16 $fEtiqueta $colTenue | Out-Null
$opcionesDrm = @(
    'Preguntar siempre',
    'Buscar en YouTube sin preguntar',
    'No buscar en YouTube'
)
$script:cmbDrmYt = Nuevo-Combo $tab3 24 172 692 $opcionesDrm (Indice-Drm-Yt)
$script:cmbDrmYt.AlCambiar = {
    param($idx)
    if ($script:syncDrmUi) { return }
    Aplicar-Indice-Drm-Yt $idx
    try { Guardar-Config-Disco } catch { Registrar-Error "Config DRM UI: $($_.Exception.Message)" }
}
$tips.SetToolTip($script:cmbDrmYt.Boton, "También se puede fijar desde el popup de DRM marcando «No volver a preguntar»:`nSí = buscar siempre · No = no buscar nunca.")
Nueva-Etiqueta $tab3 'Puedes cambiarlo aquí en cualquier momento. El popup de DRM usa la misma preferencia.' 24 220 690 40 $fPequena $colTenue | Out-Null

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
$miDesinstalar = $menu.Items.Add('Desinstalar MusicDL...')
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miVersion     = $menu.Items.Add("Versión $versionApp")
$miVersion.Enabled = $false
#endregion UI-Principal

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

#region UI-Logica
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
    [System.Windows.Forms.MessageBox]::Show($owner, $texto, 'MusicDL', 'OK', $icono) | Out-Null
}
function Pregunta($texto) {
    $owner = if ($script:enMini) { $formMini } else { $form }
    return ([System.Windows.Forms.MessageBox]::Show($owner, $texto, 'MusicDL', 'YesNo', 'Question') -eq 'Yes')
}
function Resultado($texto) {
    [void]$lstResultados.Items.Add($texto)
    $lstResultados.TopIndex = [Math]::Max(0, $lstResultados.Items.Count - 1)
}
function Barra-Tarea($estado, $valor = 0) {
    $h = if ($script:enMini) { $formMini.Handle } else { $form.Handle }
    if ($script:hayWin) { try { [DMWin]::Progreso($h, $estado, [uint64]$valor, [uint64]1000) } catch { Catch-Log 'Barra-Tarea' $_ } }
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
    $segura = Normalizar-Carpeta-Destino $txtCarpeta.Text
    if (-not (Es-Carpeta-Destino-Segura $txtCarpeta.Text)) {
        $txtCarpeta.Text = $segura
    }
    $config.carpeta   = $segura
    $config.portada   = $chkPortada.Checked
    $config.limpiar   = $chkLimpiar.Checked
    $config.saltar    = $chkSaltar.Checked
    $config.noPreguntarBorradas = $chkNoPreguntar.Checked
    $config.bajarAlCopiar = $chkBajarCopiar.Checked
    $config.ventanaMini = $script:enMini
    $config.listas    = @($script:listas)
    if ($script:cmbDrmYt) { Aplicar-Indice-Drm-Yt $script:cmbDrmYt.SelectedIndex }
    Guardar-Config-Disco
}
function Actualizar-Ayuda { $lblAyuda.Visible = ($txtEnlace.Text -eq '') }

function Modo($m) {
    $script:modo = $m
    $ocupado = ($m -ne $null)
    foreach ($c in @($cmbFormato, $cmbOrganizar, $btnCambiar, $chkPortada, $chkLimpiar,
                     $chkSaltar, $lnkOlvidar, $btnElegir, $txtNuevaLista, $btnAnadir, $btnSyncTodas, $btnSyncUna, $btnQuitar, $chkNoPreguntar, $script:cmbDrmYt)) {
        if ($c) { $c.Enabled = -not $ocupado }
    }
    # Enlaces y pegar siguen activos para poder encolar
    $txtEnlace.Enabled = $true
    $btnPegar.Enabled = $true
    $btnBorrar.Enabled = (-not $ocupado)
    $btnDescargar.Enabled = $true
    $btnCancelar.Enabled = $ocupado
    if ($btnMiniCancel) { $btnMiniCancel.Enabled = $ocupado }
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
    } catch { Catch-Log 'Avisar-Final' $_ }
    $activo = [System.Windows.Forms.Form]::ActiveForm
    $frm = if ($script:enMini) { $formMini } else { $form }
    if ($script:hayWin -and $activo -ne $frm) {
        try { [DMWin]::Flash($frm.Handle) } catch { Catch-Log 'Avisar-Final' $_ }
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
    } catch { Catch-Log 'Obtener-Version-Ytdlp' $_ }
    if (-not $script:versionYtdlp) { $script:versionYtdlp = '?' }
    return $script:versionYtdlp
}
#endregion UI-Logica

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
        $script:http.DefaultRequestHeaders.UserAgent.ParseAdd('MusicDL/3.36')
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
    if (-not (Pregunta "Hay una versión nueva de MusicDL ($nueva), firmada por el autor. Tú tienes la $versionApp.`n`n¿Actualizar ahora?")) { return }
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
#endregion Actualizacion

#region Descarga
# ================================================================
#  Descarga
# ================================================================
function Traducir-Error($l) {
    $web = if ($l -match '\[youtube') { 'YouTube' } elseif ($l -match '\[soundcloud') { 'SoundCloud' } else { 'La web' }
    switch -Regex ($l) {
        'Unsupported URL|is not a valid URL|no suitable extractor' {
            return @{ origen = 'El enlace'; texto = 'No es de una canción ni de una lista de YouTube, SoundCloud o Spotify.' } }
        'getaddrinfo|Failed to resolve|timed out|Connection refused|No route to host|Network is unreachable|Connection reset|RemoteDisconnected' {
            return @{ origen = 'Tu conexión'; texto = 'No hay internet o va muy lenta. Comprueba la conexión y vuelve a intentarlo.' } }
        'DRM protected|DRM-protected' {
            return @{ origen = $web; texto = 'Está protegida contra copia (DRM). Al terminar se preguntará si buscarla en YouTube.' } }
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

function Poner-Barra($pctCancion = 0) {
    $d = $script:dl
    if (-not $d) { return }
    $total = [Math]::Max([int]$d.total, 1)
    $hechos = [int]$d.nuevas + [int]$d.saltadas + [int]$d.nErrores + [int]$d.drmMarcados
    if ($total -gt 1) {
        # Canción actual: la siguiente a las ya hechas, o el índice de playlist si existe
        $idx = [int]$d.actual
        if ($idx -lt 1) { $idx = $hechos + 1 }
        if ($idx -gt $total) { $idx = $total }
        $v = (($idx - 1) + ([double]$pctCancion / 100.0)) / $total
        # No retroceder respecto a canciones ya cerradas
        $minV = $hechos / $total
        if ($v -lt $minV) { $v = $minV }
    } else {
        $v = [double]$pctCancion / 100.0
    }
    if ($v -gt 1) { $v = 1 }
    if ($v -lt 0) { $v = 0 }
    $valor = [int]($v * 1000)
    Set-BarraValor $barra $valor
    Set-BarraValor $barraMini $valor
    Barra-Tarea 2 $valor
}

function Poner-Barra-Canciones {
    $d = $script:dl
    if (-not $d) { return }
    $total = [Math]::Max([int]$d.total, 1)
    $hechos = [int]$d.nuevas + [int]$d.saltadas + [int]$d.nErrores + [int]$d.drmMarcados
    $v = [Math]::Min($hechos / $total, 1.0)
    $valor = [int]($v * 1000)
    Set-BarraValor $barra $valor
    Set-BarraValor $barraMini $valor
    Barra-Tarea 2 $valor
}

function Marcar-Completado($ruta) {
    $d = $script:dl
    if (-not $d -or -not $ruta) { return }
    $ruta = $ruta.Trim().Trim('"')
    if ($d.yaEstaba) { $d.yaEstaba = $false; return }
    if (-not $d.completados) { $d.completados = New-Object System.Collections.Generic.List[string] }
    if ($d.completados -contains $ruta) { return }
    [void]$d.completados.Add($ruta)
    $d.enCurso = $null
    try { $script:ultimaCarpetaReal = Split-Path -Parent $ruta } catch { Catch-Log 'Marcar-Completado' $_ }
    if (-not $d.saltandoDrm) {
        try {
            $parent = Split-Path -Parent $ruta
            if ($parent) { $d.carpetaLista = $parent }
        } catch { Catch-Log 'Marcar-Completado' $_ }
    }
    $d.nuevas++
    if ($d.listaActual) { $d.nuevasPorLista[$d.listaActual] = 1 + [int]$d.nuevasPorLista[$d.listaActual] }
    $nombre = [IO.Path]::GetFileNameWithoutExtension($ruta)
    $extra = if ($d.calidad) { "  [$($d.calidad)]" } else { '' }
    $tag = if ($d.saltandoDrm) { '  [DRM→YouTube]' }
           elseif ($d.motor -eq 'spotify-yt' -or $d.motor -eq 'spotdl') { '  [Spotify→YT]' }
           else { '' }
    Resultado ([string][char]0x2713 + '  ' + $nombre + $extra + $tag)
    Estado "Guardado:`n$nombre"
    $d.actual = [Math]::Max([int]$d.actual, [int]$d.nuevas + [int]$d.saltadas + [int]$d.nErrores)
    Poner-Barra-Canciones
}

function Es-Titulo-Comodin-Drm($t) {
    return ([string]$t -match '(?i)^Canci[oó]n\s+\d+\s+de\s+\d+$')
}

function Titulo-Desde-Url-Track($url) {
    if (-not $url) { return '' }
    # soundcloud.com/artista/tema (no sets/albums/api)
    if ($url -match '(?i)soundcloud\.com/([^/?#]+)/([^/?#]+)') {
        $a = $matches[1]; $b = $matches[2]
        if ($a -in @('you', 'discover', 'stream', 'search') ) { return '' }
        if ($b -in @('sets', 'albums', 'likes', 'tracks', 'popular-tracks', 'comments')) { return '' }
        $a = ($a -replace '-', ' ').Trim()
        $b = ($b -replace '-', ' ').Trim()
        if ($a -and $b) { return "$a $b" }
    }
    if ($url -match '(?i)youtube\.com/watch\?.*?v=([\w-]{11})' -or $url -match '(?i)youtu\.be/([\w-]{11})') {
        return ''  # sin título en la URL; se usa el de metadata
    }
    return ''
}

function Titulo-Para-Busqueda-Drm($d) {
    if ($d.titulo -and -not (Es-Titulo-Comodin-Drm $d.titulo)) { return ([string]$d.titulo).Trim() }
    if ($d.tituloDesdeUrl) { return ([string]$d.tituloDesdeUrl).Trim() }
    return ''
}

function Procesar-Linea($l) {
    $d = $script:dl
    if (-not $l) { return }
    # Título temprano (antes del DRM / descarga) vía --print before_dl
    if ($l -match '^\[DMTITLE\](.*)$') {
        $t = $matches[1].Trim()
        if ($t -and $t -ne 'NA' -and $t -ne 'None') {
            $d.titulo = $t
            if ($t -match '^(.*?)\s+/\s+(.*)$') {
                # formato "titulo / uploader" opcional
                $tit = $matches[1].Trim(); $up = $matches[2].Trim()
                if ($tit) { $d.titulo = $tit }
                if ($up -and -not $d.tituloDesdeUrl) { $d.tituloDesdeUrl = "$up $tit".Trim() }
            }
        }
        return
    }
    # Plantilla propia [DM]pct|idx|tot|titulo
    if ($l -match '^\[DM\](.*?)\|(.*?)\|(.*?)\|(.*)$') {
        $gPct = $matches[1]; $gIdx = $matches[2]; $gTot = $matches[3]; $gTit = $matches[4]
        $pct = 0.0
        [void][double]::TryParse(($gPct -replace '[^\d\.]', ''), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$pct)
        if ($gIdx -match '^\d+$' -and $gTot -match '^\d+$' -and [int]$gTot -gt 0) {
            $d.actual = [int]$gIdx
            $d.total = [Math]::Max([int]$d.total, [int]$gTot)
        }
        if ($gTit -and $gTit -ne 'NA' -and $gTit -ne 'None' -and -not (Es-Titulo-Comodin-Drm $gTit)) { $d.titulo = $gTit }
        Poner-Barra $pct
        $cual = if ($d.total -gt 1) { "canción $($d.actual) de $($d.total)" } else { 'canción' }
        Estado ("Descargando {0} ({1:0}%):`n{2}" -f $cual, $pct, $d.titulo)
        return
    }
    # Fallback: línea normal de yt-dlp "[download]  45.2%"
    if ($l -match '^\[download\]\s+(\d{1,3}(?:\.\d+)?)%') {
        $pct = [double]$matches[1]
        Poner-Barra $pct
        if ($d.titulo) {
            $cual = if ($d.total -gt 1) { "canción $($d.actual) de $($d.total)" } else { 'canción' }
            Estado ("Descargando {0} ({1:0}%):`n{2}" -f $cual, $pct, $d.titulo)
        }
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
        $d.urlActual = $u
        $desdeUrl = Titulo-Desde-Url-Track $u
        if ($desdeUrl) { $d.tituloDesdeUrl = $desdeUrl }
        if ($d.porUrl.ContainsKey($u)) { $d.listaActual = $u }
        if ($d.total -gt 1) {
            $d.indiceUrl = 1 + [int]$d.indiceUrl
            $d.actual = [Math]::Min([int]$d.indiceUrl, [int]$d.total)
            Poner-Barra 0
        }
        return
    }
    if ($l -match '^\[download\] Downloading playlist: (.+)$') {
        $nombreLista = $matches[1].Trim()
        Resultado ([string][char]0x25B8 + '  Lista: ' + $nombreLista)
        if ($d.listaActual) { $d.porUrl[$d.listaActual].nombre = $nombreLista }
        if ($nombreLista) { $d.nombreLista = $nombreLista }
        return
    }
    if ($l -match 'Downloading (?:item|video) (\d+) of (\d+)') {
        $d.actual = [int]$matches[1]; $d.total = [Math]::Max([int]$d.total, [int]$matches[2])
        # Nuevo ítem: limpiar título; el comodín "Canción N de M" ya no se usa para buscar en YT
        $d.yaEstaba = $false; $d.titulo = ''; $d.tituloDesdeUrl = ''; $d.urlActual = $null; $d.calidad = $null
        $lblCalidad.Text = ''
        Poner-Barra 0
        return
    }
    if ($l -match '^\[download\] .+ has already been downloaded') {
        $d.yaEstaba = $true; $d.saltadas++
        Resultado ('–  Ya estaba en la carpeta: ' + $d.titulo)
        Poner-Barra-Canciones
        return
    }
    # En curso (aún no terminado)
    if ($l -match '^\[download\] Destination: (.+)$' -or $l -match '\[Merger\] Merging formats into "(.+)"') {
        $d.enCurso = $matches[1].Trim().Trim('"')
        try { $script:ultimaCarpetaReal = Split-Path -Parent $d.enCurso } catch { Catch-Log 'Procesar-Linea' $_ }
        return
    }
    # Terminado de verdad (convertido o ya en formato final)
    if ($l -match '^\[ExtractAudio\] Destination: (.+)$' -or $l -match '^\[ExtractAudio\] Not converting audio (.+?);') {
        Marcar-Completado $matches[1]
        return
    }
    if ($l -match '^\[download\] 100% of .+ in ') {
        if ($d.formato -eq 'original' -and $d.enCurso) { Marcar-Completado $d.enCurso }
        else { Poner-Barra 100 }
        return
    }
    if ($l -match '^Deleting original file') { $d.enCurso = $null; return }
    if ($l -match 'has already been recorded in the archive') {
        if ($l -match '^\[download\] (\S+): has already') { [void]$d.idsSaltados.Add($matches[1]) }
        $d.saltadas++
        Resultado ('–  Ya la tenías en este formato, se ha saltado')
        Poner-Barra-Canciones
        return
    }
    if ($l -match '^ERROR:') {
        if ($l -match 'HTTP Error 403|Unable to extract|nsig|Signature|Requested format|JavaScript|jsc') {
            $script:sugerirUpdateYtdlp = $true
        }
        # DRM: encolar búsqueda en YouTube (o marcar fallo si ya estamos en el salto)
        if ($l -match '(?i)DRM protected|DRM-protected') {
            if ($d.saltandoDrm) {
                $d.drmFallbackFallo = $true
                return
            }
            $quien = Titulo-Para-Busqueda-Drm $d
            $etiqueta = if ($quien) { $quien } elseif ($d.total -gt 1) { "Canción $($d.actual) de $($d.total)" } else { '' }
            if (-not $quien) {
                $d.nErrores++
                $lineaErr = if ($etiqueta) {
                    "$etiqueta — Tiene DRM y no pude saber el título real para buscarla en YouTube."
                } else {
                    'Canción con DRM — no pude leer el título para buscarla en YouTube.'
                }
                Resultado ([string][char]0x2717 + '  ' + $lineaErr)
                if (-not $d.errores.Contains($lineaErr)) { [void]$d.errores.Add($lineaErr) }
                Poner-Barra-Canciones
                return
            }
            if (-not $d.drmPendientes) { $d.drmPendientes = New-Object System.Collections.ArrayList }
            $ya = $false
            foreach ($p in @($d.drmPendientes)) {
                if ([string]$p.titulo -eq $quien) { $ya = $true; break }
            }
            if (-not $ya) {
                [void]$d.drmPendientes.Add(@{ titulo = $quien })
                $d.drmMarcados = 1 + [int]$d.drmMarcados
                Resultado ([string][char]0x2298 + '  DRM: ' + $quien + ' — al terminar te preguntaré si buscarla en YouTube')
                Estado ("DRM detectado. Al terminar te preguntaré:`n{0}" -f $quien)
            }
            Poner-Barra-Canciones
            return
        }
        if ($d.saltandoDrm) {
            # 403/red: no marcar como "otra vez DRM"; deja que el resultado lo decida nuevas/saltadas
            if ($l -match '(?i)DRM protected|DRM-protected') { $d.drmFallbackFallo = $true }
            elseif ($l -match '(?i)HTTP Error 403|Unable to extract|nsig|Sign in to confirm') {
                $d.drmFallbackFallo = $true
            }
            return
        }
        $err = Traducir-Error $l
        $txt = "$($err.origen): $($err.texto)"
        $d.nErrores++
        $quien = Titulo-Para-Busqueda-Drm $d
        if (-not $quien) { $quien = if ($d.total -gt 1) { "Canción $($d.actual) de $($d.total)" } else { 'Canción sin título' } }
        $lineaErr = "$quien — $txt"
        Resultado ([string][char]0x2717 + '  ' + $lineaErr)
        if (-not $d.errores.Contains($lineaErr)) { [void]$d.errores.Add($lineaErr) }
        if ($d.total -gt 1) {
            Estado ("Falló una canción; continúo con el resto...`n{0}" -f $quien)
        }
        Poner-Barra-Canciones
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
    if (-not $ytdlp -or -not (Ruta-De 'ffmpeg')) {
        if (-not (Instalar-Si-Falta)) { return $null }
        Refrescar-Path
        $ytdlp = Ruta-De 'yt-dlp'
    }
    if (-not $ytdlp) { Aviso 'Falta el descargador. Cierra el programa y vuelve a abrirlo para que se instale.' 'Warning' }
    return $ytdlp
}

function Construir-Args($enlaces, $sync, $indices, $carpetaForzada = $null, $plantillaForzada = $null) {
    $fmt = $formatos[$cmbFormato.SelectedIndex]
    $carpetaRaw = if ($carpetaForzada) { [string]$carpetaForzada.TrimEnd('\') } else { $txtCarpeta.Text.TrimEnd('\') }
    $carpeta = Normalizar-Carpeta-Destino $carpetaRaw
    if (-not (Es-Carpeta-Destino-Segura $carpetaRaw)) {
        if ($txtCarpeta -and -not $carpetaForzada) { $txtCarpeta.Text = $carpeta }
    }
    $a = New-Object System.Collections.Generic.List[string]
    $a.AddRange([string[]]@('--newline', '--progress', '--color', 'never', '--no-mtime', '--encoding', 'utf-8', '--windows-filenames'))
    $a.Add('--concurrent-fragments'); $a.Add('4')
    # Robustez: reintentos y no abortar toda la lista si una canción falla
    $a.Add('--retries'); $a.Add('10')
    $a.Add('--fragment-retries'); $a.Add('10')
    $a.Add('--extractor-retries'); $a.Add('3')
    $a.Add('--retry-sleep'); $a.Add('1')
    $a.Add('--ignore-errors')
    $a.Add('--no-abort-on-error')
    # Título disponible antes de fallar por DRM (SoundCloud/YouTube)
    $a.Add('--print'); $a.Add('before_dl:[DMTITLE]%(title)s / %(uploader,creator,artist|)s')

    $ff = Ruta-De 'ffmpeg'
    if ($ff) { $a.Add('--ffmpeg-location'); $a.Add((Split-Path -Parent $ff)) }
    $deno = Ruta-De 'deno'
    if ($deno) { $a.Add('--js-runtimes'); $a.Add("deno:$deno") }

    $hayYt = @($enlaces | Where-Object { $_ -match 'youtube\.com|youtu\.be|ytsearch' }).Count -gt 0
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

    $a.Add('-P'); $a.Add($carpeta)
    # Plantilla de progreso (funciona aunque la salida no sea una terminal)
    $a.Add('--progress-template'); $a.Add('download:[DM]%(progress._percent_str)s|%(info.playlist_index)s|%(info.playlist_count)s|%(info.title)s')
    $a.Add('--progress-template'); $a.Add('postprocess:[DM]100%|%(info.playlist_index)s|%(info.playlist_count)s|%(info.title)s')

    if (-not $plantillaForzada -and $cmbOrganizar.SelectedIndex -eq 2) {
        $a.Add('--parse-metadata'); $a.Add('title:(?P<artist>.+?) - (?P<title>.+)')
        $a.Add('--replace-in-metadata'); $a.Add('uploader'); $a.Add('(?i)\s*(- topic|vevo)$'); $a.Add('')
    }
    if ($chkLimpiar.Checked) {
        $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add($reLimpiar);     $a.Add('')
        $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add($reLimpiarCola); $a.Add('')
        $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add('\s{2,}');       $a.Add(' ')
    }
    # Truncar solo si supera el límite (antes ^(.{1,N}).+$ comía 1 carácter siempre)
    $a.Add('--replace-in-metadata'); $a.Add('title'); $a.Add('^(.{120}).+$'); $a.Add('\1')
    $a.Add('--replace-in-metadata'); $a.Add('playlist_title'); $a.Add('^(.{80}).+$'); $a.Add('\1')
    $a.Add('--replace-in-metadata'); $a.Add('artist'); $a.Add('^(.{60}).+$'); $a.Add('\1')
    $a.Add('--replace-in-metadata'); $a.Add('uploader'); $a.Add('^(.{60}).+$'); $a.Add('\1')

    if ($chkPortada.Checked) {
        if ($fmt -ne 'wav' -and $fmt -ne 'original') { $a.AddRange([string[]]@('--embed-thumbnail', '--convert-thumbnails', 'jpg')) }
        elseif ($fmt -eq 'original') { $a.Add('--embed-metadata') }
        else { $a.Add('--embed-metadata') }
        if ($fmt -ne 'original') { $a.Add('--embed-metadata') }
    }

    if ($plantillaForzada) {
        $plantilla = $plantillaForzada
    } else {
        switch ($cmbOrganizar.SelectedIndex) {
            0 { $plantilla = '%(title).120B.%(ext)s' }
            1 { $plantilla = '%(playlist_title).80B/%(playlist_index&{} - |)s%(title).100B.%(ext)s' }
            2 { $plantilla = '%(artist,uploader).60B/%(title).100B.%(ext)s' }
        }
    }
    $a.Add('-o'); $a.Add($plantilla)

    $archHist = Archivo-Historial $fmt
    if ($chkSaltar.Checked -or $sync) { $a.Add('--download-archive'); $a.Add($archHist) }
    if ($indices) { $a.Add('-I'); $a.Add($indices) }

    $finales = @($enlaces | ForEach-Object { Arreglar-Enlace $_ })
    foreach ($e in $finales) { $a.Add($e) }
    return @{ args = $a; finales = $finales; fmt = $fmt; carpeta = $carpeta }
}

function Nombre-Carpeta-Seguro($nombre) {
    if (-not $nombre) { return '' }
    $n = [string]$nombre
    foreach ($ch in [IO.Path]::GetInvalidFileNameChars()) { $n = $n.Replace([string]$ch, '') }
    $n = ($n -replace '\s+', ' ').Trim().TrimEnd('.')
    if ($n.Length -gt 80) { $n = $n.Substring(0, 80).Trim().TrimEnd('.') }
    return $n
}

function Carpeta-Padre-DrmYt($d) {
    # Carpeta de la lista (o raíz) dentro de la cual irá la subcarpeta YouTube.
    $raiz = if ($d -and $d.carpeta) { [string]$d.carpeta.TrimEnd('\') } else { $txtCarpeta.Text.TrimEnd('\') }

    if ($d -and $d.carpetaLista) {
        $c = [string]$d.carpetaLista.TrimEnd('\')
        if ($c -match '[\\/]YouTube$') { $c = Split-Path -Parent $c }
        if ($c -and $c.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase)) { return $c }
    }

    if ($script:ultimaCarpetaReal) {
        $c = [string]$script:ultimaCarpetaReal.TrimEnd('\')
        if ($c -match '[\\/]YouTube$') { $c = Split-Path -Parent $c }
        if ($c -and $c.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $c)) {
            return $c
        }
    }

    if ($d -and $d.nombreLista) {
        $safe = Nombre-Carpeta-Seguro $d.nombreLista
        if ($safe) { return (Join-Path $raiz $safe) }
    }

    if ($d -and $d.listaActual -and $d.porUrl -and $d.porUrl.ContainsKey($d.listaActual)) {
        $nom = Nombre-Carpeta-Seguro $d.porUrl[$d.listaActual].nombre
        if ($nom) { return (Join-Path $raiz $nom) }
    }

    return $raiz
}

function Lanzar-Descarga($enlaces, $sync = $false, $indices = '') {
    $ytdlp = Preparar-Ytdlp
    if (-not $ytdlp) { return }

    $carpeta = Normalizar-Carpeta-Destino $txtCarpeta.Text
    if (-not (Es-Carpeta-Destino-Segura $txtCarpeta.Text)) {
        $txtCarpeta.Text = $carpeta
        Aviso 'La carpeta no estaba permitida; se usará la carpeta por defecto (dentro de tu perfil).' 'Warning'
    }
    try { New-Item -ItemType Directory -Force -Path $carpeta -ErrorAction Stop | Out-Null } catch {
        Aviso 'No se puede usar esa carpeta. Pulsa "Cambiar..." y elige otra.' 'Warning'; return
    }
    Guardar-Config

    $built = Construir-Args $enlaces $sync $indices
    $porUrl = @{}
    if ($sync) { foreach ($x in $script:listas) { if ($built.finales -contains $x.url) { $porUrl[$x.url] = $x } } }

    $script:dl = @{
        nuevas = 0; saltadas = 0; nErrores = 0; errores = New-Object System.Collections.ArrayList
        actual = 1; total = [Math]::Max($built.finales.Count, 1); titulo = ''; cancelada = $false; yaEstaba = $false; enCurso = $null
        idsSaltados = New-Object System.Collections.ArrayList
        sync = $sync; porUrl = $porUrl; listaActual = $null; nuevasPorLista = @{}
        inicio = Get-Date; carpeta = $built.carpeta; formato = $built.fmt; calidad = $null
        carpetaEscaneo = $null; motor = 'yt-dlp'
        completados = New-Object System.Collections.Generic.List[string]
        indiceUrl = 0
        drmPendientes = New-Object System.Collections.ArrayList
        drmMarcados = 0; saltandoDrm = $false; drmFallbackFallo = $false
        nombreLista = $null; carpetaLista = $null
    }
    $script:ultimaPeticion = @{ enlaces = $enlaces; sync = $sync; indices = $indices; motor = 'yt-dlp' }
    $script:ultimosArgsLista = [string[]]@($built.args)
    $script:ultimosArgs = Formato-Args-Informe $script:ultimosArgsLista

    Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
    $lstResultados.Items.Clear()
    $lblCalidad.Text = ''
    if (-not $script:enMini) { Mostrar-Pestana 1 }
    Modo 'descarga'
    Barra-Tarea 1
    Estado 'Empezando la descarga...'
    Iniciar-Tarea $ytdlp $script:ultimosArgsLista { param($l) Procesar-Linea $l } { param($c) Terminar-Descarga $c } 0 'descarga'
}

function Resolver-Spotify-Urls($enlaces) {
    # spotDL solo empareja Spotify→YouTube; la descarga real la hace yt-dlp (más actualizado).
    $spotdl = Ruta-De 'spotdl'
    $ff = Ruta-De 'ffmpeg'
    if (-not $spotdl) { return @() }
    $argsList = New-Object System.Collections.Generic.List[string]
    [void]$argsList.Add('url')
    foreach ($e in $enlaces) { [void]$argsList.Add([string]$e) }
    if ($ff) { [void]$argsList.Add('--ffmpeg'); [void]$argsList.Add([string]$ff) }

    $rS = Join-Path $dirApp 'spotdl-url-salida.txt'
    $rE = Join-Path $dirApp 'spotdl-url-errores.txt'
    Remove-Item -LiteralPath $rS, $rE -Force -ErrorAction SilentlyContinue
    $script:popupProc = $null
    try {
        $proc = Start-Process -FilePath $spotdl -ArgumentList $argsList.ToArray() -NoNewWindow -PassThru `
            -RedirectStandardOutput $rS -RedirectStandardError $rE
        $script:popupProc = $proc
        while ($proc -and -not $proc.HasExited) {
            if ($script:popupCancelado) {
                try { Start-Process taskkill -ArgumentList "/PID $($proc.Id) /T /F" -WindowStyle Hidden -Wait } catch { Catch-Log 'Resolver-Spotify-Urls' $_ }
                break
            }
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 40
        }
    } catch {
        Registrar-Error "spotdl url: $($_.Exception.Message)"
        $script:popupProc = $null
        return @()
    }
    $script:popupProc = $null
    if ($script:popupCancelado) { return @() }

    $urls = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $rS) {
        foreach ($l in (Get-Content -LiteralPath $rS -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            $t = ([string]$l).Trim()
            if ($t -match '^https://(www\.)?(music\.)?youtube\.com/' -or $t -match '^https://youtu\.be/') {
                [void]$urls.Add($t)
            }
        }
    }
    return @($urls)
}

function Lanzar-Descarga-Spotify($enlaces, $sync = $false) {
    $spotdl = Preparar-Spotdl
    if (-not $spotdl) { return }
    $ytdlp = Preparar-Ytdlp
    if (-not $ytdlp) { return }
    Refrescar-Path
    if (-not (Ruta-De 'ffmpeg')) {
        Aviso 'Falta FFmpeg. Cierra y vuelve a abrir el programa para instalarlo.' 'Warning'
        return
    }
    if (-not (Ruta-De 'deno')) {
        Aviso 'Falta Deno (necesario para YouTube). Cierra y vuelve a abrir el programa para instalarlo.' 'Warning'
        return
    }

    $carpeta = Normalizar-Carpeta-Destino $txtCarpeta.Text
    if (-not (Es-Carpeta-Destino-Segura $txtCarpeta.Text)) {
        $txtCarpeta.Text = $carpeta
        Aviso 'La carpeta no estaba permitida; se usará la carpeta por defecto (dentro de tu perfil).' 'Warning'
    }
    try { New-Item -ItemType Directory -Force -Path $carpeta -ErrorAction Stop | Out-Null } catch {
        Aviso 'No se puede usar esa carpeta. Pulsa "Cambiar..." y elige otra.' 'Warning'; return
    }
    Guardar-Config

    $script:ytResueltosSp = @()
    $script:enlacesSpResolve = @($enlaces)
    $script:popupCancelado = $false
    $script:pop = Nuevo-Popup 'Spotify' "Buscando las canciones en YouTube...`nspotDL empareja; yt-dlp descarga (evita errores 403)." $true
    $script:pop.form.ShowInTaskbar = $true
    $script:pop.form.Add_Shown({
        $script:pop.paso.Text = 'Emparejando con YouTube...'
        [System.Windows.Forms.Application]::DoEvents()
        $script:ytResueltosSp = @(Resolver-Spotify-Urls $script:enlacesSpResolve)
        if ($script:ytResueltosSp.Count -eq 0 -and -not $script:popupCancelado) {
            $script:pop.paso.Text = 'Sin resultados. Reintentando emparejado...'
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Seconds 2
            if (-not $script:popupCancelado) {
                $script:ytResueltosSp = @(Resolver-Spotify-Urls $script:enlacesSpResolve)
            }
        }
        if (-not $script:popupCancelado) {
            Start-Sleep -Milliseconds 150
            Cerrar-Popup
        }
    })
    [void]$script:pop.form.ShowDialog()
    $script:pop = $null
    $form.Enabled = $true

    if ($script:popupCancelado) {
        Estado 'Búsqueda de Spotify cancelada.'
        Modo $null
        Barra-Tarea 0
        return
    }

    $ytUrls = @($script:ytResueltosSp)
    if ($ytUrls.Count -eq 0) {
        Aviso "No se encontró ninguna canción en YouTube para ese enlace de Spotify.`n`nPrueba otro enlace o más tarde." 'Warning'
        Estado 'Listo.'
        return
    }

    $porUrl = @{}
    if ($sync) { foreach ($x in $script:listas) { if ($enlaces -contains $x.url) { $porUrl[$x.url] = $x } } }

    $built = Construir-Args $ytUrls $sync ''
    $script:dl = @{
        nuevas = 0; saltadas = 0; nErrores = 0; errores = New-Object System.Collections.ArrayList
        actual = 1; total = [Math]::Max($ytUrls.Count, 1); titulo = ''; cancelada = $false; yaEstaba = $false; enCurso = $null
        idsSaltados = New-Object System.Collections.ArrayList
        sync = $sync; porUrl = $porUrl; listaActual = $null; nuevasPorLista = @{}
        inicio = Get-Date; carpeta = $built.carpeta; formato = $built.fmt; calidad = 'Spotify→YouTube'
        carpetaEscaneo = $null; motor = 'spotify-yt'
        completados = New-Object System.Collections.Generic.List[string]
        indiceUrl = 0
        drmPendientes = New-Object System.Collections.ArrayList
        drmMarcados = 0; saltandoDrm = $false; drmFallbackFallo = $false
        nombreLista = $null; carpetaLista = $null
    }
    $script:ultimaPeticion = @{ enlaces = $enlaces; sync = $sync; indices = ''; motor = 'spotdl' }
    $script:ultimosArgsLista = [string[]]@($built.args)
    $script:ultimosArgs = Formato-Args-Informe $script:ultimosArgsLista

    Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
    $lstResultados.Items.Clear()
    $lblCalidad.Text = "Spotify → YouTube: $($ytUrls.Count) canción(es) emparejadas. Descargando con yt-dlp."
    if (-not $script:enMini) { Mostrar-Pestana 1 }
    Modo 'descarga'
    Barra-Tarea 1
    Estado "Spotify: $($ytUrls.Count) encontradas. Descargando..."
    Iniciar-Tarea $ytdlp $script:ultimosArgsLista { param($l) Procesar-Linea $l } { param($c) Terminar-Descarga $c } 0 'descarga'
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

function Preguntar-Salto-Drm($pendientes) {
    # Devuelve $true si el usuario quiere buscar en YouTube.
    # Respeta "No volver a preguntar" guardado en config.
    if ($config.noPreguntarDrmYt) { return [bool]$config.saltarDrmYtAuto }

    $titulos = @($pendientes | ForEach-Object { [string]$_.titulo } | Where-Object { $_ })
    $n = $titulos.Count
    if ($n -eq 0) { return $false }

    $f = New-Object System.Windows.Forms.Form
    Escalar-Dpi $f
    $f.Text = 'MusicDL'
    $f.ClientSize = New-Object System.Drawing.Size(520, 320)
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.StartPosition = 'CenterParent'
    $f.BackColor = $colPanel
    $f.ForeColor = $colTexto
    $f.Font = $fNormal
    $f.ShowInTaskbar = $false
    if ($script:icono) { $f.Icon = $script:icono }

    $barraTop = New-Object System.Windows.Forms.Panel
    $barraTop.BackColor = $colAcento
    $barraTop.Location = New-Object System.Drawing.Point(0, 0)
    $barraTop.Size = New-Object System.Drawing.Size(520, 4)
    $f.Controls.Add($barraTop)

    Nueva-Etiqueta $f 'PROTECCIÓN DRM' 24 24 470 22 $fEtiqueta $colAcento | Out-Null

    $intro = if ($n -eq 1) {
        "Esta canción tiene DRM (protección anticopia) y no se pudo bajar de la fuente original:"
    } else {
        "$n canciones tienen DRM y no se pudieron bajar de la fuente original:"
    }
    Nueva-Etiqueta $f $intro 24 52 470 40 $fNormal $colSuave | Out-Null

    $lst = New-Object System.Windows.Forms.ListBox
    $lst.Location = New-Object System.Drawing.Point(24, 96)
    $lst.Size = New-Object System.Drawing.Size(472, 88)
    $lst.BackColor = $colCampo
    $lst.ForeColor = $colTexto
    $lst.BorderStyle = 'FixedSingle'
    $lst.IntegralHeight = $false
    foreach ($t in ($titulos | Select-Object -First 20)) { [void]$lst.Items.Add($t) }
    if ($n -gt 20) { [void]$lst.Items.Add("… y $($n - 20) más") }
    $f.Controls.Add($lst)

    Nueva-Etiqueta $f '¿Quieres que intentemos descargar esto en YouTube?' 24 196 470 24 $fNormal $colTexto | Out-Null

    $chk = Nueva-Casilla $f 'No volver a preguntar' 24 228 $false 300

    $btnSi = Nuevo-BotonPrincipal $f 'Sí' 250 262 110 36 $fNormal
    $btnNo = Nuevo-Boton $f 'No' 370 262 110 36
    $btnSi.DialogResult = 'Yes'
    $btnNo.DialogResult = 'No'
    $f.AcceptButton = $btnSi
    $f.CancelButton = $btnNo

    $owner = if ($script:enMini) { $formMini } else { $form }
    $dr = $f.ShowDialog($owner)
    $ok = ($dr -eq 'Yes')

    if ($chk.Checked) {
        $config.noPreguntarDrmYt = $true
        $config.saltarDrmYtAuto = [bool]$ok
        try { Guardar-Config-Disco } catch { Registrar-Error "Config DRM: $($_.Exception.Message)" }
        Sync-Cmb-Drm-Yt
    }
    return [bool]$ok
}

function Marcar-Drm-Sin-Salto($d) {
    if (-not $d.drmPendientes) { return }
    foreach ($p in @($d.drmPendientes)) {
        $tit = [string]$p.titulo
        if (-not $tit) { $tit = 'Canción' }
        $d.nErrores++
        $msg = "$tit — Tiene DRM y no se buscó alternativa en YouTube."
        Resultado ([string][char]0x2717 + '  ' + $msg)
        if (-not $d.errores.Contains($msg)) { [void]$d.errores.Add($msg) }
    }
    $d.drmPendientes.Clear()
    $d.drmMarcados = 0
}

function Intentar-Saltos-Drm($d) {
    # Tras la descarga principal: canciones con DRM → buscar la misma en YouTube.
    if (-not $d -or -not $d.drmPendientes -or $d.drmPendientes.Count -eq 0) { return }
    $pend = @($d.drmPendientes)
    $d.drmPendientes.Clear()
    $d.drmMarcados = 0
    $ytdlp = Ruta-De 'yt-dlp'
    $n = $pend.Count
    $i = 0
    foreach ($p in $pend) {
        if ($d.cancelada) { return }
        $i++
        $titulo = [string]$p.titulo
        if (-not $titulo -or (Es-Titulo-Comodin-Drm $titulo)) {
            $d.nErrores++
            $msg = 'Canción con DRM — no pude leer el título real para buscarla en YouTube.'
            Resultado ([string][char]0x2717 + '  ' + $msg)
            if (-not $d.errores.Contains($msg)) { [void]$d.errores.Add($msg) }
            continue
        }
        if (-not $ytdlp) {
            $d.nErrores++
            $msg = "$titulo — Tiene DRM; intenté buscar en YouTube pero falta el descargador."
            Resultado ([string][char]0x2717 + '  ' + $msg)
            if (-not $d.errores.Contains($msg)) { [void]$d.errores.Add($msg) }
            continue
        }

        Estado ("DRM: buscando alternativa en YouTube ($i/$n):`n$titulo")
        Resultado ([string][char]0x2192 + '  DRM — buscando en YouTube: ' + $titulo)
        try { [System.Windows.Forms.Application]::DoEvents() } catch {}

        $query = ($titulo -replace '[\r\n\t]+', ' ').Trim()
        # Quitar restos típicos de path/slug inútil
        $query = ($query -replace '\s{2,}', ' ').Trim()
        if ($query.Length -gt 100) { $query = $query.Substring(0, 100).Trim() }
        $search = "ytsearch1:$query"

        $antes = [int]$d.nuevas
        $antesSalt = [int]$d.saltadas
        $d.drmFallbackFallo = $false
        $d.saltandoDrm = $true
        $d.titulo = $titulo
        $d.yaEstaba = $false
        $d.enCurso = $null
        $d.calidad = $null

        $built = Construir-Args @($search) $false '' (Carpeta-Padre-DrmYt $d) 'YouTube/%(title).100B.%(ext)s'
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $built.carpeta 'YouTube') -ErrorAction SilentlyContinue | Out-Null
        } catch { Catch-Log 'Intentar-Saltos-Drm' $_ }
        $rS = Join-Path $dirApp 'drm-salida.txt'
        $rE = Join-Path $dirApp 'drm-errores.txt'
        Remove-Item -LiteralPath $rS, $rE -Force -ErrorAction SilentlyContinue
        try {
            $argsDrm = [string[]]@($built.args)
            $proc = Start-Process -FilePath $ytdlp -ArgumentList $argsDrm -NoNewWindow -PassThru `
                -RedirectStandardOutput $rS -RedirectStandardError $rE
            while ($proc -and -not $proc.HasExited) {
                if ($d.cancelada) {
                    try { Start-Process taskkill -ArgumentList "/PID $($proc.Id) /T /F" -WindowStyle Hidden -Wait } catch { Catch-Log 'Intentar-Saltos-Drm' $_ }
                    break
                }
                try { [System.Windows.Forms.Application]::DoEvents() } catch {}
                Start-Sleep -Milliseconds 40
            }
        } catch {
            Registrar-Error "DRM→YouTube: $($_.Exception.Message)"
            $d.drmFallbackFallo = $true
        }

        if ($d.cancelada) {
            $d.saltandoDrm = $false
            return
        }

        $huboDrmOtraVez = $false
        foreach ($rutaLog in @($rS, $rE)) {
            if (-not (Test-Path -LiteralPath $rutaLog)) { continue }
            foreach ($l in @(Get-Content -LiteralPath $rutaLog -Encoding UTF8 -ErrorAction SilentlyContinue)) {
                if ($l -match '(?i)DRM protected|DRM-protected') { $huboDrmOtraVez = $true }
                Procesar-Linea $l
            }
        }
        # Formato original: a veces no hay ExtractAudio; cerrar si hay destino y no hubo DRM/403 fatal
        if ([int]$d.nuevas -eq $antes -and $d.enCurso -and -not $huboDrmOtraVez -and -not $d.drmFallbackFallo) {
            if (Test-Path -LiteralPath $d.enCurso) { Marcar-Completado $d.enCurso }
        }
        $d.saltandoDrm = $false

        $ok = ([int]$d.nuevas -gt $antes) -or ([int]$d.saltadas -gt $antesSalt)
        if ($ok) {
            Estado ("DRM saltado vía YouTube:`n$titulo")
        } else {
            $d.nErrores++
            $motivo = if ($huboDrmOtraVez) {
                'Intenté saltar el DRM buscando en YouTube, pero el resultado también estaba protegido.'
            } elseif ($d.drmFallbackFallo) {
                'Intenté saltar el DRM buscando en YouTube, pero YouTube bloqueó o no dejó descargar (403/login).'
            } else {
                'Intenté saltar el DRM buscando en YouTube, pero no encontré la misma canción.'
            }
            $lineaErr = "$titulo — $motivo"
            Resultado ([string][char]0x2717 + '  ' + $lineaErr)
            if (-not $d.errores.Contains($lineaErr)) { [void]$d.errores.Add($lineaErr) }
            Estado ("No se pudo saltar el DRM:`n$titulo")
        }
        Poner-Barra-Canciones
        try { [System.Windows.Forms.Application]::DoEvents() } catch {}
    }
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
        $prefijo = if ($motor -eq 'spotdl' -or $motor -eq 'spotify-yt') { 'spotify→yt-dlp ' } else { 'yt-dlp ' }
        $txt.Add($prefijo + $script:ultimosArgs)
        $txt.Add('')
        $txt.Add('===== Canciones con fallo =====')
        if ($script:dl -and $script:dl.errores -and $script:dl.errores.Count -gt 0) {
            foreach ($e in @($script:dl.errores)) { $txt.Add([string]$e) }
        } else {
            $txt.Add('(ninguna)')
        }
        $txt.Add('')
        $txt.Add('===== Lo que ha ido haciendo =====')
        if (Test-Path -LiteralPath $rS) { foreach ($x in (Get-Content -LiteralPath $rS -Encoding UTF8)) { $txt.Add($x) } }
        $txt.Add('')
        $txt.Add('===== Errores y avisos (yt-dlp) =====')
        if (Test-Path -LiteralPath $rE) { foreach ($x in (Get-Content -LiteralPath $rE -Encoding UTF8)) { $txt.Add($x) } }
        Set-Content -LiteralPath $archInforme -Value $txt -Encoding UTF8
    } catch { Registrar-Error "Informe: $($_.Exception.Message)" }
}

function Limpiar-Restos($d) {
    # Solo temporales / fragmentos / enCurso. NO borra audios recientes (.m4a, .mp3, etc.).
    Start-Sleep -Milliseconds 900
    if (-not $d) { return }
    $desde = $d.inicio.AddSeconds(-5)
    $bases = New-Object System.Collections.Generic.List[string]
    if ($d.carpeta) { [void]$bases.Add($d.carpeta) }
    if ($script:ultimaCarpetaReal) { [void]$bases.Add($script:ultimaCarpetaReal) }
    $ok = @{}
    if ($d.completados) { foreach ($c in @($d.completados)) { if ($c) { $ok[[string]$c] = $true } } }
    $tempExt = @('.part', '.ytdl', '.temp', '.webp', '.jpg', '.jpeg', '.png')

    foreach ($base in @($bases | Select-Object -Unique)) {
        if (-not $base -or -not (Test-Path -LiteralPath $base)) { continue }
        try {
            Get-ChildItem -LiteralPath $base -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $desde } |
                Where-Object {
                    $full = $_.FullName
                    if ($ok.ContainsKey($full)) { return $false }
                    $n = $_.Name.ToLower(); $e = $_.Extension.ToLower()
                    if ($d.enCurso -and ($full -eq [string]$d.enCurso)) { return $true }
                    if ($n -match '\.part($|-frag|\.)' -or $e -in $tempExt -or $n -match '\.temp\.') { return $true }
                    if ($n -match '\.f\d{2,4}(\.|$)') { return $true }
                    return $false
                } | Remove-Item -Force -ErrorAction SilentlyContinue

            Get-ChildItem -LiteralPath $base -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending |
                Where-Object { $_.CreationTime -ge $desde -or $_.LastWriteTime -ge $desde } |
                Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        } catch { Registrar-Error "Limpiar restos: $($_.Exception.Message)" }
    }
}

function Terminar-Descarga($codigo) {
    $d = $script:dl
    $btnAbrirUltima.Enabled = [bool]($script:ultimaCarpetaReal -and (Test-Path -LiteralPath $script:ultimaCarpetaReal))

    if ($d.cancelada) {
        Estado 'Cancelando: limpiando temporales...'
        Limpiar-Restos $d
        Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
        Barra-Tarea 0
        Modo $null
        Estado 'Descarga cancelada. Se han borrado temporales; los audios ya guardados se conservan.'
        $script:colaDescargas.Clear()
        Pintar-Cola
        return
    }
    if ($codigo -eq -999) {
        Guardar-Informe $codigo
        Barra-Tarea 0
        Modo $null
        Estado 'El programa: no se pudo iniciar la descarga.'
        return
    }

    # Canciones con DRM: preguntar si buscar en YouTube (salvo "no volver a preguntar")
    if ($d.drmPendientes -and $d.drmPendientes.Count -gt 0) {
        $hacer = Preguntar-Salto-Drm $d.drmPendientes
        if ($hacer) {
            Intentar-Saltos-Drm $d
            if ($d.cancelada) {
                Estado 'Cancelando: limpiando temporales...'
                Limpiar-Restos $d
                Set-BarraValor $barra 0; Set-BarraValor $barraMini 0
                Barra-Tarea 0
                Modo $null
                Estado 'Descarga cancelada. Se han borrado temporales; los audios ya guardados se conservan.'
                $script:colaDescargas.Clear()
                Pintar-Cola
                return
            }
        } else {
            Marcar-Drm-Sin-Salto $d
        }
    }

    Guardar-Informe $codigo

    if ($d.sync) {
        foreach ($u in $d.porUrl.Keys) {
            $x = $d.porUrl[$u]
            $x.ultima = Hoy
            if ($d.motor -eq 'spotdl' -or $d.motor -eq 'spotify-yt') {
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
        if ($codigo -ne 0) { Estado 'Algo ha fallado. Comprueba el enlace o reinicia para actualizar yt-dlp.' }
        else { Estado 'Terminado.' }
    } elseif ($d.nuevas -eq 0 -and $d.nErrores -eq 0) {
        Estado 'No hay canciones nuevas: ya tenías todas en este formato.'
    } else {
        $msgFin = 'Terminado: ' + ($partes -join ', ') + '.'
        if ($d.nErrores -gt 0 -and ($d.nuevas -gt 0 -or $d.saltadas -gt 0)) {
            $msgFin += ' Las que fallaron se saltaron; el resto está guardado.'
        }
        Estado $msgFin
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
        $maxErr = @($d.errores | Select-Object -First 8)
        $extraErr = if ($d.errores.Count -gt 8) {
            "`n`n… y $($d.errores.Count - 8) más (Menú → Ver detalles técnicos)."
        } else { '' }
        Aviso ("Algunas canciones fallaron; el resto se ha seguido descargando:`n`n- " + ($maxErr -join "`n- ") + $extraErr) 'Warning'
    }
    if ($script:sugerirUpdateYtdlp -and -not $script:yaOfrecioUpdateSesion) {
        $script:yaOfrecioUpdateSesion = $true
        $script:sugerirUpdateYtdlp = $false
        if (Pregunta "YouTube ha bloqueado o cambiado algo.`n`n¿Actualizar yt-dlp ahora? (recomendado)") {
            Actualizar-Herramientas-Directas -Forzar
            $verAhora = Obtener-Version-Ytdlp
            Aviso "yt-dlp actualizado a $verAhora.`n`nVuelve a intentar la descarga."
        }
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
    } catch { Catch-Log 'Canciones-Borradas' $_ }
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
        'MusicDL', 'YesNoCancel', 'Question')
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
#endregion Descarga

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

#region Ayuda
# ================================================================
#  Ayuda / Desinstalar / Accesos
# ================================================================
function Mostrar-Aviso-Legal-PrimerUso {
    if ($config.avisoLegalAceptado) { return $true }
    $f = New-Object System.Windows.Forms.Form
    Escalar-Dpi $f
    $f.Text = 'MusicDL — Condiciones de uso'
    $f.ClientSize = New-Object System.Drawing.Size(560, 420)
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterScreen'
    $f.BackColor = $colPanel; $f.ForeColor = $colTexto; $f.Font = $fNormal
    $f.TopMost = $true
    if ($script:icono) { $f.Icon = $script:icono }
    $t = New-Object System.Windows.Forms.TextBox
    $t.Multiline = $true; $t.ReadOnly = $true; $t.ScrollBars = 'Vertical'
    $t.BorderStyle = 'None'; $t.BackColor = $colPanel; $t.ForeColor = $colTexto
    $t.TabStop = $false
    $t.Location = New-Object System.Drawing.Point(20, 18)
    $t.Size = New-Object System.Drawing.Size(520, 320)
    $t.Text = @"
AVISO LEGAL (uso personal)

MusicDL es una herramienta local. Al continuar confirmas que:

1. Respetarás los términos de YouTube, SoundCloud y Spotify y la legislación de tu país sobre derechos de autor.
2. Usarás el programa solo para uso personal; no redistribuirás, venderás ni compartirás contenido sin permiso.
3. Entiendes que Spotify no entrega audio Premium: se busca un equivalente en YouTube (calidad variable).
4. El autor no se hace responsable del uso indebido ni de bloqueos o cambios de las plataformas.
5. No quitarás el crédito «Made by WLY» / MusicDL al redistribuir el programa.

Si no estás de acuerdo, pulsa «No acepto» y el programa se cerrará.
"@ -replace "(?<!`r)`n", "`r`n"
    $f.Controls.Add($t)
    $bOk = Nuevo-BotonPrincipal $f 'ACEPTO' 280 360 140 36 $fBotonMed
    $bOk.DialogResult = 'Yes'
    $bNo = Nuevo-Boton $f 'No acepto' 140 360 120 36
    $bNo.DialogResult = 'No'
    $f.AcceptButton = $bOk
    $f.CancelButton = $bNo
    $r = $f.ShowDialog()
    $f.Dispose()
    if ($r -eq 'Yes') {
        $config.avisoLegalAceptado = $true
        try { Guardar-Config-Disco } catch { Catch-Log 'AvisoLegal' $_ }
        return $true
    }
    return $false
}

function Mostrar-Ayuda {
    $f = New-Object System.Windows.Forms.Form
    Escalar-Dpi $f
    $f.Text = 'Ayuda - MusicDL'
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

Spotify: spotDL busca el tema en YouTube; la descarga la hace yt-dlp (misma calidad/fiabilidad que YouTube). Se instalan al abrir el programa la primera vez.

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
Al arrancar, si hay MusicDL.bat.sig se verifica la firma RSA antes de ejecutar.
yt-dlp, FFmpeg, Deno y spotDL se descargan con URL fija y se comprueban con SHA256.
Solo se aceptan enlaces https de YouTube, SoundCloud y Spotify.
La carpeta de destino queda acotada a tu perfil (Música, Documentos, Escritorio, Descargas).

LEGAL
Uso personal: respeta ToS de las plataformas y la ley de tu país. No redistribuyas contenido sin permiso.
La primera vez el programa pide aceptar estas condiciones.

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
    if (-not (Pregunta "¿Desinstalar MusicDL?`n`nSe quitarán accesos directos, ajustes, listas e historial.`nTu música NO se borra.")) { return }
    $quitarPiezas = Pregunta "¿Quitar también yt-dlp, FFmpeg, Deno y spotDL de la carpeta del programa?"
    Abandonar-Tarea
    if ($quitarPiezas) {
        Mostrar-Popup-Encima 'Desinstalando' 'Quitando las piezas descargadas...'
        try { Remove-Item -LiteralPath $dirBin -Recurse -Force -ErrorAction SilentlyContinue } catch { Catch-Log 'Desinstalar' $_ }
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
    Remove-Item -LiteralPath (Join-Path $env:APPDATA 'DescargarMusica') -Recurse -Force -ErrorAction SilentlyContinue
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
    if ($script:hayWin) { try { [DMWin]::SetShortcutAppId($lnk, 'MusicDL.App') } catch { Catch-Log 'Escribir-Acceso' $_ } }
}

function Crear-Acceso {
    $bat = $env:DM_BAT
    if (-not $bat -or -not (Test-Path -LiteralPath $bat)) { return }
    try { Escribir-Acceso (Join-Path ([Environment]::GetFolderPath('Programs')) 'MusicDL.lnk') $bat } catch { Catch-Log 'Crear-Acceso' $_ }
    try {
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'MusicDL.lnk'
        if ($config.accesoCreado -and -not (Test-Path -LiteralPath $lnk)) { return }
        Escribir-Acceso $lnk $bat
        $config.accesoCreado = $true
        Guardar-Config
    } catch { Catch-Log 'Crear-Acceso' $_ }
}
#endregion Ayuda

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
    if (Test-Path -LiteralPath $txtCarpeta.Text) { $dlg.SelectedPath = $txtCarpeta.Text }
    if ($dlg.ShowDialog($form) -eq 'OK') {
        if (-not (Es-Carpeta-Destino-Segura $dlg.SelectedPath)) {
            Aviso 'Esa carpeta no está permitida. Elige una dentro de tu perfil, Música, Documentos, Escritorio o Descargas.' 'Warning'
            return
        }
        $txtCarpeta.Text = Normalizar-Carpeta-Destino $dlg.SelectedPath
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
    $c = $txtCarpeta.Text
    try { New-Item -ItemType Directory -Force -Path $c | Out-Null } catch { Catch-Log 'Cancelar-Operacion' $_ }
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
        if ($script:hayWin) {
            $pasoUi = 'tema'
            try { if ($form -and $form.Handle) { [DMWin]::TemaOscuro($form.Handle) } } catch { Catch-Log 'Cancelar-Operacion' $_ }
            try { if ($txtEnlace) { [DMWin]::TemaOscuro($txtEnlace.Handle) } } catch { Catch-Log 'Cancelar-Operacion' $_ }
            try { if ($txtCarpeta) { [DMWin]::TemaOscuro($txtCarpeta.Handle) } } catch { Catch-Log 'Cancelar-Operacion' $_ }
            try { if ($txtNuevaLista) { [DMWin]::TemaOscuro($txtNuevaLista.Handle) } } catch { Catch-Log 'Cancelar-Operacion' $_ }
            try { if ($lstResultados) { [DMWin]::TemaOscuro($lstResultados.Handle) } } catch { Catch-Log 'Cancelar-Operacion' $_ }
            try { if ($lvListas) { [DMWin]::TemaOscuro($lvListas.Handle) } } catch { Catch-Log 'Cancelar-Operacion' $_ }
            try { if ($txtNuevaLista) { [DMWin]::Pista($txtNuevaLista.Handle, 'Pega aquí el enlace de una lista') } } catch { Catch-Log 'Cancelar-Operacion' $_ }
        }
        $pasoUi = 'acceso'
        Crear-Acceso
        $pasoUi = 'ayuda'
        Actualizar-Ayuda
        $pasoUi = 'listas'
        Pintar-Listas
        $pasoUi = 'cola'
        Pintar-Cola
        try { Refrescar-Path } catch { Catch-Log 'Cancelar-Operacion' $_ }
        if ($lblAct) { $lblAct.Text = 'Todo listo' }

        if ($script:timerAct) { try { $script:timerAct.Stop(); $script:timerAct.Dispose() } catch {} }
        $script:timerAct = New-Object System.Windows.Forms.Timer
        $script:timerAct.Interval = 2000
        $script:timerAct.Add_Tick({
            try {
                if ($script:timerAct) { $script:timerAct.Stop() }
                if ($lblAct) { $lblAct.Text = 'Comprobando descargador...' }
                [System.Windows.Forms.Application]::DoEvents()
                Actualizar-Herramientas-Directas
            } catch {
                if ($lblAct) { $lblAct.Text = 'Todo al día' }
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
    } catch {
        Registrar-Error "Al mostrar ventana ($pasoUi): $($_.Exception.Message)"
        try { if ($lblAct) { $lblAct.Text = 'Listo' } } catch { Catch-Log 'Cancelar-Operacion' $_ }
    }
})
#endregion Eventos

#region Arrancar
# ================================================================
#  Arrancar
# ================================================================
[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $e)
    $msg = $e.Exception.Message
    try { $msg += " | " + $e.Exception.StackTrace } catch { Catch-Log 'Cancelar-Operacion' $_ }
    Registrar-Error "UI: $msg"
})
[AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $e)
    try { Registrar-Error "Fatal: $($e.ExceptionObject)" } catch { Catch-Log 'Cancelar-Operacion' $_ }
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
    [System.Windows.Forms.MessageBox]::Show("Ha ocurrido un error inesperado:`n`n$($_.Exception.Message)`n`nSe ha guardado en el registro de errores.", 'MusicDL', 'OK', 'Error') | Out-Null
} finally {
    if ($script:mutex) { try { $script:mutex.ReleaseMutex() } catch {}; try { $script:mutex.Dispose() } catch {} }
}
#endregion Arrancar

