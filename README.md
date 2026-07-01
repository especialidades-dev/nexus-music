# Nexus Music 🎵

> Fork de [Harmony-Music](https://github.com/anandnet/Harmony-Music) con soporte para **Linux Debian** y **Harmony OS 6.1.x** (aún en desarrollo)

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
| Harmony OS 6.1.x | ✅ (Flutter OHOS port) |(sin probar aún)
| Windows | Mantenido del upstream | (no planeado)
| Android | Mantenido del upstream | (En pruebas)

## Disclaimer
He creado este fork sólo para fines de aprendizaje, no pretendo tener ningún tipo de sponsor ni afiliación de ningún tipo. 

Todas las canciones, contenidos y marcas registradas utilizadas en esta aplicación son propiedad intelectual de sus respectivos dueños.

No me responsabilizo de ninguna infracción de derechos de autor u otros derechos de propiedad intelectual que puedan derivarse del uso de las canciones y demás contenido disponible a través de esta aplicación.

En ningún caso el autor de este software será responsable de daños especiales, consecuenciales, incidentales o indirectos de cualquier tipo (incluidas, entre otras, pérdidas económicas) derivados del uso o la imposibilidad de usar este producto, incluso si el autor conoce la posibilidad de dichos daños y defectos.

Este software se distribuye "tal cual", sin garantía ni responsabilidad alguna.

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
