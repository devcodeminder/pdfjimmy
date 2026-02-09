import os
import fitz  # PyMuPDF
try:
    import pytesseract
    from pdf2image import convert_from_path
except ImportError:
    pytesseract = None
    convert_from_path = None

from sumy.parsers.plaintext import PlaintextParser
from sumy.nlp.tokenizers import Tokenizer
from sumy.summarizers.lsa import LsaSummarizer
from sumy.nlp.stemmers import Stemmer
from sumy.utils import get_stop_words
import nltk
import re

class OfflinePDFToolkit:
    def __init__(self):
        self.language = "english"
        # Ensure NLTK data is ready
        try:
            nltk.data.find('tokenizers/punkt')
        except LookupError:
            nltk.download('punkt')

    def extract_text_pypdf(self, pdf_path: str) -> str:
        """Fast extraction using PyMuPDF"""
        try:
            doc = fitz.open(pdf_path)
            text = ""
            for page in doc:
                text += page.get_text()
            return text
        except Exception as e:
            return f"Error reading PDF: {str(e)}"

    def extract_text_ocr(self, pdf_path: str, lang: str = "tam+eng") -> str:
        """Slower extraction using Tesseract OCR (good for scanned/broken fonts)"""
        if not pytesseract or not convert_from_path:
            return "Error: pytesseract or pdf2image not installed."
        
        try:
            # Convert PDF pages to images
            images = convert_from_path(pdf_path)
            full_text = ""
            
            # Configure Tesseract
            # Need to ensure 'tam' data is installed on user system
            custom_config = r'--oem 3 --psm 6' 
            
            for i, img in enumerate(images):
                # Use Tamil + English logic
                text = pytesseract.image_to_string(img, lang=lang, config=custom_config)
                full_text += f"\n--- Page {i+1} ---\n{text}"
            
            return full_text
        except Exception as e:
            return f"Error during OCR: {str(e)}"

    def summarize_text(self, text: str, sentence_count: int = 5) -> str:
        if not text.strip():
            return ""
        
        try:
            parser = PlaintextParser.from_string(text, Tokenizer(self.language))
            stemmer = Stemmer(self.language)
            summarizer = LsaSummarizer(stemmer)
            summarizer.stop_words = get_stop_words(self.language)
            
            summary = summarizer(parser.document, sentence_count)
            return " ".join([str(sentence) for sentence in summary])
        except Exception:
            return "Could not generate summary (text might be too short or complex)."

    def analyze_pdf(self, pdf_path: str, use_ocr: bool = False) -> dict:
        text = ""
        used_method = "fast"
        
        # 1. Try Fast Extraction
        if not use_ocr:
            text = self.extract_text_pypdf(pdf_path)
            
            # Auto-detect broken font artifacts (The "H" / "A" corruption issue)
            # If we see many "H"s sandwiched between Tamil chars, it's broken.
            # We can detect this if we find very few actual Tamil/English words but lots of symbols.
            # Simple heuristic: If extraction is almost empty or garbage, we might suggest OCR.
            if not text.strip():
                used_method = "ocr_fallback"
                text = self.extract_text_ocr(pdf_path, lang="tam+eng")

        # 2. Forced OCR (User requested)
        else:
            used_method = "ocr_forced"
            text = self.extract_text_ocr(pdf_path, lang="tam+eng")

        summary = self.summarize_text(text)
        
        return {
            "method": used_method,
            "text_length": len(text),
            "text_preview": text[:500] + "..." if len(text) > 500 else text,
            "summary": summary,
            "full_text": text
        }
