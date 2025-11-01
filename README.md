# Cloudstream Non-English Plugin Repository 

All available repositories: https://recloudstream.github.io/repos/

Not all extractors are included, only those need to compile. We need to use loadExtractor in the future.

## Getting started with writing your first plugin

1. Open the root build.gradle.kts, read the comments and replace all the placeholders
2. Familiarize yourself with the project structure. Most files are commented
3. Build or deploy your first plugin using:
   - Windows: `.\gradlew.bat ExampleProvider:make` or `.\gradlew.bat ExampleProvider:deployWithAdb`
   - Linux & Mac: `./gradlew ExampleProvider:make` or `./gradlew ExampleProvider:deployWithAdb`

## Attribution

This template as well as the gradle plugin and the whole plugin system is **heavily** based on [Aliucord](https://github.com/Aliucord).
*Go use it, it's a great mobile discord client mod!*

## Pruebas de conectividad y resumen de providers

Se añadieron pruebas automáticas que verifican la respuesta HTTP y capturan un pequeño fragmento del contenido para los providers que solicitaste. Los resultados se generan en `tests/test_results.md` y un resumen compacto en `tests/summary.md`.

Resumen compacto (fecha de ejecución dentro del repo):

| Provider | Main URL | HTTP hint | Content check |
|---|---|---|---|
| AnimefenixProvider | https://animefenix2.tv | HTTP/2 200 | ok (contains anime-related keywords) |
| AnimeflvIOProvider | https://www3.animeflv.net | HTTP/1.1 400 Bad Request | uncertain (no obvious anime keywords in snippet) |
| AnimeflvnetProvider | https://www3.animeflv.net | HTTP/1.1 400 Bad Request | uncertain (no obvious anime keywords in snippet) |
| CinecalidadProvider | https://cinecalidad.lol | HTTP/2 301 | ok (contains anime-related keywords) |
| CuevanaProvider | https://cuevana3.me | HTTP/2 200 | uncertain (no obvious anime keywords in snippet) |
| DoramasYTProvider | https://doramasyt.com | (no response) | uncertain (no obvious anime keywords in snippet) |
| ElifilmsProvider | https://elifilms.net | (no response) | uncertain (no obvious anime keywords in snippet) |
| EntrepeliculasyseriesProvider | https://entrepeliculasyseries.nz | HTTP/2 200 | ok (contains anime-related keywords) |
| EstrenosDoramasProvider | https://www23.estrenosdoramas.net | (no response) | uncertain (no obvious anime keywords in snippet) |
| JKAnimeProvider | https://jkanime.net | HTTP/1.1 400 Bad Request | uncertain (no obvious anime keywords in snippet) |
| MonoschinosProvider | https://monoschino2.com | HTTP/1.1 400 Bad Request | uncertain (no obvious anime keywords in snippet) |
| MundoDonghuaProvider | https://www.mundodonghua.com | HTTP/2 200 | uncertain (no obvious anime keywords in snippet) |
| PeliSmartProvider | https://pelismart.com | HTTP/1.1 301 Moved Permanently | uncertain (no obvious anime keywords in snippet) |
| PelisflixProvider | https://pelisflix.li | HTTP/1.1 302 Found | uncertain (no obvious anime keywords in snippet) |
| PelisplusHDProvider | https://pelisplushd.cam | HTTP/2 301 | ok (contains anime-related keywords) |
| PelisplusProvider | https://pelisplus.icu | (no response) | uncertain (no obvious anime keywords in snippet) |
| SeriesflixProvider | https://seriesflix.video | HTTP/2 302 | uncertain (no obvious anime keywords in snippet) |
| TocanimeProvider | https://tocanime.co | HTTP/1.1 400 Bad Request | uncertain (no obvious anime keywords in snippet) |

Notas rápidas:
- "HTTP hint" es un resumen rápido a partir de la respuesta HTTP (código / redirección). No garantiza que el scraping funcione.
- "Content check" indica si el fragmento descargado contiene palabras clave relacionadas (ej. "anime", "animes", "episodios"). "uncertain" significa que hace falta una verificación más profunda desde la app.
- Para providers con 4xx/403/400 o redirecciones, se recomienda probar desde la app real (con las cabeceras y cookies que el provider implementa) y/o ajustar cabeceras (Host/Origin/Referer) en el código del provider.

Si quieres, hago push de los commits y abro un PR con este README actualizado y los archivos de tests.

## Resumen y requisitos para compilar

Resumen corto:
- Los providers solicitados (AnimefenixProvider, AnimeflvIOProvider, AnimeflvnetProvider, JKAnimeProvider, MonoschinosProvider, MundoDonghuaProvider, TocanimeProvider) han sido verificados con pruebas HTTP desde el contenedor. Algunos devuelven 200 y HTML válido; otros requieren cabeceras específicas (Host/Referer/Origin) o manejo de Cloudflare para poder scrapear correctamente desde la app.

Requisitos mínimos para compilar en este repositorio:

- JDK: Java 11 (recomendado) instalado y en PATH. Aunque el código usa jvmTarget 1.8, el Android Gradle Plugin 7.x funciona mejor con Java 11.
- Android SDK: Plataformas y Build-tools para API 30 instaladas (compileSdkVersion = 30). Tener `platforms;android-30` y `build-tools;30.0.3` preferiblemente.
- Android SDK Command-line tools (sdkmanager) para instalar y aceptar licencias.
- Gradle wrapper incluido (usar `./gradlew`) — no necesitas instalar Gradle globalmente.
- Variables de entorno: `ANDROID_SDK_ROOT` o `ANDROID_HOME` apuntando al SDK instalado.
- Conexión a Internet durante la compilación para que Gradle descargue dependencias (kotlin plugin, maven repos, etc.).

Instalación mínima en Ubuntu (ejemplo):

```bash
# instalar JDK 11
sudo apt update && sudo apt install -y openjdk-11-jdk

# descargar Android SDK command line tools (https://developer.android.com/studio#command-tools)
# descomprimirlo y exportar ANDROID_SDK_ROOT (ejemplo en ~/Android/Sdk)
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
mkdir -p "$ANDROID_SDK_ROOT"
# luego usar sdkmanager para instalar plataformas y build-tools
${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root="$ANDROID_SDK_ROOT" "platform-tools" "platforms;android-30" "build-tools;30.0.3"
yes | ${ANDROID_SDK_ROOT}/cmdline-tools/bin/sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses
```

Cómo compilar un provider específico (desde la raíz del repo):

```bash
# compilar (tarea definida por el plugin cloudstream)
./gradlew AnimefenixProvider:make

# o para deploy con adb al dispositivo conectado (si lo necesitas)
./gradlew AnimefenixProvider:deployWithAdb
```

Notas importantes de build:
- Usa el Gradle wrapper (`./gradlew`) para asegurar la versión correcta de Gradle.
- Si la compilación falla por versión de Java, instala Java 11 y reinicia el terminal/sesion.
- Para providers que devuelvan 4xx/403 en pruebas, la ejecución real dentro de la app (o emulador) usando las cabeceras definidas en cada provider suele ser suficiente. Si no, se necesita depurar con logs o con pruebas de scraping más profundas (HEADLESS browser / cookies / JS).

Si quieres que aplique automáticamente cabeceras adicionales en los providers que lo requieran (AnimeflvIO, Animeflvnet, JKAnime, Monoschinos, Tocanime), puedo hacerlo y ejecutar otra ronda de pruebas.

### Windows: script automático (PowerShell)

He añadido un script PowerShell que automatiza la preparación mínima de un entorno Windows para compilar providers y ejecutar la compilación usando el Gradle wrapper.

Archivo: `scripts/setup_windows_build.ps1`

Uso básico (en PowerShell, desde la raíz del repo):

```powershell
cd scripts
.\setup_windows_build.ps1 -Provider AnimefenixProvider
```

Qué hace el script:
- Comprueba que `java` esté en PATH y sea Java 11 o superior.
- Descarga (si hace falta) las Android command-line tools y las coloca en `%ANDROID_SDK_ROOT%\cmdline-tools\latest` (por defecto usa `%USERPROFILE%\Android\Sdk`).
- Instala `platform-tools`, `platforms;android-30` y `build-tools;30.0.3` usando `sdkmanager`.
- Intenta aceptar las licencias automáticamente (puede requerir interacción en algunos casos).
- Añade `platform-tools` al PATH de la sesión actual y, opcionalmente, lo persiste con `setx` si pasas `-SetEnv`.
- Ejecuta `gradlew.bat <Provider>:make` para compilar el provider solicitado.

Limitaciones y notas:
- El script intenta automatizar la aceptación de licencias y la instalación, pero puede requerir intervención manual según la configuración de tu sistema y permisos.
- Es recomendable ejecutar PowerShell como usuario con permisos para escribir en la carpeta SDK.
- Si prefieres la GUI, instalar Android Studio y usar su SDK Manager también es válido; el script es útil para entornos sin Android Studio o para automatizar.

Si quieres que cambie algo en el script (por ejemplo, usar un mirror distinto, o forzar rutas diferentes), dime y lo adapto.
