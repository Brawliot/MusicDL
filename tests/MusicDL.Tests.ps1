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
}

Describe 'Formato-Args-Informe' {
    It 'cita args con espacios' {
        $s = Formato-Args-Informe @('-P', 'C:\Users\Me\My Music', 'https://youtu.be/x')
        $s | Should -Match 'My Music'
        $s | Should -Match 'https://youtu.be/x'
    }
}
