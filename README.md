# MusicDL

Descarga música desde **YouTube**, **SoundCloud** y **Spotify** en Windows.

- Interfaz oscura estilo deck
- Formatos: Original, MP3, M4A, OPUS, FLAC, WAV
- Mis listas, cola y modo Mini
- Spotify: spotDL empareja en YouTube; yt-dlp descarga
- Actualizaciones firmadas RSA

**Versión actual:** 3.20 · Made by WLY

---

## Aviso legal

MusicDL es una herramienta **local** de uso personal. Tú eres responsable de cómo la usas.

- Respeta los términos de YouTube, SoundCloud y Spotify, y la legislación de tu país sobre derechos de autor.
- No uses MusicDL para redistribuir, vender o compartir contenido sin permiso.
- Spotify **no** entrega audio Premium: se busca una versión equivalente en YouTube/YouTube Music; la calidad es la del vídeo encontrado.
- El autor no se hace responsable del uso indebido ni de bloqueos, cambios o limitaciones de las plataformas.
- Al usar MusicDL aceptas estas condiciones.

---

## Cómo usarlo (usuarios)

1. Descarga **MusicDL.zip** desde [Releases](https://github.com/Brawliot/MusicDL/releases/latest)
2. Extráelo (clic derecho → Extraer)
3. Abre **MusicDL.bat**
4. Si Windows avisa: *Más información* → *Ejecutar de todas formas*
5. La primera vez instalará yt-dlp, FFmpeg, Deno y spotDL (espera)
6. Pega el enlace y pulsa **Descargar**

Solo Windows 10/11. No hace falta Python ni Git.

---

## Notas

- **Elegir…** solo aplica a listas de YouTube/SoundCloud. Con Spotify usa **Descargar**.
- Datos locales: `%APPDATA%\MusicDL\` (si venías de la versión antigua, se migran desde `DescargarMusica`).

---

## Para el autor (GitHub / firma)

Sube al repo: `MusicDL.bat`, `MusicDL.bat.sig`, `README.md`, `.gitignore`, `Firmar-Version.ps1`, `clave-publica.xml`.  
**Nunca** subas `clave-privada.xml`.

```powershell
$urlApp = 'https://raw.githubusercontent.com/Brawliot/MusicDL/main/MusicDL.bat'
$urlFirma = ''
```

Tras editar el `.bat`: `.\Firmar-Version.ps1` y sube `.bat` + `.sig`.
