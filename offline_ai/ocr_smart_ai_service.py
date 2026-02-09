"""
OCR and Smart AI Service
Provides OCR, language detection, handwriting recognition, and smart search
"""

import cv2
import numpy as np
import pytesseract
from PIL import Image
import io
import fitz  # PyMuPDF
from typing import List, Dict, Any, Tuple
import re
from langdetect import detect, detect_langs
from collections import Counter
import spacy
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Try to load spaCy model
try:
    nlp = spacy.load("en_core_web_sm")
except:
    print("Warning: spaCy model 'en_core_web_sm' not found. Run: python -m spacy download en_core_web_sm")
    nlp = None


class OCRService:
    """Advanced OCR capabilities"""
    
    def __init__(self):
        # Configure Tesseract (update path if needed)
        # pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
        pass
    
    def preprocess_image(self, image_bytes: bytes) -> np.ndarray:
        """Preprocess image for better OCR results"""
        # Convert bytes to numpy array
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply adaptive thresholding
        thresh = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
        )
        
        # Denoise
        denoised = cv2.fastNlMeansDenoising(thresh)
        
        return denoised
    
    def extract_text(
        self,
        image_bytes: bytes,
        language: str = 'eng',
        preserve_layout: bool = True
    ) -> Dict[str, Any]:
        """Extract text from image using Tesseract OCR"""
        try:
            # Preprocess image
            processed_img = self.preprocess_image(image_bytes)
            
            # Configure OCR
            config = '--psm 6' if preserve_layout else '--psm 3'
            
            # Perform OCR
            text = pytesseract.image_to_string(
                processed_img,
                lang=language,
                config=config
            )
            
            # Get detailed data with bounding boxes
            data = pytesseract.image_to_data(
                processed_img,
                lang=language,
                config=config,
                output_type=pytesseract.Output.DICT
            )
            
            # Extract blocks with confidence
            blocks = self._extract_blocks(data)
            
            # Calculate average confidence
            confidences = [b['confidence'] for b in blocks if b['confidence'] > 0]
            avg_confidence = sum(confidences) / len(confidences) if confidences else 0
            
            return {
                'text': text,
                'confidence': avg_confidence,
                'blocks': blocks,
                'metadata': {
                    'language': language,
                    'preserve_layout': preserve_layout
                }
            }
        except Exception as e:
            return {
                'text': '',
                'confidence': 0,
                'error': str(e)
            }
    
    def _extract_blocks(self, data: Dict) -> List[Dict[str, Any]]:
        """Extract text blocks with bounding boxes"""
        blocks = []
        n_boxes = len(data['text'])
        
        for i in range(n_boxes):
            if int(data['conf'][i]) > 0:  # Only include confident detections
                blocks.append({
                    'text': data['text'][i],
                    'confidence': float(data['conf'][i]),
                    'bounding_box': {
                        'x': int(data['left'][i]),
                        'y': int(data['top'][i]),
                        'width': int(data['width'][i]),
                        'height': int(data['height'][i])
                    },
                    'type': 'word'  # Can be enhanced to detect paragraphs, lines, etc.
                })
        
        return blocks
    
    def detect_language(self, image_bytes: bytes) -> Dict[str, Any]:
        """Detect language in image text"""
        try:
            # Extract text first
            processed_img = self.preprocess_image(image_bytes)
            text = pytesseract.image_to_string(processed_img)
            
            if not text.strip():
                return {
                    'primary_language': 'unknown',
                    'confidence': 0.0,
                    'candidates': []
                }
            
            # Detect language
            langs = detect_langs(text)
            
            return {
                'primary_language': langs[0].lang if langs else 'unknown',
                'confidence': langs[0].prob if langs else 0.0,
                'candidates': [
                    {'language': lang.lang, 'confidence': lang.prob}
                    for lang in langs[:5]
                ]
            }
        except Exception as e:
            return {
                'primary_language': 'unknown',
                'confidence': 0.0,
                'error': str(e)
            }
    
    def extract_tables(self, image_bytes: bytes, language: str = 'eng') -> Dict[str, Any]:
        """Extract tables from image using layout analysis"""
        try:
            # Preprocess image
            nparr = np.frombuffer(image_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            
            # Detect horizontal and vertical lines
            horizontal_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (40, 1))
            vertical_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 40))
            
            # Detect horizontal lines
            horizontal = cv2.morphologyEx(gray, cv2.MORPH_OPEN, horizontal_kernel)
            # Detect vertical lines
            vertical = cv2.morphologyEx(gray, cv2.MORPH_OPEN, vertical_kernel)
            
            # Combine lines
            table_mask = cv2.add(horizontal, vertical)
            
            # Find contours (table cells)
            contours, _ = cv2.findContours(table_mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
            
            # Extract text from cells
            # This is a simplified version - production would need more sophisticated table detection
            tables = []
            
            return {
                'tables': tables,
                'table_count': len(tables)
            }
        except Exception as e:
            return {
                'tables': [],
                'table_count': 0,
                'error': str(e)
            }
    
    def recognize_handwriting(self, image_bytes: bytes, language: str = 'eng') -> Dict[str, Any]:
        """Recognize handwriting (premium feature)"""
        try:
            # Preprocess for handwriting
            nparr = np.frombuffer(image_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            
            # Apply specific preprocessing for handwriting
            # Increase contrast
            clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
            enhanced = clahe.apply(gray)
            
            # Use Tesseract with handwriting-optimized config
            config = '--psm 6 --oem 1'  # LSTM OCR Engine
            text = pytesseract.image_to_string(enhanced, lang=language, config=config)
            
            return {
                'text': text,
                'confidence': 0.7,  # Handwriting typically has lower confidence
                'metadata': {
                    'type': 'handwriting',
                    'language': language
                }
            }
        except Exception as e:
            return {
                'text': '',
                'confidence': 0,
                'error': str(e)
            }
    
    def get_supported_languages(self) -> List[str]:
        """Get list of supported OCR languages"""
        try:
            langs = pytesseract.get_languages()
            return langs
        except:
            return ['eng', 'spa', 'fra', 'deu', 'ita', 'por', 'rus', 'chi_sim', 'jpn', 'kor']


class SmartSearchService:
    """Smart search with synonyms and semantic understanding"""
    
    def __init__(self):
        self.synonym_dict = self._build_synonym_dict()
    
    def _build_synonym_dict(self) -> Dict[str, List[str]]:
        """Build synonym dictionary for common terms"""
        return {
            'agreement': ['contract', 'deal', 'arrangement', 'accord', 'pact'],
            'contract': ['agreement', 'deal', 'arrangement', 'covenant'],
            'termination': ['cancellation', 'ending', 'conclusion', 'cessation'],
            'clause': ['provision', 'section', 'article', 'term'],
            'payment': ['compensation', 'remuneration', 'fee', 'charge'],
            'invoice': ['bill', 'receipt', 'statement', 'account'],
            'date': ['time', 'period', 'deadline', 'term'],
            'amount': ['sum', 'total', 'value', 'quantity'],
            'party': ['entity', 'organization', 'company', 'individual'],
            'obligation': ['duty', 'responsibility', 'commitment', 'requirement'],
        }
    
    def get_synonyms(self, word: str, max_synonyms: int = 5) -> List[str]:
        """Get synonyms for a word"""
        word_lower = word.lower()
        synonyms = self.synonym_dict.get(word_lower, [])
        
        # Use spaCy for additional synonyms if available
        if nlp and len(synonyms) < max_synonyms:
            doc = nlp(word)
            # This is simplified - production would use word embeddings
            pass
        
        return synonyms[:max_synonyms]
    
    def smart_search(
        self,
        text: str,
        query: str,
        include_synonyms: bool = True,
        highlight_paragraphs: bool = True
    ) -> Dict[str, Any]:
        """Perform smart search with synonym expansion"""
        matches = []
        synonyms_used = []
        
        # Split into paragraphs
        paragraphs = text.split('\n\n')
        
        # Search terms
        search_terms = [query.lower()]
        if include_synonyms:
            synonyms = self.get_synonyms(query)
            search_terms.extend(synonyms)
            synonyms_used = synonyms
        
        # Search each paragraph
        for para_idx, paragraph in enumerate(paragraphs):
            para_lower = paragraph.lower()
            
            for term in search_terms:
                if term in para_lower:
                    # Find exact position
                    start_idx = para_lower.find(term)
                    end_idx = start_idx + len(term)
                    
                    # Calculate relevance score
                    relevance = 1.0 if term == query.lower() else 0.8
                    
                    matches.append({
                        'page_number': 0,  # Would need page info from PDF
                        'paragraph': paragraph,
                        'matched_text': paragraph[start_idx:end_idx],
                        'relevance_score': relevance,
                        'start_index': start_idx,
                        'end_index': end_idx,
                        'match_type': 'exact' if term == query.lower() else 'synonym'
                    })
        
        return {
            'query': query,
            'matches': matches,
            'total_matches': len(matches),
            'synonyms_used': synonyms_used
        }
    
    def semantic_similarity(self, text1: str, text2: str) -> float:
        """Calculate semantic similarity between texts"""
        try:
            # Use TF-IDF for similarity
            vectorizer = TfidfVectorizer()
            tfidf_matrix = vectorizer.fit_transform([text1, text2])
            similarity = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:2])[0][0]
            return float(similarity)
        except:
            return 0.0


class DocumentClassifier:
    """Classify documents into categories"""
    
    def __init__(self):
        self.categories = {
            'invoice': ['invoice', 'bill', 'payment', 'amount', 'total', 'due', 'tax'],
            'contract': ['agreement', 'contract', 'party', 'clause', 'term', 'obligation'],
            'id': ['identification', 'passport', 'license', 'card', 'number', 'issued'],
            'notes': ['note', 'memo', 'reminder', 'meeting', 'action', 'todo'],
            'receipt': ['receipt', 'purchased', 'transaction', 'paid', 'store'],
        }
    
    def classify(self, text: str) -> Dict[str, Any]:
        """Classify document based on content"""
        text_lower = text.lower()
        scores = {}
        
        # Calculate score for each category
        for category, keywords in self.categories.items():
            score = sum(1 for keyword in keywords if keyword in text_lower)
            scores[category] = score
        
        # Get top category
        if not scores or max(scores.values()) == 0:
            return {
                'document_type': 'Other',
                'confidence': 0.0,
                'candidates': [],
                'features': {}
            }
        
        # Sort by score
        sorted_categories = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        top_category, top_score = sorted_categories[0]
        
        # Calculate confidence
        total_score = sum(scores.values())
        confidence = top_score / total_score if total_score > 0 else 0
        
        # Build candidates
        candidates = [
            {
                'type': cat.capitalize(),
                'confidence': score / total_score if total_score > 0 else 0
            }
            for cat, score in sorted_categories[:3]
        ]
        
        return {
            'document_type': top_category.capitalize(),
            'confidence': confidence,
            'candidates': candidates,
            'features': scores
        }
    
    def extract_keyphrases(self, text: str, top_n: int = 10) -> List[Dict[str, Any]]:
        """Extract key phrases from text"""
        if not nlp:
            # Fallback: simple word frequency
            words = re.findall(r'\b[a-z]{4,}\b', text.lower())
            word_freq = Counter(words)
            
            return [
                {
                    'phrase': word,
                    'score': freq / len(words) if words else 0,
                    'frequency': freq
                }
                for word, freq in word_freq.most_common(top_n)
            ]
        
        # Use spaCy for better phrase extraction
        doc = nlp(text)
        
        # Extract noun phrases
        phrases = [chunk.text for chunk in doc.noun_chunks]
        phrase_freq = Counter(phrases)
        
        return [
            {
                'phrase': phrase,
                'score': freq / len(phrases) if phrases else 0,
                'frequency': freq
            }
            for phrase, freq in phrase_freq.most_common(top_n)
        ]


# Standalone functions for API
ocr_service = OCRService()
search_service = SmartSearchService()
classifier = DocumentClassifier()


def perform_ocr(image_bytes: bytes, language: str = 'eng', preserve_layout: bool = True) -> Dict[str, Any]:
    """Perform OCR on image"""
    return ocr_service.extract_text(image_bytes, language, preserve_layout)


def detect_language(image_bytes: bytes) -> Dict[str, Any]:
    """Detect language in image"""
    return ocr_service.detect_language(image_bytes)


def extract_tables(image_bytes: bytes, language: str = 'eng') -> Dict[str, Any]:
    """Extract tables from image"""
    return ocr_service.extract_tables(image_bytes, language)


def recognize_handwriting(image_bytes: bytes, language: str = 'eng') -> Dict[str, Any]:
    """Recognize handwriting"""
    return ocr_service.recognize_handwriting(image_bytes, language)


def smart_search(text: str, query: str, include_synonyms: bool = True) -> Dict[str, Any]:
    """Perform smart search"""
    return search_service.smart_search(text, query, include_synonyms)


def classify_document(text: str) -> Dict[str, Any]:
    """Classify document"""
    return classifier.classify(text)


def extract_keyphrases(text: str, top_n: int = 10) -> List[Dict[str, Any]]:
    """Extract key phrases"""
    return classifier.extract_keyphrases(text, top_n)


if __name__ == "__main__":
    print("OCR and Smart AI Service initialized")
    print(f"Supported languages: {ocr_service.get_supported_languages()}")
