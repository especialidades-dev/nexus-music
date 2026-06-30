# Nexus Music 🎵

> Fork de [Harmony-Music](https://github.com/anandnet/Harmony-Music) con soporte para **Linux Debian** y **Harmony OS 6.1.x**

Aplicación multiplataforma para streaming de música construida con Flutter.

## Características

- Reproducción desde YouTube / YouTube Music
- Caché de canciones durante reproducción
- Modo Radio (reproducción infinita basada en canción seleccionada)
- Reproducción en segundo plano
- Creación de playlists y favoritos
- Favoritos de artistas y álbumes
- Importar canciones, playlists, álbumes desde YouTube Music
- Control de calidad de streaming
- Descarga de canciones
- Soporte multi-idioma
- Skip silence
- Tema dinámico
- Navegación inferior o lateral
- Ecualizador
- Letras sincronizadas y planas
- Temporizador de sueño
- Sin anuncios
- Sin login requerido

## Plataformas soportadas

| Plataforma | Estado |
|-----------|--------|
| Linux (Debian/Ubuntu) | ✅ |
| Harmony OS 6.1.x | ✅ (Flutter OHOS port) |
| Windows | Mantenido del upstream |
| Android | Mantenido del upstream |

## Compilación

### Linux (Debian)

```bash
sudo apt-get install libmpv-dev mpv libayatana-appindicator3-dev ninja-build libgtk-3-dev
dart pub global activate flutter_distributor
flutter_distributor package --platform linux --targets deb
```

### Harmony OS 6.1.x

```bash
# Usar Flutter SDK con soporte OHOS
flutter config --enable-ohos
flutter build hap --debug --target-platform ohos-arm64
```

## Créditos

- [anandnet/Harmony-Music](https://github.com/anandnet/Harmony-Music) - Proyecto original
- OpenHarmony Flutter SIG - Port de Flutter para OpenHarmony
