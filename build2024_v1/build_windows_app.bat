@echo off
echo ===================================================
echo City Builder 2040 - Windows Release Builder
echo ===================================================
echo.

cd /d "%~dp0\.."

echo Checking Flutter Windows build...
flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Windows build failed.
    echo Please make sure Visual Studio has "Desktop development with C++" installed.
    echo You can open Visual Studio Installer, click Modify, and check "Desktop development with C++".
    echo.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Copying release files to build2024_v1...
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "%~dp0"

echo.
echo ===================================================
echo [SUCCESS] Windows application saved to build2024_v1!
echo You can run the game by launching:
echo "%~dp0city_builder_2040.exe"
echo ===================================================
pause
