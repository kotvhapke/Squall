@echo off
title Squall — Установка
setlocal enabledelayedexpansion

:: Squall Auto-Installer
:: Запускается из ZIP. Копирует файлы, создаёт ярлык на рабочем столе.
:: Требует права администратора для Program Files.

cd /d "%~dp0"

:: 1. Проверяем, что рядом есть squall.exe
if not exist "squall.exe" (
    echo [ERROR] squall.exe not found.
    echo Убедитесь, что вы распаковали архив полностью.
    pause
    exit /b 1
)

:: 2. Определяем папку установки
set "INSTALL_DIR=%LOCALAPPDATA%\Squall"

:: 3. Копируем файлы
echo Установка в %INSTALL_DIR% ...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
copy /y "%~dp0squall.exe" "%INSTALL_DIR%\squall.exe" >nul
if exist "%~dp0*.dll" copy /y "%~dp0*.dll" "%INSTALL_DIR%\" >nul 2>&1
if exist "%~dp0data" (
    if exist "%INSTALL_DIR%\data" rmdir /s /q "%INSTALL_DIR%\data"
    xcopy /e /i /q /y "%~dp0data" "%INSTALL_DIR%\data\" >nul
)

:: 4. Создаём ярлык на рабочем столе
set "SHORTCUT=%USERPROFILE%\Desktop\Squall.lnk"
if exist "%SHORTCUT%" del "%SHORTCUT%"

powershell -NoProfile -Command ^
"$s = New-Object -ComObject WScript.Shell; $l = $s.CreateShortcut('%SHORTCUT%'); $l.TargetPath = '%INSTALL_DIR%\squall.exe'; $l.WorkingDirectory = '%INSTALL_DIR%'; $l.IconLocation = '%INSTALL_DIR%\squall.exe,0'; $l.Save()" >nul

:: 5. Запускаем приложение
start "" "%INSTALL_DIR%\squall.exe"

:: 6. Готово
echo.
echo === Squall установлен! ===
echo Ярлык на рабочем столе: %SHORTCUT%
echo.
timeout /t 3 /nobreak >nul