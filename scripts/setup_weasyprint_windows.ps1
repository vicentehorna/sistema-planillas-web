# Instala dependencias nativas de WeasyPrint en Windows.
# Ejecutar PowerShell como administrador desde la carpeta del proyecto:
#   powershell -ExecutionPolicy Bypass -File scripts\setup_weasyprint_windows.ps1
#
# Opción A (recomendada por WeasyPrint): MSYS2 + Pango -> C:\msys64\mingw64\bin
# Opción B (más simple): GTK3 Runtime -> C:\Program Files\GTK3-Runtime Win64\bin

param(
    [ValidateSet('msys2', 'gtk3')]
    [string]$Metodo = 'msys2'
)

$ErrorActionPreference = 'Stop'

function Test-WeasyGobjectDll {
    param([string]$BinPath)
    return (Test-Path (Join-Path $BinPath 'libgobject-2.0-0.dll'))
}

Write-Host "=== Setup WeasyPrint (Windows) - metodo: $Metodo ===" -ForegroundColor Cyan

Write-Host '1) Instalando paquetes Python...' -ForegroundColor Yellow
python -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { throw 'pip install falló' }

$dllDir = $null

if ($Metodo -eq 'gtk3') {
    $gtkRoot = 'C:\Program Files\GTK3-Runtime Win64'
    $gtkBin = Join-Path $gtkRoot 'bin'
    if (-not (Test-WeasyGobjectDll $gtkBin)) {
        Write-Host '2) Descargando GTK3 Runtime...' -ForegroundColor Yellow
        $installer = Join-Path $env:TEMP 'gtk3-runtime-win64.exe'
        $url = 'https://github.com/tschoonj/GTK-for-Windows-Runtime-Environment-Installer/releases/download/2022-01-04/gtk3-runtime-3.24.31-2022-01-04-ts-win64.exe'
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing

        Write-Host '3) Instalando GTK3 Runtime (siguiente, siguiente, finalizar)...' -ForegroundColor Yellow
        Start-Process -FilePath $installer -Wait
    }
    if (-not (Test-WeasyGobjectDll $gtkBin)) {
        throw "GTK3 no quedó instalado en $gtkBin"
    }
    $dllDir = $gtkBin
}
else {
    $msysRoot = 'C:\msys64'
    $msysBin = Join-Path $msysRoot 'mingw64\bin'
    $bash = Join-Path $msysRoot 'usr\bin\bash.exe'

    if (-not (Test-Path $bash)) {
        Write-Host '2) Descargando MSYS2...' -ForegroundColor Yellow
        $installer = Join-Path $env:TEMP 'msys2-x86_64-latest.exe'
        $url = 'https://github.com/msys2/msys2-installer/releases/download/2026-01-13/msys2-x86_64-20260113.exe'
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing

        Write-Host '3) Instalando MSYS2 en C:\msys64 (puede tardar varios minutos)...' -ForegroundColor Yellow
        Start-Process -FilePath $installer -ArgumentList 'in','--confirm-command','--accept-messages','--root','C:\msys64' -Wait
    }

    if (-not (Test-Path $bash)) {
        throw 'MSYS2 no quedó instalado. Instale manualmente desde https://www.msys2.org/'
    }

    Write-Host '4) Instalando Pango (pacman)...' -ForegroundColor Yellow
    & $bash -lc 'pacman -Sy --noconfirm mingw-w64-x86_64-pango'
    if ($LASTEXITCODE -ne 0) { throw 'pacman falló al instalar pango' }

    if (-not (Test-WeasyGobjectDll $msysBin)) {
        throw "No se encontró libgobject en $msysBin"
    }
    $dllDir = $msysBin
}

Write-Host '5) Configurando WEASYPRINT_DLL_DIRECTORIES (usuario)...' -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable('WEASYPRINT_DLL_DIRECTORIES', $dllDir, 'User')
$env:WEASYPRINT_DLL_DIRECTORIES = $dllDir

Write-Host '6) Verificando WeasyPrint...' -ForegroundColor Yellow
python scripts\check_weasyprint.py
if ($LASTEXITCODE -ne 0) { throw 'La verificación de WeasyPrint falló' }

Write-Host ''
Write-Host 'Listo. Cierre esta terminal, abra una nueva y ejecute: python app.py' -ForegroundColor Green
