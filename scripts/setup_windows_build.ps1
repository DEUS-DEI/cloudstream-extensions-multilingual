<#
PowerShell helper to prepare a Windows machine for building providers in this repo.
Usage (PowerShell as user):
  cd <repo-root>\scripts
  .\setup_windows_build.ps1 -Provider AnimefenixProvider

This script will:
 - Check Java version (requires Java 11+)
 - Ensure an Android SDK root exists (default: %USERPROFILE%\Android\Sdk)
 - Download Android command-line tools if missing
 - Install platform-tools, platforms;android-30 and build-tools;30.0.3
 - Attempt to accept licenses (interactive may be required)
 - Add platform-tools to PATH for the current session
 - Run the Gradle wrapper to build the chosen provider

Notes:
 - Run PowerShell with enough privileges to write into the chosen SDK folder.
 - The script tries to automate license acceptance but may prompt you.
 - If you prefer GUI, install Android Studio and use SDK Manager there.
#>
param(
    [string]$Provider = "AnimefenixProvider",
    [switch]$SetEnv # if provided, will persist ANDROID_SDK_ROOT and PATH via setx (user scope)
)

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m) { Write-Host "[ERROR] $m" -ForegroundColor Red }

# Check Java
Write-Info "Comprobando Java..."
$java = Get-Command java -ErrorAction SilentlyContinue
if (-not $java) {
    Write-Err "No se encontró 'java' en PATH. Instala JDK 11 (Adoptium / Temurin) y configura JAVA_HOME."
    exit 1
}

$verOut = & java -version 2>&1
# java -version typically prints like: openjdk version "11.0.x" 202x-xx-xx
if ($verOut -match 'version "([0-9]+)') {
    $major = [int]$Matches[1]
    if ($major -lt 11) {
        Write-Err "Java versión detectada menor a 11: $major. Instala JDK 11 o superior."
        exit 1
    } else {
        Write-Info "Java OK (versión >= 11 detected)."
    }
} else {
    Write-Warn "No se pudo parsear la versión de Java, salida: $verOut"
}

# Determine SDK root
if ($env:ANDROID_SDK_ROOT) { $SdkRoot = $env:ANDROID_SDK_ROOT } else { $SdkRoot = Join-Path $env:USERPROFILE 'Android\Sdk' }
Write-Info "Usando ANDROID_SDK_ROOT = $SdkRoot"

# Ensure directories
if (-not (Test-Path $SdkRoot)) {
    Write-Info "Creando carpeta SDK: $SdkRoot"
    New-Item -ItemType Directory -Path $SdkRoot -Force | Out-Null
}

# Cmdline tools path
$cmdlineRoot = Join-Path $SdkRoot 'cmdline-tools\latest'
$cmdlineBin = Join-Path $cmdlineRoot 'bin\sdkmanager.bat'

if (-not (Test-Path $cmdlineBin)) {
    Write-Info "command-line tools no encontrado. Descargando..."
    $tmpZip = Join-Path $env:TEMP 'commandlinetools-win-latest.zip'
    $downloadUrl = 'https://dl.google.com/android/repository/commandlinetools-win-latest.zip'
    Write-Info "Descargando $downloadUrl -> $tmpZip"
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpZip -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Err "Fallo al descargar las command-line tools: $_.Exception.Message"
        exit 1
    }
    # Extract to temporary folder and move to cmdlineRoot
    $extractTmp = Join-Path $env:TEMP 'android_cmdline_tmp'
    if (Test-Path $extractTmp) { Remove-Item $extractTmp -Recurse -Force }
    Expand-Archive -Path $tmpZip -DestinationPath $extractTmp
    # The zip contains a 'cmdline-tools' folder; move its contents to $cmdlineRoot
    $src = Join-Path $extractTmp 'cmdline-tools'
    if (-not (Test-Path $src)) { $src = $extractTmp }
    try {
        New-Item -ItemType Directory -Path $cmdlineRoot -Force | Out-Null
        # copy contents
        Get-ChildItem -Path $src | ForEach-Object { Copy-Item -Path $_.FullName -Destination $cmdlineRoot -Recurse -Force }
        Write-Info "Command-line tools instaladas en $cmdlineRoot"
    } catch {
        Write-Err "Fallo al extraer/instalar command-line tools: $_.Exception.Message"
        exit 1
    }
} else {
    Write-Info "command-line tools ya presente: $cmdlineBin"
}

# sdkmanager path
$sdkmanager = $cmdlineBin
if (-not (Test-Path $sdkmanager)) {
    Write-Err "No se encontró sdkmanager en $sdkmanager"
    exit 1
}

# Install components: platform-tools, platforms;android-30, build-tools;30.0.3
$toInstall = @( 'platform-tools', 'platforms;android-30', 'build-tools;30.0.3' )
Write-Info "Instalando: $($toInstall -join ', ')"
# Run sdkmanager
$installCmd = @($sdkmanager, '--sdk_root=' + $SdkRoot) + $toInstall
try {
    # Many sdks require interactive license acceptance. We'll try to pipe many 'y' answers.
    $yStream = for ($i=0; $i -lt 50; $i++) { 'y' }
    $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', ($installCmd -join ' ')) -NoNewWindow -PassThru -RedirectStandardInput 'PIPE' -RedirectStandardOutput 'PIPE' -RedirectStandardError 'PIPE'
    foreach ($line in $yStream) { $proc.StandardInput.WriteLine($line) }
    $proc.StandardInput.Close()
    $out = $proc.StandardOutput.ReadToEnd()
    $err = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    Write-Info "sdkmanager output (truncado):"; Write-Host $out.Substring(0,[Math]::Min($out.Length,200))
    if ($proc.ExitCode -ne 0) { Write-Warn "sdkmanager exit code $($proc.ExitCode). Revisa la salida completa en consola." }
} catch {
    Write-Warn "Fallo automatizado sdkmanager: $_. Exception.Message. Ejecuta manualmente: $sdkmanager --sdk_root=$SdkRoot ${toInstall -join ' '}"
}

# Ensure platform-tools in PATH for session
$pt = Join-Path $SdkRoot 'platform-tools'
if (Test-Path $pt) {
    if (-not ($env:Path -split ';' | Where-Object { $_ -eq $pt })) {
        $env:Path = "$pt;$env:Path"
        Write-Info "Añadido $pt a PATH (sesión actual)."
        if ($SetEnv) {
            Write-Info "Persistiendo PATH y ANDROID_SDK_ROOT usando setx (user)."
            setx ANDROID_SDK_ROOT "$SdkRoot" | Out-Null
            # Append platform-tools to PATH permanently (read current user PATH then add)
            $curr = [Environment]::GetEnvironmentVariable('PATH', 'User')
            if ($curr -notlike "*${pt}*") {
                setx PATH ("$curr;$pt") | Out-Null
            }
            Write-Info "Variables persistidas. Cierra y vuelve a abrir PowerShell para que surtan efecto."
        }
    } else { Write-Info "$pt ya en PATH" }
} else {
    Write-Warn "platform-tools no encontrado en $pt. Asegúrate de que sdkmanager instaló platform-tools correctamente."
}

# Run gradle wrapper to build provider
# Determine repo root (one level above scripts)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$gradlew = Join-Path $repoRoot 'gradlew.bat'
if (-not (Test-Path $gradlew)) {
    Write-Err "No se encontró gradlew.bat en $repoRoot. Ejecuta desde la carpeta del repo."
    exit 1
}

Write-Info "Iniciando compilación de $Provider usando Gradle wrapper..."
Push-Location $repoRoot
try {
    & $gradlew "$Provider:make"
} catch {
    Write-Err "Gradle falló: $_.Exception.Message"
    Pop-Location
    exit 1
}
Pop-Location

Write-Info "Script finalizado. Si hubo errores en sdkmanager o Gradle, revisa la salida y ejecútalos manualmente." 
