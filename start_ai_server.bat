@echo off
cd offline_ai
echo ===================================================
echo      PDFJimmy AI Server Launcher
echo ===================================================
echo.
echo [1/2] Checking and installing dependencies...
pip install -r requirements.txt
echo.
echo [2/2] Starting AI Server...
echo.
python server.py
pause
