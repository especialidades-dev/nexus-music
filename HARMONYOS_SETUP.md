# Nexus Music en Harmony OS 6.1.x

Guía completa para compilar e instalar Nexus Music en dispositivos Harmony OS 6.1.x.

---

## Requisitos

- PC con Linux, macOS o Windows
- Dispositivo Harmony OS 6.1.x (teléfono, tablet o 2-en-1)
- Cable USB para conexión
- DevEco Studio (IDE oficial de Huawei)
- Flutter SDK con soporte OHOS

---

## 1. Instalar DevEco Studio

1. Descargar desde: https://developer.huawei.com/consumer/cn/download/
2. Instalar y abrir DevEco Studio
3. Durante la instalación se descarga el SDK de Harmony OS
4. Anotar la ruta del SDK (ej: `C:\Users\tuuser\AppData\Local\Huawei\Sdk` en Windows)

---

## 2. Configurar Flutter OHOS SDK

```bash
# Clonar Flutter con soporte OHOS
git clone -b oh-3.22.0 https://gitee.com/openharmony-sig/flutter_flutter.git ~/flutter-ohos

# Agregar al PATH
export PATH="$HOME/flutter-ohos/bin:$PATH"

# Configurar variables de entorno del SDK de Harmony OS
# Ajusta la ruta según tu instalación de DevEco Studio
export DEVECO_SDK_HOME="C:/Users/tuuser/AppData/Local/Huawei/Sdk"  # Windows
# export DEVECO_SDK_HOME="$HOME/Library/Huawei/Sdk"  # macOS
# export DEVECO_SDK_HOME="/home/usuario/Huawei/Sdk"  # Linux

export PATH="$DEVECO_SDK_HOME/ohpm/bin:$PATH"
export PATH="$DEVECO_SDK_HOME/hvigor/bin:$PATH"
export PATH="$DEVECO_SDK_HOME/node/bin:$PATH"

# Habilitar soporte OHOS en Flutter
flutter config --enable-ohos

# Verificar
flutter doctor -v
# Debe mostrar "OpenHarmony" como plataforma disponible
```

---

## 3. Clonar y compilar Nexus Music

```bash
git clone https://github.com/especialidades-dev/nexus-music.git
cd nexus-music

# Instalar dependencias Dart
flutter pub get

# Compilar HAP (Harmony OS App Package)
flutter build hap --debug --target-platform ohos-arm64

# El archivo .hap se genera en:
# ohos/entry/build/default/outputs/default/entry-default-signed.hap
```

> **Nota**: Para release firmado:
> 1. Abrir el proyecto en DevEco Studio
> 2. File → Project Structure → Signing Configs
> 3. Marcar "Automatically generate signature"
> 4. Luego: `flutter build hap --release --target-platform ohos-arm64`

---

## 4. Instalar en dispositivo Harmony OS

### Opción A: Con hdc (Harmony OS Debug Bridge)

```bash
# Conectar dispositivo por USB
# Activar modo desarrollador en el dispositivo:
# Ajustes → Acerca del teléfono → Tocar "Número de compilación" 7 veces
# Ajustes → Sistema y actualizaciones → Opciones de desarrollador → Depuración USB

# Verificar dispositivo conectado
hdc list targets

# Instalar el HAP
hdc install ohos/entry/build/default/outputs/default/entry-default-signed.hap

# La app aparecerá como "Nexus Music" en el dispositivo
```

### Opción B: Con DevEco Studio

1. Abrir el proyecto en DevEco Studio (abrir la carpeta `ohos/`)
2. Conectar el dispositivo por USB
3. Click en "Run" (triángulo verde)
4. Seleccionar el dispositivo Harmony OS
5. La app se compila e instala automáticamente

---

## 5. Permisos necesarios

La app solicitará automáticamente:

- **Internet** - Para streaming de música
- **Almacenamiento** - Para descargar canciones offline
- **Ejecución en segundo plano** - Para reproducción con pantalla apagada

Conceder manualmente si es necesario:
- Ajustes → Aplicaciones → Nexus Music → Permisos

---

## 6. Actualizar la app

```bash
cd nexus-music
git pull
flutter pub get
flutter build hap --release --target-platform ohos-arm64
hdc install ohos/entry/build/default/outputs/default/entry-default-signed.hap
```

El HAP reemplazará la versión anterior conservando los datos locales.

---

## Solución de problemas

| Problema | Solución |
|----------|----------|
| `hdc list targets` no muestra dispositivo | Verificar cable USB, modo desarrollador y depuración USB activados |
| Error de firma al compilar | Abrir DevEco Studio → File → Project Structure → Signing → Auto-generar |
| `flutter build hap` falla por SDK | Verificar `flutter doctor -v` y variables de entorno |
| La app no reproduce audio | Verificar permisos de Internet y ejecución en segundo plano |
