# Nexus Music Linux - Learning Document

## Sesión: Implementación streaming InnerTube en Linux (2026-08-20)

---

### Contexto
- Proyecto: Nexus Music (fork de Harmony Music)
- Objetivo: Linux production build con streaming robusto
- Directorio de trabajo: `/home/lex/Documentos/App_harmony/NexusMusic/NexusMusiLinux/`
- Fuente consultada: `nexus-music-full/`, `NexusMusixAndroid/` (solo lectura)

---

### Problemas resueltos

#### 1. Versión hardcodeada en Ajustes
- **Archivo**: `lib/ui/screens/Settings/settings_screen_controller.dart:50`
- **Problema**: `final currentVersion = "V2.1.7"` mostraba versión vieja tras bump
- **Fix**: Cambiado a `V2.1.8` y bump build +218, +219, +220, +221, +222

#### 2. Pantalla gris (crash al arranque)
- **Archivo**: `lib/main.dart:91`
- **Causa**: `Get.put(() => MusicServices(), permanent: true)` — incorrecto (`Get.put` recibe instancia, no builder)
- **Fix**: Revertido a `Get.lazyPut(() => MusicServices(), fenix: true)` igual que Android

#### 3. "Página necesita refrescarse" / streaming fallido
- **Causa**: InnerTube sin `visitorData` → URLs gated (403)
- **Análisis Android**: `NexusMusixAndroid/lib/services/stream_service.dart`
  - InnerTube primero (`isHarmonyOS || isAndroid`)
  - Fallback a YoutubeExplode si falla
  - `fetchAudioFromInnerTube` con fallback `combinedFormats`
- **Implementación Linux**:
  - Copiada implementación Android completa
  - Habilitado InnerTube también para Linux: `isHarmonyOS || GetPlatform.isAndroid || GetPlatform.isLinux`
  - `visitorData` desde Hive box `AppPrefs['visitorId']` (generado en `MusicServices.onInit`)
  - Fallback YoutubeExplode automático si InnerTube no playable

#### 4. `visitorId` no generado a tiempo
- **Problema**: `MusicServices` era `lazyPut` → `onInit()` (genera visitorId) solo al primer acceso
- **Solución**: Mantener `lazyPut` pero InnerTube ahora se llama al reproducir (ya se navegó → home cargada → `MusicServices` inicializado)

---

### Archivos modificados en NexusMusiLinux

| `ohos/entry/src/main/ets/plugin/FileBridge.ets` | Puente nativo OHOS: selección de carpeta (DocumentViewPicker), importFile, fileExists, ensureAccess. |
| `ohos/entry/src/main/ets/plugin/AudioBridge.ets` | Reproducción vía fd:// para URIs externos; fix cálculo isSameTrack ANTES de actualizar lastUrl. |
| `ohos/entry/src/main/module.json5` | Añadido `ohos.permission.FILE_ACCESS_PERSIST` (best-effort). |
| `lib/utils/folder_picker.dart` | Wrapper Dart para carpeta de descargas (OHOS nativo + fallback). |
| `lib/services/downloader.dart` | Descarga a carpeta externa (importa vía puente nativo), fallback a sandbox. |
| `lib/services/harmonyos_audio_service.dart` | Prioriza archivo local (sandbox o carpeta externa) sobre streaming. |
| `lib/ui/screens/Settings/settings_screen*.dart` | UI para ubicación de descargas + tile "Descargar todas las canciones favoritas". |
| `lib/utils/get_localization.dart` | Claves `downloadAllFavorites`. |

---

### Estado actual (v2.1.9+219)
- **OHOS**: Selector de carpeta funciona (sin forzar persistPermission en rutas restringidas). Descargas se importan a carpeta elegida. Reproducción prioriza local. Fix pausa+cambio de pista verificado.
- **HAP firmado**: `NexusMusicHarmonyOs/versiones_hap/nexusmusic-2.1.9+219-harmonyos.hap`
- **Commits**: `bcbab4c` feat(descargas + reproducción local + fix AudioBridge), `88c4194` chore(bump 2.1.9+219)

---

### Build commands
```bash
# Deps
sudo apt-get install libmpv-dev mpv libayatana-appindicator3-dev ninja-build libgtk-3-dev

# Build
export PATH="/home/lex/flutter/bin:$HOME/.pub-cache/bin:$PATH"
export FLUTTER_ROOT=/home/lex/flutter
flutter pub get
echo "const updateCheckFlag = true;" > lib/utils/update_check_flag_file.dart
dart pub global activate flutter_distributor
flutter_distributor package --platform linux --targets deb
```

---

### Versiones generadas

| Build | Versión | Cambio clave |
|-------|---------|--------------|
| +218 | 2.1.9+218 | Descargas a carpeta externa + reproducción local (OHOS) + fix cambio pista pausado |
| +219 | 2.1.9+219 | Bump versión para sincronizar agentes |

---

---

### Artefacto actual (HAP OHOS)
- **HAP firmado**: `/home/lex/Documentos/App_harmony/NexusMusic/NexusMusicHarmonyOs/versiones_hap/nexusmusic-2.1.9+219-harmonyos.hap`
- **Código fuente base**: `nexus-music-full` (commit: bcbab4c + 88c4194)

---

### Próximos pasos (pendientes)
- Sincronizar implementación con Android/Linux siguiendo la misma lógica (carpeta elegida + prioridad local)
- Push de los cambios en `nexus-music-full` (otro agente se encarga)