@echo off
echo Installing Python dependencies for PDFJimmy AI...
cd offline_ai
pip install -r requirements.txt
python -m nltk.downloader punkt
cd ..
echo.
echo Dependencies installed successfully!
pause
