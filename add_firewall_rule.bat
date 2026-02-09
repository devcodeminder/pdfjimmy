@echo off
echo Adding Windows Firewall rule for PDF AI Server...
echo This requires Administrator privileges.
echo.

netsh advfirewall firewall delete rule name="PDF AI Server" protocol=TCP localport=8002 >nul 2>&1
netsh advfirewall firewall add rule name="PDF AI Server" dir=in action=allow protocol=TCP localport=8002

if %errorlevel% equ 0 (
    echo.
    echo SUCCESS! Firewall rule added.
    echo The Android emulator should now be able to connect to the server.
) else (
    echo.
    echo ERROR: Failed to add firewall rule.
    echo Please run this script as Administrator:
    echo   1. Right-click on add_firewall_rule.bat
    echo   2. Select "Run as administrator"
)

echo.
pause
