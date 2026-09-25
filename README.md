# MusicDL

Descarga música desde **YouTube**, **SoundCloud** y **Spotify** en Windows.

- Interfaz oscura estilo deck
- Formatos: Original, MP3, M4A, OPUS, FLAC, WAV
- Mis listas (solo canciones nuevas)
- Cola de descargas y modo Mini
- Spotify vía **spotDL** (busca cada tema en YouTube/YouTube Music)
- Actualizaciones **firmadas RSA** (sin firma válida no se instalan)

Made by WLY.

---

## Uso rápido

1. Abre `MusicDL.bat`
2. La primera vez instala yt-dlp, FFmpeg y Deno (automático)
3. Pega un enlace y pulsa **Descargar**
4. Si es Spotify, la primera vez también baja spotDL (~45 MB)

No hace falta instalar Python ni nada más.

---

## Notas

- **Spotify**: no descarga el audio de Spotify Premium; usa YouTube/YouTube Music con metadatos de Spotify. La calidad es la del vídeo encontrado.
- Datos locales del usuario: `%APPDATA%\MusicDL\` (ajustes, historial, binarios). Si tenías la versión antigua, se migran solos desde `%APPDATA%\DescargarMusica\`.
- Requisitos: Windows 10/11, PowerShell, conexión a internet.
