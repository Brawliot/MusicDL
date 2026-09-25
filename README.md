# MusicDL

Descarga música desde **YouTube**, **SoundCloud** y **Spotify** en Windows.

- Interfaz oscura estilo deck
- Formatos: Original, MP3, M4A, OPUS, FLAC, WAV
- Mis listas, cola y modo Mini
- Spotify: spotDL empareja en YouTube; yt-dlp descarga
- Actualizaciones **firmadas RSA**
- Si hay DRM: puede buscar la canción en YouTube (pestaña **AJUSTES**)

**Versión actual:** 3.36 · **Made by WLY**

---

## Cómo usarlo

1. Ve a [Releases](https://github.com/Brawliot/MusicDL/releases/latest)
2. Descarga **MusicDL.bat** (lo más fácil) **o** genera/descarga **MusicDL.zip**
3. Abre **MusicDL.bat**
4. Si Windows avisa: *Más información* → *Ejecutar de todas formas*
5. Acepta el aviso legal la primera vez
6. La primera vez instalará yt-dlp, FFmpeg, Deno y spotDL (espera)
7. Pega el enlace y pulsa **Descargar**

Para actualizaciones automáticas, deja **MusicDL.bat.sig** en la misma carpeta que el `.bat`.

**Solo Windows 10/11.** No hace falta Python ni Git.

---

## Aviso legal (uso)

MusicDL es una herramienta **local** de uso personal. Tú eres responsable de cómo la usas.

- Respeta los términos de YouTube, SoundCloud y Spotify, y la legislación de tu país sobre derechos de autor.
- No uses MusicDL para redistribuir, vender o compartir contenido sin permiso.
- Spotify **no** entrega audio Premium: se busca una versión equivalente en YouTube/YouTube Music; la calidad es la del vídeo encontrado.
- El autor no se hace responsable del uso indebido ni de bloqueos, cambios o limitaciones de las plataformas.
- Al usar MusicDL aceptas estas condiciones (también se muestran la primera vez que abres el programa).

---

## Autoría y uso del programa

© WLY — MusicDL. Todos los derechos reservados.

- Puedes usarlo en tu PC para uso personal.
- **No** lo redistribuyas como producto propio, ni quites o sustituyas el crédito **Made by WLY** / el nombre MusicDL para hacerlo pasar por tuyo.
- Las actualizaciones oficiales solo se aceptan si llevan la **firma RSA** del autor. Una copia modificada no podrá actualizarse haciéndose pasar por la versión oficial.

**Firma de releases (solo el autor):** la clave privada no va en este repo. Ruta por defecto: `%USERPROFILE%\.secrets\MusicDL\clave-privada.xml` (o variable `MUSICDL_SIGNING_KEY`). Luego: `.\Firmar-Version.ps1`.

**ZIP de distribución:** `.\Build-Zip.ps1` (genera `MusicDL.zip` con bat, sig, docs y clave pública; no incluye la privada).

---

## Actualizar herramientas (yt-dlp / FFmpeg / Deno / spotDL)

Las herramientas van **fijadas** (URL + SHA256) dentro de `MusicDL.bat` — no se usa `latest` a ciegas.

1. Descarga la release oficial deseada.
2. Calcula el SHA256 (`Get-FileHash -Algorithm SHA256`).
3. Actualiza `url` y `sha256` en la tabla `$herramientas`.
4. Sube `$versionApp` y firma: `.\Firmar-Version.ps1`.
5. Publica `MusicDL.bat` + `MusicDL.bat.sig`.

---

## Desarrollo / tests

```powershell
Import-Module Pester -MaximumVersion 5.99.99 -Force
Invoke-Pester -Path .\tests
```

CI: GitHub Actions (`.github/workflows/ci.yml`) ejecuta Pester 5 en Windows.

---

## Notas

- **Elegir…** solo aplica a listas de YouTube/SoundCloud. Con Spotify usa **Descargar**.
- Canciones con DRM: el programa puede preguntar si buscarlas en YouTube; puedes cambiarlo en **AJUSTES**.
- Datos locales: `%APPDATA%\MusicDL\` (si venías de la versión antigua, se migran desde `DescargarMusica`).
