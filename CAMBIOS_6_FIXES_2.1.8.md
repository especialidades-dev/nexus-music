# Nexus Music — Corrección de 6 fallos (v2.1.8+218)

> Documento de respaldo/replicación. Escrito por el agente HarmonyOS para que los
> agentes de **Android** y **Linux** apliquen los mismos cambios.
>
> Fecha: 2026-10-09
> Repo canónico: `nexus-music-full` (aquí se edita y se commitea; el push a GitHub lo hace otro agente).
> Versión: **2.1.8+218** (NO cambiar). HAP final: `nexusmusic-2.1.8+218-harmonyos.hap`.

---

## 0. Resumen ejecutivo

Se corrigieron 6 fallos. La mayoría de los arreglos viven en `lib/` (Flutter puro,
se comparten entre las 3 plataformas) y dos son nativos OHOS (`ohos/`).

| # | Fallo | Archivos clave | ¿Aplica a Android/Linux? |
|---|-------|----------------|--------------------------|
| 1 | La reproducción se detiene y hay que reanudarla | `AudioBridge.ets`, `harmonyos_audio_service.dart` | Sí (revisar `audio_handler.dart`) |
| 2 | El teléfono no permite rotar la pantalla | `ohos/entry/src/main/module.json5` | Sí (AndroidManifest) |
| 3 | "Me gusta" guarda pero no reproduce / no persiste | `media_Item_builder.dart`, `audio_handler.dart` | **Sí, obligatorio** |
| 4 | Apariencia según liquid-glass | `lib/ui/utils/liquid_glass.dart` + 5 archivos UI | Sí (Flutter puro) |
| 5 | Logo antiguo al iniciar | iconos OHOS desde `assets/icons/icon.png` | Sí (iconos Android/Linux) |
| 6 | "GitHub" en Ajustes no abre el repo | `open_url.dart`, `UrlBridge.ets`, `PluginRegistrant.ets` | Sí (usa fallback `url_launcher`) |

---

## 1. Punto 1 — La reproducción se detiene y hay que reanudar manualmente

**Síntoma:** el audio se corta tras un tiempo indeterminado y el usuario debe pulsar play otra vez.

**Causa:** el `AVPlayer` nativo podía quedar en estado de *stall* o error (caída de red,
URL de stream caducada) sin notificar a Dart, dejando el reproductor parado en silencio.

**Solución OHOS:**
- `ohos/entry/src/main/ets/plugin/AudioBridge.ets`
  - Interfaz `PlaybackError { code; message }` (ArkTS no admite tipos de objeto literales).
  - Guarda `lastError` en `player.on('error')` y notifica `onPlaybackError`.
  - **Watchdog de stall de 30 s**: `startStallWatchdog()` / `clearStallWatchdog()`; si no
    llega `onPositionChanged` en 30 s estando en `playing`, emite `STALL_TIMEOUT`.
- `lib/services/harmonyos_audio_service.dart`
  - `_handlePlaybackError()`: reintenta la canción con URL fresca → `skipToNext()` → tras
    3 fallos consecutivos para y notifica al usuario (`notifyPlayError`).
  - Resetea `_consecutivePlaybackErrors` al reproducir y al completar.
  - Valida que el fichero local descargado exista; si no, pide el stream online.

**Replicar en Android/Linux:** en `lib/services/audio_handler.dart` (just_audio) verificar
que un fallo de stream se recupere (retry / skip) y que `checkNGetUrl` no devuelva la ruta
de un fichero descargado inexistente.

**Verificación en dispositivo:** `AudioRenderer` del sistema activo con `clientUID 20020222`
(UID real de la app) y `rendererState: 2` (RUNNING); sin errores AVPlayer/NET_ERR/stall
durante ~40 s.

---

## 2. Punto 2 — El teléfono no permite rotar la pantalla

**Solución OHOS:** en `ohos/entry/src/main/module.json5`, dentro del ability `EntryAbility`:

```json5
"orientation": "auto_rotation",
```

**Replicar en Android:** en `android/app/src/main/AndroidManifest.xml`, la `MainActivity`
NO debe forzar orientación. Si tiene `android:screenOrientation="portrait"`, cambiarla a
`fullSensor` (o quitarla para heredar `unspecified`).

**Verificación:** el usuario confirmó que la pantalla rota al girar el teléfono.

---

## 3. Punto 3 — "Me gusta" marca y agrega al listado, pero luego no reproduce ni queda guardado

**Causa raíz (confirmada al inspeccionar `libfav.hive` en el dispositivo):**
`MediaItemBuilder.toJson` guardaba `mediaItem.artUri` **null** como la cadena literal
`"null"` dentro de `thumbnails`. Al recargar, `fromJson` hacía
`Thumbnail(json["thumbnails"][0]['url'])` → `Uri.parse("null")`, lo que lanzaba una
excepción y **rompía toda la lista de favoritos** (por eso el favorito "desaparecía" y no
se podía reproducir).

**Solución (compartida, Android/Linux también):**
- `lib/models/media_Item_builder.dart`
  - `fromJson` defensivo: `artists` solo si es `List`; `album` solo si es `Map`;
    `thumbnails` solo si es `List` no vacía y `raw != 'null'`; `id`/`title` con fallback;
    `artUri` puede quedar `null`; `duration` solo si es `int`.
  - `toDuration` envuelto en `try/catch` y guarda de cadena vacía.
  - `toJson` escribe `thumbnails` **solo si hay `artUri`**, y usa `extras?` null-safe.
- `lib/services/audio_handler.dart` → `MediaLibrary.getLibSongs()`: bucle con `try/catch`
  que **omite una entrada corrupta** en lugar de reventar toda la lista
  (log `getLibSongs[... skipped bad entry`).

Nota: la caja Hive es `LIBFAV` (clave = `videoId`, valor = JSON del `MediaItem`), 100 % local.
`autoDownloadFavoriteSongEnabled` es `false` por defecto (no afecta a la reproducción del stream).

**Verificación en dispositivo:** al dar "me gusta", `libfav.hive` creció (20.734 → 24.022 B);
la pantalla Biblioteca → Favoritos cargó **15 canciones** (incluida la recién marcada) y
"Bailas?" reprodujo con `AudioRenderer` activo y `clientUID 20020222`.

---

## 4. Punto 4 — Cambiar apariencia según liquid-glass

**Referencia:** https://github.com/nikdelvin/liquid-glass (efecto "iOS 26 Liquid Glass" web).
No se porta el CSS/SVG; se **adaptó como glassmorphism Flutter**.

**Nuevo archivo `lib/ui/utils/liquid_glass.dart`:**
- `LiquidGlass`: panel translúcido con `BackdropFilter` (blur), gradiente blanco suave,
  borde claro y sombra. Parámetros: `blur` (por defecto 22), `radius`, `tint`, `bordered`, etc.
- `LiquidGlassBackground`: fondo tipo *mesh-gradient* con blobs de color difuminados
  (`MaskFilter.blur`) derivados del color primario del tema + viñeta.
- `GlassSpecular`: brillo especular opcional (barrido cónico).

**Aplicado en:**
- `lib/ui/home.dart`: `Stack` con `Positioned.fill(child: LiquidGlassBackground())` detrás y
  `Scaffold(backgroundColor: Colors.transparent)`; `SlidingUpPanel(color: Colors.transparent)`.
- `lib/ui/utils/theme_controller.dart`: `scaffoldBackgroundColor` translúcido en los 3 temas
  (dynamic `0.35`, dark `0.42`, light `0.25`); `bottomSheetTheme` semitransparente.
- `lib/ui/widgets/bottom_nav_bar.dart`: `NavigationBar` envuelto en `LiquidGlass` con
  `backgroundColor: Colors.transparent`.
- `lib/ui/player/components/mini_player.dart`: `Container` → `LiquidGlass`.
- `lib/ui/player/components/standard_player.dart`: `PlayerControlWidget` envuelto en
  `LiquidGlass` (portrait y landscape).

**Replicar en Android/Linux:** es Flutter puro; se hereda al usar el mismo `lib/`.

**Verificación:** el usuario confirmó "se ve bien, vale así".

---

## 5. Punto 5 — Al iniciar se muestra el logo antiguo

**Causa:** los iconos OHOS apuntaban a un asset viejo.

**Logo actual:** `assets/icons/icon.png` (pak-choi), 512×512,
md5 `e2d0bd1f8af92830221e2c3f6dbdf420`.

**Solución OHOS:** copiar ese PNG a:
- `ohos/AppScope/resources/base/media/app_icon.png`
- `ohos/entry/src/main/resources/base/media/icon.png`

**Replicar en Android:** regenerar `android/app/src/main/res/mipmap-*/ic_launcher*.png`
a partir de `assets/icons/icon.png`. **Linux:** actualizar el icono del paquete `.deb`/`.desktop`.

**Verificación:** el usuario confirmó que el logo de inicio es el nuevo (pak-choi).

---

## 6. Punto 6 — En Ajustes → Información de aplicación, "GitHub" no abre el repo

**Causa OHOS:** `url_launcher` no tiene implementación para OHOS.

**Solución:**
- Nuevo `lib/utils/open_url.dart` → `Future<bool> openExternalUrl(String url)`:
  - En HarmonyOS usa el `MethodChannel('nexus_music/url')` con método `openUrl`.
  - En el resto de plataformas cae a `url_launcher` (`LaunchMode.externalApplication`).
  - `_isHarmonyOS` se resuelve localmente (todos los `GetPlatform.*` son `false` en OHOS)
    para no arrastrar `harmonyos_audio_service.dart` a Android/Linux.
- Nuevo nativo `ohos/entry/src/main/ets/plugin/UrlBridge.ets`: `openUrl` con un `Want`
  (`action: 'ohos.want.action.viewData'`, `entities: ['entity.system.browsable']`,
  `uri: url`) vía `startAbility`. Import por defecto: `import Want from '@ohos.app.ability.Want'`.
- `ohos/entry/src/main/ets/plugin/PluginRegistrant.ets`: registra el canal `nexus_music/url`
  (`registerUrlService`).
- Aplicado en `lib/ui/screens/Settings/settings_screen.dart` (2 usos) y
  `lib/ui/widgets/new_version_dialog.dart`.

**Replicar en Android/Linux:** usan el fallback `url_launcher`; no requieren código nativo.

**Verificación en dispositivo:** log `NexusMusic openUrl ok: https://github.com/especialidades-dev/nexus-music`
y el navegador del sistema (`com.huawei.hmos.browser/MainAbility`) pasó a primer plano.

---

## 7. Lista de archivos modificados / nuevos

Modificados (`git diff --stat`):
```
lib/models/media_Item_builder.dart
lib/services/audio_handler.dart
lib/services/harmonyos_audio_service.dart
lib/ui/home.dart
lib/ui/player/components/mini_player.dart
lib/ui/player/components/standard_player.dart
lib/ui/screens/Settings/settings_screen.dart
lib/ui/utils/theme_controller.dart
lib/ui/widgets/bottom_nav_bar.dart
lib/ui/widgets/new_version_dialog.dart
ohos/AppScope/resources/base/media/app_icon.png      (bin)
ohos/entry/src/main/ets/plugin/AudioBridge.ets
ohos/entry/src/main/ets/plugin/PluginRegistrant.ets
ohos/entry/src/main/module.json5
ohos/entry/src/main/resources/base/media/icon.png    (bin)
pubspec.lock
```

Nuevos (untracked):
```
lib/ui/utils/liquid_glass.dart
lib/utils/open_url.dart
ohos/entry/src/main/ets/plugin/UrlBridge.ets
```

---

## 8. Build / firma / instalación HarmonyOS (flujo que funciona)

```bash
export PATH="/home/lex/ohos-sdk/flutter_ohos/bin:$HOME/.pub-cache/bin:$PATH"
export FLUTTER_ROOT=/home/lex/ohos-sdk/flutter_ohos
cd /home/lex/Documentos/App_harmony/NexusMusic/nexus-music-full

# 1) Compilar (signing desactivado; se firma aparte)
flutter build hap --debug --no-codesign --target-platform ohos-arm64
# salida: build/ohos/hap/entry-default-unsigned.hap

# 2) Firmar manual con hap-sign-tool (auto-sign falla)
SIGNTOOL=/home/lex/ohos-sdk/commandline-tools/command-line-tools/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar
PWD32="12345678901234567890123456789012"
java -jar "$SIGNTOOL" sign-app -mode localSign -keyAlias "nexus-debug-key" -keyPwd "$PWD32" \
  -appCertFile ohos/signing/material/debug.cer -profileFile ohos/signing/material/debug.p7b \
  -inFile build/ohos/hap/entry-default-unsigned.hap \
  -signAlg "SHA256withECDSA" -keystoreFile ohos/signing/material/debug.p12 -keystorePwd "$PWD32" \
  -outFile "build/ohos/hap/nexusmusic-2.1.8+218-harmonyos.hap" \
  -compatibleVersion 12 -signCode "1"

# 3) Instalar
HDC=/home/lex/Documentos/App_harmony/command-line-tools/toolchains/hdc
"$HDC" install "build/ohos/hap/nexusmusic-2.1.8+218-harmonyos.hap"
"$HDC" shell "aa force-stop io.github.nexusmusic.app"
"$HDC" shell "aa start -a EntryAbility -b io.github.nexusmusic.app"
```

`ohos/signing/material/` (firma manual): `debug.cer`, `debug.p12`, `debug.p7b`.

---

## 9. Notas de verificación útiles (HarmonyOS)

- Dispositivo: `7FX0226302000943`. Bundle: `io.github.nexusmusic.app`. Ability: `EntryAbility`.
  UID de la app: `20020222`.
- Audio activo: `hdc shell "hidumper -s AudioPolicyService -a '-s'"` → buscar `clientUID 20020222`
  y `rendererState: 2`.
- Sesión: `hidumper -s AVSessionService -a '-show_session_info'` / `-show_metadata`.
- UI automatizable: `hdc shell "uitest dumpLayout -p /data/local/tmp/x.json"` + `hdc file recv`;
  tocar con `uitest uiInput click X Y`; capturas con `snapshot_display -f <ruta> -t jpeg`.
- Datos de la app (Hive, legibles): `/data/app/el2/100/base/io.github.nexusmusic.app/haps/entry/files/flutter/`
  (`libfav.hive`, `librp.hive`, `appprefs.hive`, etc.).
- En este build los `print` de Dart **no** salen en `hilog`; sí salen los `console.*` nativos
  (`A03D00/io.github.nexusmusic.app/JSAPP: NexusMusic ...`).
- `nexus-music-full` no tiene proyecto Flutter-OHOS propio: los ficheros nativos se **espejan**
  a `NexusMusicHarmonyOs/ohos/` (mantener sincronizados Audio/Url/PluginRegistrant/module.json5/iconos).

---

## 10. Nueva funcionalidad — Carpeta de descargas + reproducción local (v2.1.8)

### Qué aporta
1. **Selección de carpeta del teléfono** (Ajustes → Descargar → "Ubicación de la descarga").
   - Antes: `file_picker`/`permission_handler` no tienen implementación OHOS
     (`GeneratedPluginRegistrant` vacío), el selector hacía `MissingPluginException` silencioso.
   - Ahora: puente nativo `FileBridge` (`nexus_music/filepicker`) que abre el
     `DocumentViewPicker` del sistema en modo **FOLDER** (sin permisos especiales).
2. **Descarga de favoritas a esa carpeta**:
   - Botón "Descargar todas las canciones favoritas" nuevo en Ajustes → Descargar
     (además del icono de descarga que ya existía en la pantalla de la playlist Favoritos).
3. **Reproducción desde el fichero descargado (sin streaming)**:
   - Script default: carpeta privada `files/Music` (se verifica existencia real).
   - Carpeta elegida: la app descarga a un temporal del sandbox y lo **importa** a la
     carpeta elegida vía `importFile` nativo; guarda el URI del fichero y reproduce con
     AVPlayer a través de `fd://` (abierto con `fs.openSync(uri)`). Si el fichero no
     existe, sólo entonces cae a stream online.

### Archivos
- `ohos/entry/src/main/ets/plugin/FileBridge.ets` (nuevo): `pickFolder`, `ensureAccess`,
  `importFile`, `fileExists`, `removeFile`; `persistPermission` best-effort.
- `ohos/entry/src/main/ets/plugin/PluginRegistrant.ets`: registra `registerFileService`.
- `ohos/entry/src/main/ets/plugin/AudioBridge.ets`: reproduce URIs `file://docs`/`content://`
  abriendo `fd://` (cierra el fd en `release`).
- `lib/utils/folder_picker.dart` (nuevo): helper Dart `pickDownloadFolder()` (OHOS nativo,
  resto de plataformas sigue `file_picker`), `folderAccessible`, `importFileIntoFolder`,
  `downloadedFileExists`, `deleteDownloadedFile`.
- `lib/ui/screens/Settings/settings_screen_controller.dart`: `setDownloadLocation()` usa el
  selector nativo en OHOS; nuevos campos `downloadLocationDisplay/IsExternal/Persisted`;
  `resetDownloadLocation()`; validación de acceso en init.
- `lib/ui/screens/Settings/settings_screen.dart`: subtítulo muestra la carpeta elegida y
  nuevo tile "Descargar todas las canciones favoritas".
- `lib/services/downloader.dart`: descarga externa = temporal en sandbox → `importFileIntoFolder`
  → URI final; si la carpeta no es accesible, mantiene el fichero en el sandbox (`Music`).
- `lib/services/harmonyos_audio_service.dart`: `checkNGetUrl` comprueba URIs de carpeta con
  `downloadedFileExists`; si falta, stream online.
- `lib/utils/get_localization.dart`: claves `downloadAllFavorites` (en/es).
- Espejo `NexusMusicHarmonyOs/ohos/` sincronizado (FileBridge/AudioBridge/PluginRegistrant).

### Límites conocidos
- `ohos.permission.FILE_ACCESS_PERSIST` es `system_basic`/ACL y el perfil debug actual tiene
  `allowed-acls: []`, así que la persistencia entre reinicios es best-effort: si el sistema
  revoca el acceso a la carpeta, al arrancar la app se relega a la carpeta interna y se deberá
  re-elegir la carpeta. La descarga en sesión funciona sin persistir.
- Si `importFile` falla (permiso revocado), la canción se guarda igual en `files/Music`
  (privada) para no perder la reproducción offline.
