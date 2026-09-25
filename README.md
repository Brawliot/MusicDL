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

## Qué subir a GitHub

| Archivo | ¿Subir? |
|---------|---------|
| `MusicDL.bat` | Sí |
| `MusicDL.bat.sig` | Sí (firma de esa versión) |
| `clave-publica.xml` | Sí (opcional; ya va dentro del .bat) |
| `Firmar-Version.ps1` | Sí (para que tú firmes nuevas versiones) |
| `README.md` | Sí |
| `.gitignore` | Sí |
| **`clave-privada.xml`** | **NO** (nunca) |

El `.gitignore` del repo ya bloquea la clave privada.

---

## Actualizaciones automáticas (`$urlApp` / raw)

En `MusicDL.bat` hay dos líneas cerca del inicio:

```powershell
$urlApp = ''
$urlFirma = ''
```

### Qué poner

1. Crea el repo en GitHub (ej. `tu-usuario/MusicDL`).
2. Sube los archivos (al menos `MusicDL.bat` y `MusicDL.bat.sig` en la raíz, rama `main`).
3. Abre cada archivo en GitHub → botón **Raw** → copia la URL.

Te quedará algo así:

```text
https://raw.githubusercontent.com/TU_USUARIO/MusicDL/main/MusicDL.bat
https://raw.githubusercontent.com/TU_USUARIO/MusicDL/main/MusicDL.bat.sig
```

4. En el `.bat`, pon:

```powershell
$urlApp = 'https://raw.githubusercontent.com/TU_USUARIO/MusicDL/main/MusicDL.bat'
$urlFirma = ''   # vacío = usa automáticamente $urlApp + '.sig'
```

Si la firma está en otra ruta, rellena `$urlFirma` con el Raw del `.sig`.

5. **Vuelve a firmar** (el cambio de URL invalida la firma anterior) y sube otra vez `.bat` + `.sig`.

Si `$urlApp` queda vacío, el programa no busca versiones nuevas (sigue funcionando igual).

---

## Firmar una versión

Solo en tu PC, con la clave privada (que no está en GitHub):

```powershell
cd ruta\a\MusicDL
.\Firmar-Version.ps1
```

Eso genera/actualiza `MusicDL.bat.sig`.

**Cada vez que edites `MusicDL.bat`** (versión, URLs, código…):

1. Sube `$versionApp` si es una versión nueva (ej. `'3.8'`)
2. Ejecuta `.\Firmar-Version.ps1`
3. Sube a GitHub **los dos**: `MusicDL.bat` y `MusicDL.bat.sig`

Sin un `.sig` válido que coincida con el `.bat`, nadie podrá actualizar desde el menú.

---

## Checklist al publicar / actualizar

1. [ ] `clave-privada.xml` no está en el repo
2. [ ] `$urlApp` apunta al Raw correcto
3. [ ] `$versionApp` es mayor que la de los usuarios
4. [ ] Ejecutado `Firmar-Version.ps1`
5. [ ] Subidos `MusicDL.bat` + `MusicDL.bat.sig`

---

## Notas

- **Spotify**: no descarga el audio de Spotify Premium; usa YouTube/YouTube Music con metadatos de Spotify. La calidad es la del vídeo encontrado.
- Datos locales del usuario: `%APPDATA%\DescargarMusica\` (ajustes, historial, binarios).
- Requisitos: Windows 10/11, PowerShell, conexión a internet.
