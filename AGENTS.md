# Nexus Music - Project Knowledge Base

## Build Commands

### Linux Debian
```bash
# Install deps
sudo apt-get install libmpv-dev mpv libayatana-appindicator3-dev ninja-build libgtk-3-dev
# Build
dart pub global activate flutter_distributor
flutter_distributor package --platform linux --targets deb
```

### Harmony OS 6.1.x
```bash
# Use OHOS-enabled Flutter SDK
# git clone -b 3.22.0-ohos https://gitcode.com/openharmony-sig/flutter_flutter.git
flutter config --enable-ohos
flutter build hap --debug --target-platform ohos-arm64
```

## Architecture

- **Linux**: `just_audio` + `just_audio_media_kit` + `media_kit` (mpv backend)
- **Harmony OS**: Custom `HarmonyOSAudioHandler` via MethodChannel -> native AVPlayer
- **State Management**: GetX
- **Local DB**: Hive
- **Music Source**: YouTube Music API via `youtube_explode_dart` + `music_service.dart`

## Key Files

| File | Purpose |
|------|---------|
| `lib/services/audio_handler.dart` | Linux/Android audio handler (just_audio) |
| `lib/services/harmonyos_audio_service.dart` | Harmony OS audio handler (MethodChannel) |
| `lib/main.dart` | Entry point for Linux/Android |
| `lib/main_harmonyos.dart` | Entry point for Harmony OS |
| `ohos/entry/src/main/ets/plugin/AudioBridge.ets` | Native AVPlayer bridge |
| `ohos/entry/src/main/ets/plugin/PluginRegistrant.ets` | Flutter plugin registration |

## Platform Detection
- `MyAudioHandler.isHarmonyOS` in audio_handler.dart
- Runtime check: all `GetPlatform.*` return false on Harmony OS
