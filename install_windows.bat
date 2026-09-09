@echo off
title Squall — Установка
setlocal enabledelayedexpansion

:: Squall Auto-Installer
:: Запускается из ZIP. Спрашивает про ярлык, копирует файлы, запускает Squall.
:: Требует права администратора для Program Files.

cd /d "%~dp0"

:: 1. Проверяем, что рядом есть squall.exe
if not exist "squall.exe" (
    echo [ERROR] squall.exe not found.
    echo Убедитесь, что вы распаковали архив полностью.
    pause
    exit /b 1
)

:: 2. Спрашиваем про ярлык на рабочем столе
set "MAKE_SHORTCUT=Y"
echo.
echo ========================================
echo    УСТАНОВКА SQUALL
echo ========================================
choice /C YN /M "Создать ярлык на рабочем столе?"
if errorlevel 2 set "MAKE_SHORTCUT=N"

:: 3. Определяем папку установки
set "INSTALL_DIR=%LOCALAPPDATA%\Squall"

:: 4. Копируем файлы
echo.
echo Установка в %INSTALL_DIR% ...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
copy /y "%~dp0squall.exe" "%INSTALL_DIR%\squall.exe" >nul
if exist "%~dp0*.dll" copy /y "%~dp0*.dll" "%INSTALL_DIR%\" >nul 2>&1
if exist "%~dp0data" (
    if exist "%INSTALL_DIR%\data" rmdir /s /q "%INSTALL_DIR%\data"
    xcopy /e /i /q /y "%~dp0data" "%INSTALL_DIR%\data\" >nul
)

:: 5. Ярлык на рабочем столе (по желанию)
if /i "%MAKE_SHORTCUT%"=="Y" (
    set "SHORTCUT=%USERPROFILE%\Desktop\Squall.lnk"
    if exist "%SHORTCUT%" del "%SHORTCUT%"
    powershell -NoProfile -Command ^
    "$s = New-Object -ComObject WScript.Shell; $l = $s.CreateShortcut('%SHORTCUT%'); $l.TargetPath = '%INSTALL_DIR%\squall.exe'; $l.WorkingDirectory = '%INSTALL_DIR%'; $l.IconLocation = '%INSTALL_DIR%\squall.exe,0'; $l.Save()" >nul
    echo Ярлык создан: %SHORTCUT%
) else (
    echo Ярлык не создан (пропущено).
)

:: 6. Запускаем приложение
echo.
echo === Squall установлен! ===
start "" "%INSTALL_DIR%\squall.exe"

:: 7. Завершаем установку без лишнего ожидания
exit /b 0
