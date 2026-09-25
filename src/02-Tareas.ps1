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

