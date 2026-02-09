@echo off
echo ========================================
echo Installing AI Image Processing Dependencies
echo ========================================
echo.

cd offline_ai

echo [1/4] Installing Python packages...
pip install -r requirements.txt

echo.
echo [2/4] Downloading NLTK data...
python -c "import nltk; nltk.download('punkt'); nltk.download('stopwords')"

echo.
echo [3/4] Downloading spaCy model...
python -m spacy download en_core_web_sm

echo.
echo [4/4] Verifying Tesseract installation...
tesseract --version
if %errorlevel% neq 0 (
    echo.
    echo WARNING: Tesseract OCR not found!
    echo Please install Tesseract from: https://github.com/UB-Mannheim/tesseract/wiki
    echo.
) else (
    echo Tesseract OCR is installed!
)

echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo To start the AI server, run:
echo   start_ai_server.bat
echo.
pause
