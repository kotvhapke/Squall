@echo off
title Squall — Installer
setlocal enabledelayedexpansion

:: ============================================================
:: Squall — Windows Auto-Installer
:: Распаковывает Squall и создаёт ярлык на рабочем столе.
:: Запускать из папки, где лежит squall.exe и все DLL.
:: Если запущен из ZIP — сначала распакуйте вручную.
:: ============================================================

cd /d "%~dp0"

:: Проверяем, что squall.exe есть рядом
if not exist "squall.exe" (
    echo [ERROR] squall.exe not found in current folder.
    echo         Make sure you extracted the ZIP first.
    pause
    exit /b 1
)

:: Создаём папку в Program Files (требует админских прав — если нет, используем AppData)
set "INSTALL_DIR=%LOCALAPPDATA%\Squall"
if exist "%PROGRAMFILES%\Squall" set "INSTALL_DIR=%PROGRAMFILES%\Squall"

:: Если не в Program Files — копируем в AppData
if not "%INSTALL_DIR%"=="%PROGRAMFILES%\Squall" (
    echo Installing to: %INSTALL_DIR%
    if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
    copy /y "%~dp0squall.exe" "%INSTALL_DIR%\squall.exe" >nul
    copy /y "%~dp0*.dll" "%INSTALL_DIR%\" >nul 2>&1
    if exist "%~dp0data" xcopy /e /i /q /y "%~dp0data" "%INSTALL_DIR%\data\" >nul
)

:: Создаём ярлык на рабочем столе
set "SHORTCUT=%USERPROFILE%\Desktop\Squall.lnk"
if exist "%SHORTCUT%" del "%SHORTCUT%"

:: PowerShell скрипт для создания ярлыка
powershell -NoProfile -Command ^
"$s = New-Object -ComObject WScript.Shell; $l = $s.CreateShortcut('%SHORTCUT%'); $l.TargetPath = '%INSTALL_DIR%\squall.exe'; $l.WorkingDirectory = '%INSTALL_DIR%'; $l.IconLocation = '%INSTALL_DIR%\squall.exe,0'; $l.Save()"

echo.
echo === Squall installed successfully! ===
echo Shortcut created on your desktop.
echo.
echo To uninstall: delete "%INSTALL_DIR%" and the desktop shortcut.
echo.
pause