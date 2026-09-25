# MusicDL

Descarga música desde **YouTube**, **SoundCloud** y **Spotify** en Windows.

- Interfaz oscura estilo deck
- Formatos: Original, MP3, M4A, OPUS, FLAC, WAV
- Mis listas, cola y modo Mini
- Spotify: spotDL empareja en YouTube; yt-dlp descarga
- Actualizaciones **firmadas RSA**
- Si hay DRM: puede buscar la canción en YouTube (pestaña **AJUSTES**)

**Versión actual:** 3.24 · **Made by WLY**

---

## Cómo usarlo

1. Ve a [Releases](https://github.com/Brawliot/MusicDL/releases/latest)
2. Descarga **MusicDL.bat** (lo más fácil) **o** **MusicDL.zip** (clic derecho → Extraer todo)
3. Abre **MusicDL.bat**
4. Si Windows avisa: *Más información* → *Ejecutar de todas formas*
5. La primera vez instalará yt-dlp, FFmpeg, Deno y spotDL (espera)
6. Pega el enlace y pulsa **Descargar**

Para actualizaciones automáticas, deja **MusicDL.bat.sig** en la misma carpeta que el `.bat`.

**Solo Windows 10/11.** No hace falta Python ni Git.

---

## Aviso legal (uso)

MusicDL es una herramienta **local** de uso personal. Tú eres responsable de cómo la usas.

- Respeta los términos de YouTube, SoundCloud y Spotify, y la legislación de tu país sobre derechos de autor.
- No uses MusicDL para redistribuir, vender o compartir contenido sin permiso.
- Spotify **no** entrega audio Premium: se busca una versión equivalente en YouTube/YouTube Music; la calidad es la del vídeo encontrado.
- El autor no se hace responsable del uso indebido ni de bloqueos, cambios o limitaciones de las plataformas.
- Al usar MusicDL aceptas estas condiciones.

---

## Autoría y uso del programa

© WLY — MusicDL. Todos los derechos reservados.

- Puedes usarlo en tu PC para uso personal.
- **No** lo redistribuyas como producto propio, ni quites o sustituyas el crédito **Made by WLY** / el nombre MusicDL para hacerlo pasar por tuyo.
- Las actualizaciones oficiales solo se aceptan si llevan la **firma RSA** del autor. Una copia modificada no podrá actualizarse haciéndose pasar por la versión oficial.

---

## Notas

- **Elegir…** solo aplica a listas de YouTube/SoundCloud. Con Spotify usa **Descargar**.
- Canciones con DRM: el programa puede preguntar si buscarlas en YouTube; puedes cambiarlo en **AJUSTES**.
- Datos locales: `%APPDATA%\MusicDL\` (si venías de la versión antigua, se migran desde `DescargarMusica`).
