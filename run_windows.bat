@echo off
title PDFJimmy Launcher
echo ===========================================
echo       PDFJimmy Windows Launcher
echo ===========================================
echo.
echo [Step 1] Initializing Offline AI Engine (Python)...
cd offline_ai

REM Check if virtual env or python exists (assuming global python for now based on user context)
REM Start Python server in a new minimized window with a specific title so we can kill it later.
start "PDFJimmy AI Server" /MIN python server.py

cd ..
echo AI Engine is running in the background.
echo.
echo [Step 2] Launching PDFJimmy App...
echo Please wait while the app builds and starts...
echo (First run may take a few minutes to compile)
call flutter run -d windows

echo.
echo [Step 3] Cleaning up...
echo Closing AI Server...
taskkill /F /FI "WINDOWTITLE eq PDFJimmy AI Server" >nul 2>&1
echo Session Ended.
pause
