# MusicDL

Descarga música desde **YouTube**, **SoundCloud** y **Spotify** en Windows.

- Interfaz oscura estilo deck; **modo simple** por defecto
- Formatos: Original, MP3, M4A, OPUS, FLAC, WAV (MP3 por defecto en instalaciones nuevas)
- Mis listas, cola y modo Mini
- Spotify: spotDL empareja en YouTube; yt-dlp descarga (aviso claro la primera vez)
- Actualizaciones **firmadas RSA**
- Si hay DRM: puede buscar la canción en YouTube (pestaña **AJUSTES**)

**Versión actual:** 3.40 · **Made by WLY**

---

## Cómo usarlo

1. Ve a [Releases](https://github.com/Brawliot/MusicDL/releases/latest)
2. Descarga **MusicDL.bat** (lo más fácil) **o** genera/descarga **MusicDL.zip**
3. Abre **MusicDL.bat**
4. Si Windows avisa: *Más información* → *Ejecutar de todas formas*
5. Acepta el aviso legal y el tutorial de 3 pasos la primera vez
6. La primera vez instalará yt-dlp, FFmpeg, Deno y spotDL (espera)
7. Pega el enlace y pulsa **Descargar**

Por defecto: modo simple y carpeta «Música descargada». Usa **Más opciones** para formato y organización.

Para arrancar y actualizar hace falta **MusicDL.bat.sig** en la misma carpeta que el `.bat` (firma RSA obligatoria).

**Solo Windows 10/11.** No hace falta Python ni Git.

---

## Aviso legal (uso)

MusicDL es una herramienta **local** de uso personal. Tú eres responsable de cómo la usas.

- Respeta los términos de YouTube, SoundCloud y Spotify, y la legislación de tu país sobre derechos de autor.
- No uses MusicDL para redistribuir, vender o compartir contenido sin permiso.
- Spotify **no** entrega audio Premium: se busca una versión equivalente en YouTube/YouTube Music; la calidad es la del vídeo encontrado.
- Si hay DRM en la fuente, el programa **puede** buscar la misma pista en YouTube (configurable en AJUSTES); no desactiva el DRM de la plataforma. Eres responsable según la ley y los ToS.
- El autor no se hace responsable del uso indebido ni de bloqueos, cambios o limitaciones de las plataformas.
- Al usar MusicDL aceptas estas condiciones (se muestran **antes** de instalar herramientas la primera vez, y si el aviso se actualiza).

---

## Autoría y uso del programa

© WLY — MusicDL. Todos los derechos reservados.

- Puedes usarlo en tu PC para uso personal.
- **No** lo redistribuyas como producto propio, ni quites o sustituyas el crédito **Made by WLY** / el nombre MusicDL para hacerlo pasar por tuyo.
- Las actualizaciones oficiales solo se aceptan si llevan la **firma RSA** del autor. Una copia modificada no podrá actualizarse haciéndose pasar por la versión oficial.

**Firma de releases (solo el autor):** la clave privada no va en este repo.

Checklist rápido:
1. Clave solo en `%USERPROFILE%\.secrets\MusicDL\clave-privada.xml` (o `MUSICDL_SIGNING_KEY`).
2. Nunca en el repo, USB compartido, chat ni capturas. Backup offline cifrado.
3. ACL recomendada: `icacls "%USERPROFILE%\.secrets\MusicDL" /inheritance:r` y grant solo a tu usuario.
4. Fuente de verdad de la pública: `clave-publica.xml` → `.\Sync-ClavePublica.ps1` (inyecta CMD+PS).
5. El `.bat` en LF. Firma **RSA-PSS**: `.\Firmar-Version.ps1` (pide escribir `FIRMAR`, o `-Force`). Queda registro en `%USERPROFILE%\.secrets\MusicDL\firmas.log`.
6. Si sospechas filtración: deja de firmar, genera nuevo par RSA, sustituye `clave-publica.xml`, `Sync-ClavePublica`, firma y publica (rompe clientes con la pública antigua a propósito).

**ZIP de distribución:** `.\Build-Zip.ps1` (genera `MusicDL.zip` con bat, sig, docs y clave pública; no incluye la privada ni el script de firma).

---

## Actualizar herramientas (yt-dlp / FFmpeg / Deno / spotDL)

Las herramientas van **fijadas** (URL + SHA256) dentro de `MusicDL.bat` — no se usa `latest` a ciegas. En FFmpeg/Deno también hay `sha256exe` del binario tras extraer el ZIP.

1. Descarga la release oficial deseada.
2. Calcula el SHA256 del artefacto (`Get-FileHash -Algorithm SHA256`).
3. Si es ZIP: extrae el `.exe` y calcula también su SHA256 → `sha256exe`.
4. Actualiza `url` / `sha256` / `sha256exe` en la tabla `$herramientas` (en `src/` o el bat).
5. `.\Assemble-MusicDL.ps1` si editaste `src/`; sube `$versionApp` y firma: `.\Firmar-Version.ps1`.
6. Publica `MusicDL.bat` + `MusicDL.bat.sig`.

---

## Desarrollo / tests

El código editable por regiones está en `src/` (ensamblado a `MusicDL.bat` para distribución):

```powershell
.\Sync-ClavePublica.ps1          # clave-publica.xml -> embeddings CMD/PS
.\Assemble-MusicDL.ps1 -Split    # bat -> src/ (resync)
.\Assemble-MusicDL.ps1           # src/ -> MusicDL.bat
.\Assemble-MusicDL.ps1 -Check    # CI / pre-firma
.\Firmar-Version.ps1             # RSA-PSS; pide FIRMAR (o -Force)
```

```powershell
Import-Module Pester -MaximumVersion 5.99.99 -Force
Invoke-Pester -Path .\tests
```

CI: GitHub Actions (`.github/workflows/ci.yml`) comprueba `src/` ↔ bat, firma RSA y Pester 5 en Windows.

---

## Notas

- **Elegir…** solo aplica a listas de YouTube/SoundCloud. Con Spotify usa **Descargar**.
- Canciones con DRM: el programa puede preguntar si buscarlas en YouTube; puedes cambiarlo en **AJUSTES**.
- Datos locales: `%APPDATA%\MusicDL\` (si venías de la versión antigua, se migran desde `DescargarMusica`).
