# Pester tests — MusicDL (funciones puras)
# Requiere Pester 5+:  Import-Module Pester -MinimumVersion 5.0.0
# Ejecutar:  Invoke-Pester -Path .\tests

BeforeAll {
    . (Join-Path $PSScriptRoot 'Import-MusicDLFns.ps1')
}

Describe 'Es-Enlace-Valido' {
    It 'acepta YouTube https' {
        Es-Enlace-Valido 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' | Should -Be $true
    }
    It 'acepta youtu.be' {
        Es-Enlace-Valido 'https://youtu.be/dQw4w9WgXcQ' | Should -Be $true
    }
    It 'acepta SoundCloud' {
        Es-Enlace-Valido 'https://soundcloud.com/artist/track-name' | Should -Be $true
    }
    It 'acepta Spotify open' {
        Es-Enlace-Valido 'https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6' | Should -Be $true
    }
    It 'rechaza http' {
        Es-Enlace-Valido 'http://www.youtube.com/watch?v=dQw4w9WgXcQ' | Should -Be $false
    }
    It 'rechaza metacaracteres' {
        Es-Enlace-Valido 'https://www.youtube.com/watch?v=abc|calc' | Should -Be $false
    }
    It 'rechaza dominio desconocido' {
        Es-Enlace-Valido 'https://example.com/video' | Should -Be $false
    }
    It 'rechaza vacío' {
        Es-Enlace-Valido '' | Should -Be $false
    }
}

Describe 'Tipo-Enlace' {
    It 'detecta youtube' {
        Tipo-Enlace 'https://music.youtube.com/watch?v=aaaaaaaaaaa' | Should -Be 'youtube'
    }
    It 'detecta soundcloud' {
        Tipo-Enlace 'https://m.soundcloud.com/x/y' | Should -Be 'soundcloud'
    }
    It 'detecta spotify' {
        Tipo-Enlace 'https://spotify.link/AbCd123' | Should -Be 'spotify'
    }
}

Describe 'Es-Carpeta-Destino-Segura' {
    It 'acepta carpeta bajo el perfil' {
        $p = Join-Path $env:USERPROFILE 'MusicDL-test-safe'
        Es-Carpeta-Destino-Segura $p | Should -Be $true
    }
    It 'rechaza System32' {
        Es-Carpeta-Destino-Segura 'C:\Windows\System32' | Should -Be $false
    }
    It 'rechaza vacío' {
        Es-Carpeta-Destino-Segura '' | Should -Be $false
    }
}

Describe 'Texto-Destino-Amigable' {
    It 'describe la carpeta por defecto sin ruta cruda' {
        $t = Texto-Destino-Amigable (Carpeta-Destino-Por-Defecto)
        $t | Should -Match 'descargada'
        $t | Should -Not -Match '^[A-Z]:\\'
    }
    It 'nombra una subcarpeta bajo Musica' {
        $p = Join-Path ([Environment]::GetFolderPath('MyMusic')) 'MisHits'
        $t = Texto-Destino-Amigable $p
        $t | Should -Match 'MisHits'
        $t | Should -Match '\(en '
    }
}

Describe 'Verificar-Sha256' {
    It 'valida hash correcto' {
        $f = Join-Path $env:TEMP ("musicdl-sha-" + [Guid]::NewGuid().ToString('N') + '.bin')
        [IO.File]::WriteAllBytes($f, [byte[]](1, 2, 3, 4, 5))
        $h = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash
        Verificar-Sha256 $f $h | Should -Be $true
        Remove-Item -LiteralPath $f -Force
    }
    It 'rechaza hash incorrecto' {
        $f = Join-Path $env:TEMP ("musicdl-sha-" + [Guid]::NewGuid().ToString('N') + '.bin')
        [IO.File]::WriteAllBytes($f, [byte[]](9, 9, 9))
        Verificar-Sha256 $f ('0' * 64) | Should -Be $false
        Remove-Item -LiteralPath $f -Force
    }
    It 'rechaza sin esperado' {
        Verificar-Sha256 $PSScriptRoot '' | Should -Be $false
    }
}

Describe 'DRM título' {
    It 'detecta comodín Cancion N de M' {
        # ASCII: el patrón acepta Canci[oó]n (el .ps1 puede perder tildes según encoding)
        Es-Titulo-Comodin-Drm 'Cancion 25 de 35' | Should -Be $true
        Es-Titulo-Comodin-Drm ([string]([char]0x43) + 'anci' + [char]0xF3 + 'n 3 de 9') | Should -Be $true
    }
    It 'no marca título real como comodín' {
        Es-Titulo-Comodin-Drm 'Joan Sebastian - Veinticinco Rosas' | Should -Be $false
    }
    It 'slug SoundCloud a query' {
        Titulo-Desde-Url-Track 'https://soundcloud.com/some-artist/cool-track' | Should -Be 'some artist cool track'
    }
    It 'Titulo-Para-Busqueda-Drm ignora comodín y usa URL' {
        $d = @{ titulo = 'Cancion 1 de 10'; tituloDesdeUrl = 'artist song' }
        Titulo-Para-Busqueda-Drm $d | Should -Be 'artist song'
    }
}

Describe 'Herramientas fijadas en MusicDL.bat' {
    It 'cada herramienta tiene url https y sha256 de 64 hex' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $shaMatches = [regex]::Matches($text, "sha256\s*=\s*'([0-9A-Fa-f]{64})'")
        $shaMatches.Count | Should -BeGreaterOrEqual 4
        $urlLatest = [regex]::IsMatch($text, 'releases/latest')
        $urlLatest | Should -Be $false
    }
    It 'Ruta-De no usa Get-Command / PATH del sistema' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $fn = [regex]::Match($text, '(?s)function Ruta-De\(\$cmd\) \{.*?^function ', [Text.RegularExpressions.RegexOptions]::Multiline).Value
        $fn | Should -Match 'dirBin'
        $fn | Should -Not -Match 'Get-Command'
    }
    It 'hay Esperar-Proceso-Con-Timeout y helpers de descarga' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $text | Should -Match 'function Esperar-Proceso-Con-Timeout'
        $text | Should -Match 'function Preparar-Carpeta-Y-Config-Descarga'
        $text | Should -Match 'function Nuevo-Estado-Descarga'
        $text | Should -Match 'function Arrancar-Ui-Descarga'
    }
}

Describe 'Formato-Args-Informe' {
    It 'cita args con espacios' {
        $s = Formato-Args-Informe @('-P', 'C:\Users\Me\My Music', 'https://youtu.be/x')
        $s | Should -Match 'My Music'
        $s | Should -Match 'https://youtu.be/x'
    }
    It 'Q escapa comillas dobles' {
        Q 'a"b' | Should -Be '"a\"b"'
    }
}

Describe 'i18n T / Idioma-Actual' {
    It 'por defecto devuelve español' {
        $script:config = [ordered]@{ idioma = 'es' }
        Idioma-Actual | Should -Be 'es'
        T 'Hola' 'Hello' | Should -Be 'Hola'
    }
    It 'en inglés devuelve en' {
        $script:config = [ordered]@{ idioma = 'en' }
        Idioma-Actual | Should -Be 'en'
        T 'Hola' 'Hello' | Should -Be 'Hello'
    }
}

Describe 'Accesibilidad / DoEvents / ZIP selectivo' {
    It 'define Bombeo-Ui y no deja DoEvents sueltos fuera de Bombeo-Ui' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $text | Should -Match 'function Bombeo-Ui'
        $all = [regex]::Matches($text, '\[System\.Windows\.Forms\.Application\]::DoEvents\(\)')
        $all.Count | Should -Be 1
    }
    It 'Extraer-Zip-Selectivo no usa ExtractToDirectory' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $fn = [regex]::Match($text, '(?s)function Extraer-Zip-Selectivo.*?^function ', [Text.RegularExpressions.RegexOptions]::Multiline).Value
        $fn | Should -Match 'ZipArchive'
        $fn | Should -Match 'Es-Entrada-Zip-Segura'
        $fn | Should -Not -Match 'ExtractToDirectory'
    }
    It 'controles principales fijan AccessibleName' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $text | Should -Match 'AccessibleName'
        $text | Should -Match 'HighContrast'
        $text | Should -Match 'AccessibleRole]::Document'
    }
}

Describe 'Build-Zip no empaqueta Firmar-Version' {
    It 'Build-Zip.ps1 no incluye Firmar-Version.ps1' {
        $ps1 = Join-Path (Split-Path $PSScriptRoot -Parent) 'Build-Zip.ps1'
        $text = Get-Content -LiteralPath $ps1 -Raw -Encoding UTF8
        $text | Should -Not -Match "Firmar-Version\.ps1'"
    }
}

Describe 'Firma RSA / arranque sin TOCTOU' {
    BeforeAll {
        $script:root = Split-Path $PSScriptRoot -Parent
        $script:batPath = Join-Path $script:root 'MusicDL.bat'
        $script:sigPath = Join-Path $script:root 'MusicDL.bat.sig'
        $script:pubPath = Join-Path $script:root 'clave-publica.xml'
        $script:batBytes = [IO.File]::ReadAllBytes($script:batPath)
        $script:batText = [Text.Encoding]::UTF8.GetString($script:batBytes)
        $script:firmaB64 = ((Get-Content -LiteralPath $script:sigPath -Raw) -replace '\s', '')
    }

    It 'launcher usa GetString($bytes) y no vuelve a leer el .bat del disco' {
        $launch = [regex]::Match($script:batText, '(?s)start "" powershell.*?exit /b').Value
        $launch | Should -Match '\[Text\.Encoding\]::UTF8\.GetString\(\$bytes\)'
        $launch | Should -Not -Match 'ReadAllText\(\$bat'
        # Tras VerifyData solo debe haber Create desde $bytes (una lectura ReadAllBytes)
        ([regex]::Matches($launch, 'ReadAllBytes\(\$bat\)')).Count | Should -Be 1
    }

    It 'DM_PUB_B64, $clavePublicaXml y clave-publica.xml coinciden' {
        $mCmd = [regex]::Match($script:batText, 'set "DM_PUB_B64=([^"]+)"')
        $mCmd.Success | Should -Be $true
        $fromCmd = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($mCmd.Groups[1].Value)) -replace '\s', '').Trim()
        $mPs = [regex]::Match($script:batText, '\$clavePublicaXml = ''([^'']+)''')
        $mPs.Success | Should -Be $true
        $fromPs = ($mPs.Groups[1].Value -replace '\s', '').Trim()
        $fromFile = ((Get-Content -LiteralPath $script:pubPath -Raw -Encoding UTF8) -replace '\s', '').Trim()
        $fromCmd | Should -Be $fromFile
        $fromPs | Should -Be $fromFile
    }

    It 'Verificar-Firma acepta MusicDL.bat.sig actual' {
        Verificar-Firma $script:batBytes $script:firmaB64 | Should -Be $true
    }

    It 'Verificar-Firma rechaza bytes alterados' {
        $tampered = [byte[]]::new($script:batBytes.Length)
        [Array]::Copy($script:batBytes, $tampered, $script:batBytes.Length)
        $tampered[0] = $tampered[0] -bxor 0xFF
        Verificar-Firma $tampered $script:firmaB64 | Should -Be $false
    }

    It 'Verificar-Firma rechaza firma basura' {
        Verificar-Firma $script:batBytes 'AAAA' | Should -Be $false
    }

    It 'Firmar-Version.ps1 rechaza clave dentro del repo' {
        $ps1 = Join-Path $script:root 'Firmar-Version.ps1'
        $text = Get-Content -LiteralPath $ps1 -Raw -Encoding UTF8
        $text | Should -Match 'RECHAZADO: la clave privada'
        $text | Should -Match 'DENTRO del repo'
        $text | Should -Match 'VerifyData'
        $text | Should -Match 'RSASignaturePadding\]::Pss'
        $text | Should -Match 'Fingerprint|FP pub|firmas\.log'
        $text | Should -Match 'FIRMAR'
    }
}

Describe 'L1 RSA-PSS / L2 sync clave / M4 Con-ErrorActionStop / M6 bak' {
    It 'arranque y Verificar-Firma usan PSS' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $launch = [regex]::Match($text, '(?s)start "" powershell.*?exit /b').Value
        $launch | Should -Match 'RSASignaturePadding\]::Pss'
        $launch | Should -Not -Match 'RSASignaturePadding\]::Pkcs1'
        $fn = [regex]::Match($text, '(?s)function Verificar-Firma.*?^function ', [Text.RegularExpressions.RegexOptions]::Multiline).Value
        $fn | Should -Match 'RSASignaturePadding\]::Pss'
    }
    It 'Sync-ClavePublica -Check pasa' {
        $root = Split-Path $PSScriptRoot -Parent
        $p = Start-Process -FilePath powershell.exe -ArgumentList @(
            '-NoProfile', '-File', (Join-Path $root 'Sync-ClavePublica.ps1'), '-Check'
        ) -Wait -PassThru -WindowStyle Hidden
        $p.ExitCode | Should -Be 0
    }
    It 'define Con-ErrorActionStop y lo usan rutas criticas' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $text | Should -Match 'function Con-ErrorActionStop'
        $text | Should -Match 'Instalar-Herramienta-Directa[\s\S]{0,80}Con-ErrorActionStop'
        $text | Should -Match 'Instalar-VersionApp[\s\S]{0,80}Con-ErrorActionStop'
    }
    It 'no hay MusicDL.bat.sig.bak-ux en el repo' {
        $root = Split-Path $PSScriptRoot -Parent
        Test-Path -LiteralPath (Join-Path $root 'MusicDL.bat.sig.bak-ux') | Should -Be $false
        $gi = Get-Content -LiteralPath (Join-Path $root '.gitignore') -Raw -Encoding UTF8
        $gi | Should -Match '\.sig\.bak'
    }
}

Describe 'M1 desinstalacion borra .sig' {
    It 'Terminar-Desinstalacion elimina bat y sig' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $fn = [regex]::Match($text, '(?s)function Terminar-Desinstalacion.*?^function ', [Text.RegularExpressions.RegexOptions]::Multiline).Value
        $fn | Should -Match 'del /f /q `"\$bat`"'
        $fn | Should -Match '\$sigDel'
        $fn | Should -Match 'del /f /q `"\$sigDel`"'
    }
}

Describe 'M5 sha256exe tras ZIP' {
    It 'ffmpeg y deno declaran sha256exe de 64 hex' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $text | Should -Match "cmd = 'ffmpeg'[\s\S]*?sha256exe = '[0-9A-Fa-f]{64}'"
        $text | Should -Match "cmd = 'deno'[\s\S]*?sha256exe = '[0-9A-Fa-f]{64}'"
    }
    It 'Instalar-Herramienta-Directa verifica sha256exe tras extraer' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $fn = [regex]::Match($text, '(?s)function Instalar-Herramienta-Directa.*?^function ', [Text.RegularExpressions.RegexOptions]::Multiline).Value
        $fn | Should -Match 'sha256exe'
        $fn | Should -Match 'SHA256 exe inv'
    }
    It 'Ruta-De usa sha256exe para herramientas zip' {
        $bat = Join-Path (Split-Path $PSScriptRoot -Parent) 'MusicDL.bat'
        $text = Get-Content -LiteralPath $bat -Raw -Encoding UTF8
        $fn = [regex]::Match($text, '(?s)function Ruta-De\(\$cmd\) \{.*?^function ', [Text.RegularExpressions.RegexOptions]::Multiline).Value
        $fn | Should -Match 'sha256exe'
    }
}

Describe 'M3 src/ ensamblado' {
    It 'existe src/modules.txt y Assemble-MusicDL.ps1 -Check pasa' {
        $root = Split-Path $PSScriptRoot -Parent
        Test-Path -LiteralPath (Join-Path $root 'src\modules.txt') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $root 'Assemble-MusicDL.ps1') | Should -Be $true
        $p = Start-Process -FilePath powershell.exe -ArgumentList @(
            '-NoProfile', '-File', (Join-Path $root 'Assemble-MusicDL.ps1'), '-Check'
        ) -Wait -PassThru -WindowStyle Hidden
        $p.ExitCode | Should -Be 0
    }
}

Describe 'M2 Construir-Args / Nombre-Carpeta-Seguro' {
    BeforeEach {
        $global:cmbFormato = @{ SelectedIndex = 1 }
        $global:cmbOrganizar = @{ SelectedIndex = 0 }
        $global:chkLimpiar = @{ Checked = $false }
        $global:chkPortada = @{ Checked = $false }
        $global:chkSaltar = @{ Checked = $false }
    }

    It 'Nombre-Carpeta-Seguro limpia caracteres invalidos' {
        Nombre-Carpeta-Seguro 'A<>:"/\|?*B' | Should -Be 'AB'
        Nombre-Carpeta-Seguro '' | Should -Be ''
    }

    It 'Construir-Args incluye enlace y carpeta segura' {
        $url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
        $r = Construir-Args @($url) $false $null
        $r.fmt | Should -Be 'mp3'
        $r.finales | Should -Contain $url
        $joined = [string]($r.args -join ' ')
        $joined.Contains('-P') | Should -Be $true
        $joined.Contains($url) | Should -Be $true
        Es-Carpeta-Destino-Segura $r.carpeta | Should -Be $true
    }

    It 'Construir-Args formato original no usa -x' {
        $global:cmbFormato.SelectedIndex = 0
        $r = Construir-Args @('https://youtu.be/dQw4w9WgXcQ') $false $null
        $r.fmt | Should -Be 'original'
        $joined = [string]($r.args -join ' ')
        $joined.Contains('bestaudio') | Should -Be $true
        ($r.args -contains '-x') | Should -Be $false
    }

    It 'Construir-Args con indices anade -I' {
        $r = Construir-Args @('https://youtu.be/dQw4w9WgXcQ') $false '1-3'
        ($r.args -contains '-I') | Should -Be $true
        ($r.args -contains '1-3') | Should -Be $true
    }
}
