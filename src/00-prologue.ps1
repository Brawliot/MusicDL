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
    if exist "%DM_DIR%\prev-version.bat.sig" copy /y "%DM_DIR%\prev-version.bat.sig" "%DM_BAT%.sig" >nul
    echo Restaurado automaticamente tras un fallo de actualizacion. > "%DM_DIR%\errores.log"
  )
  del /f /q "%DM_DIR%\esperando-arranque.flag" >nul 2>&1
  del /f /q "%DM_DIR%\update-pending.flag" >nul 2>&1
)
if exist "%DM_DIR%\update-pending.flag" (
  echo. > "%DM_DIR%\esperando-arranque.flag"
)

REM Sin Bypass/iex: firma RSA sobre $bytes y ScriptBlock desde esos mismos bytes (sin releer disco)
start "" powershell -NoProfile -STA -WindowStyle Hidden -Command "& { $ErrorActionPreference='Stop'; $bat=$env:DM_BAT; $sig=$bat+'.sig'; Add-Type -AssemblyName System.Windows.Forms; if (-not (Test-Path -LiteralPath $sig)) { [void][System.Windows.Forms.MessageBox]::Show('Falta MusicDL.bat.sig junto al programa. Sin firma RSA no se inicia.','MusicDL',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error); exit 1 }; $pub=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:DM_PUB_B64)); $tmp=[Security.Cryptography.RSA]::Create(); $tmp.FromXmlString($pub); $rp=$tmp.ExportParameters($false); $tmp.Dispose(); $rsa=New-Object Security.Cryptography.RSACng; $rsa.ImportParameters($rp); $bytes=[IO.File]::ReadAllBytes($bat); $firma=[Convert]::FromBase64String(((Get-Content -LiteralPath $sig -Raw) -replace '\s','')); if (-not $rsa.VerifyData($bytes,$firma,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pss)) { [void][System.Windows.Forms.MessageBox]::Show('La firma de MusicDL no es valida. No se inicia.','MusicDL',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error); exit 1 }; $raw=[Text.Encoding]::UTF8.GetString($bytes); $sb=[scriptblock]::Create($raw); & $sb }"
exit /b
#>

# ================================================================
#  MusicDL  -  YouTube, SoundCloud y Spotify (spotDL)  (v3.40)
#  Usa yt-dlp, FFmpeg, Deno y spotDL (URL fija + SHA256; sin winget).
#  Arranque y actualizaciones exigen firma RSA del autor.
#  Arquitectura: un solo archivo a proposito (distribucion simple); secciones
#  marcadas con #region / #endregion. Sin ofuscacion.
# ================================================================

$versionApp = '3.40'
$script:sugerirUpdateYtdlp = $false
$script:yaOfrecioUpdateSesion = $false
# Enlace Raw del .bat en GitHub. Si está vacío, no busca versiones nuevas.
$urlApp = 'https://raw.githubusercontent.com/Brawliot/MusicDL/main/MusicDL.bat'
# Enlace Raw de la firma (.sig). Si vacío, se usa $urlApp + '.sig'
$urlFirma = ''

# Clave pública RSA (XML). Solo el autor tiene la privada (clave-privada.xml).
$clavePublicaXml = '<RSAKeyValue><Modulus>po2BhuG7eWT/bc65ZUh8QesDy5VFoG1+xU77YmW9OLWU+w0kZx0N7MfzAD4pSZleTbv3gxm9UwTFFSuApEDlsDYAYemd5WgMU70TgoXV7cEbX/DuvBwRo34ezCCjDafcRkpL5T3cXj1vNcZPIiCOpw1UzjPzUlFT8+fIjsBocmVSat1aKlfZWUXpQtEsF0OgMo1mL+lPMV15RyKUOGZB/QOg0JnUvTux2ywGUQtOo7uvYQN1Cl08X7iKpAObJZXny2Nu2BbDIAYj+IURvvZF3EVArkzhWtNjUSgf2/5e1GD/jTWJeVYbkRnG19fsc2TGonwxZdEGM8aCD0y6ULoVSQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'

# UI: Continue para no tumbar timers/WinForms por errores no fatales.
# Rutas criticas (descarga, install, firma, update) usan Con-ErrorActionStop.
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
$script:formatosEtiquetaEs = @(
    'Original (sin convertir)',
    'MP3 (recomendado)',
    'M4A (iPhone)',
    'OPUS (poca espacio)',
    'FLAC (sin pérdida)',
    'WAV (sin comprimir)'
)
$script:formatosEtiquetaEn = @(
    'Original (no convert)',
    'MP3 (recommended)',
    'M4A (iPhone)',
    'OPUS (small size)',
    'FLAC (lossless)',
    'WAV (uncompressed)'
)
$formatosEtiqueta = $script:formatosEtiquetaEs


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

function Texto-Destino-Amigable([string]$ruta) {
    $ruta = Normalizar-Carpeta-Destino $ruta
    $def = Normalizar-Carpeta-Destino (Carpeta-Destino-Por-Defecto)
    # "Música" con código Unicode (evita líos de encoding del .bat)
    $musica = 'M' + [string][char]0x00FA + 'sica'
    if ([string]::Equals($ruta, $def, [StringComparison]::OrdinalIgnoreCase)) {
        return ($musica + ' descargada (en tu carpeta ' + $musica + ')')
    }
    $nombre = [IO.Path]::GetFileName($ruta)
    if (-not $nombre) { $nombre = $ruta }
    $padres = @(
        @{ r = [Environment]::GetFolderPath('MyMusic'); n = $musica },
        @{ r = [Environment]::GetFolderPath('MyDocuments'); n = 'Documentos' },
        @{ r = [Environment]::GetFolderPath('Desktop'); n = 'Escritorio' },
        @{ r = (Join-Path $env:USERPROFILE 'Downloads'); n = 'Descargas' },
        @{ r = $env:USERPROFILE; n = 'tu usuario' }
    )
    foreach ($p in $padres) {
        if (-not $p.r) { continue }
        try {
            $root = [IO.Path]::GetFullPath(($p.r.TrimEnd('\') + '\'))
            $full = [IO.Path]::GetFullPath(($ruta.TrimEnd('\') + '\'))
            if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                if ($full.Length -eq $root.Length) { return ("Tu carpeta " + $p.n) }
                return ($nombre + ' (en ' + $p.n + ')')
            }
        } catch { Catch-Log 'Texto-Destino-Amigable' $_ }
    }
    return $nombre
}

function Carpeta-UI-Actual {
    if ($script:carpetaReal) { return (Normalizar-Carpeta-Destino $script:carpetaReal) }
    return (Carpeta-Destino-Por-Defecto)
}

function Fijar-Carpeta-UI([string]$ruta) {
    $script:carpetaReal = Normalizar-Carpeta-Destino $ruta
    if ($txtCarpeta -and -not $txtCarpeta.IsDisposed) {
        $txtCarpeta.Text = Texto-Destino-Amigable $script:carpetaReal
        if ($tips) { $tips.SetToolTip($txtCarpeta, $script:carpetaReal) }
    }
}

$config = [ordered]@{
    formato            = 1
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
    avisoLegalRevision = 0
    modoSimple         = $true
    onboardingHecho    = $false
    avisoSpotifyHecho  = $false
    idioma             = 'es'
}
# Sube este número si cambia el texto legal (obliga a reaceptar).
$script:avisoLegalRevisionActual = 2

function Idioma-Actual {
    try {
        if ([string]$config.idioma -eq 'en') { return 'en' }
    } catch {}
    return 'es'
}
function T([string]$es, [string]$en) {
    if ((Idioma-Actual) -eq 'en' -and $en) { return $en }
    return $es
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
        # v3.37: modo simple / onboarding (usuarios antiguos no ven el tutorial otra vez)
        if (-not ($leido.PSObject.Properties.Name -contains 'modoSimple')) {
            $config.modoSimple = $true
        }
        if (-not ($leido.PSObject.Properties.Name -contains 'onboardingHecho')) {
            $config.onboardingHecho = [bool]$config.avisoLegalAceptado
        }
        if (-not ($leido.PSObject.Properties.Name -contains 'avisoSpotifyHecho')) {
            $config.avisoSpotifyHecho = $false
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
  } catch {
    # No reentrar en Catch-Log (evitar recursión si falla el registro)
  }
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
if ((Idioma-Actual) -eq 'en') {
    $formatosEtiqueta = $script:formatosEtiquetaEn
} else {
    $formatosEtiqueta = $script:formatosEtiquetaEs
}

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

# Herramientas: URL fija + SHA256 del artefacto (y sha256exe si viene en ZIP).
# Al subir versiones nuevas, actualiza url+sha256[+sha256exe] y firma el .bat.
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
        sha256exe = '2A1FD2A0A9FE7F3343DDE8B707354B4B36837A55735EE739D9F872A3CFE1F6F3'
        tipo = 'zip-ffmpeg'; destino = 'ffmpeg.exe'
    },
    @{
        cmd = 'deno'; id = 'DenoLand.Deno'; nombre = 'el complemento para YouTube'
        url = 'https://github.com/denoland/deno/releases/download/v2.9.7/deno-x86_64-pc-windows-msvc.zip'
        sha256 = 'A0C3101B4158D1DFB7D6A78A7BF0F3DE80C96BB423C152BEEC8BEB22786F2238'
        sha256exe = 'E020F3E232BD16E33768DEE528E5983349C962952051CED0A5D58AD42F5D9B33'
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

# Alto contraste de Windows: usar colores del sistema (M5)
$script:altoContraste = $false
try { $script:altoContraste = [System.Windows.Forms.SystemInformation]::HighContrast } catch { $script:altoContraste = $false }
if ($script:altoContraste) {
    $colFondo     = [System.Drawing.SystemColors]::Control
    $colPanel     = [System.Drawing.SystemColors]::Window
    $colCampo     = [System.Drawing.SystemColors]::Window
    $colTexto     = [System.Drawing.SystemColors]::WindowText
    $colSuave     = [System.Drawing.SystemColors]::GrayText
    $colTenue     = [System.Drawing.SystemColors]::GrayText
    $colBorde     = [System.Drawing.SystemColors]::WindowFrame
    $colHover     = [System.Drawing.SystemColors]::Highlight
    $colAcento    = [System.Drawing.SystemColors]::Highlight
    $colAcentoOsc = [System.Drawing.SystemColors]::HotTrack
    $colCancelar  = [System.Drawing.SystemColors]::ControlDark
    $colBlanco    = [System.Drawing.SystemColors]::HighlightText
    $colExito     = [System.Drawing.SystemColors]::Highlight
    $colAviso     = [System.Drawing.SystemColors]::HotTrack
}

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

