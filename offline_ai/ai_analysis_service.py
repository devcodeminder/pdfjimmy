"""
AI-Powered PDF Analysis Service
Provides: Auto-summary, Page-wise summaries, Entity detection, Translation
Fast and efficient processing using NLP techniques
"""

import fitz  # PyMuPDF
import re
from typing import List, Dict, Any, Tuple
from collections import Counter
import json

# NLP Libraries
from sumy.parsers.plaintext import PlaintextParser
from sumy.nlp.tokenizers import Tokenizer
from sumy.summarizers.lsa import LsaSummarizer
from sumy.summarizers.lex_rank import LexRankSummarizer
import nltk
from nltk.tokenize import sent_tokenize, word_tokenize
from nltk.corpus import stopwords

# Translation
from deep_translator import GoogleTranslator

# Download required NLTK data (run once)
try:
    nltk.data.find('tokenizers/punkt')
except LookupError:
    nltk.download('punkt', quiet=True)
    
try:
    nltk.data.find('corpora/stopwords')
except LookupError:
    nltk.download('stopwords', quiet=True)


class PDFAIAnalyzer:
    """Advanced PDF Analysis with AI capabilities"""
    
    def __init__(self):
        self.stop_words = set(stopwords.words('english'))
        
    def extract_text_from_pdf(self, pdf_path: str) -> Tuple[str, List[str]]:
        """Extract full text and page-wise text from PDF"""
        doc = fitz.open(pdf_path)
        full_text = ""
        pages_text = []
        
        for page_num in range(len(doc)):
            page = doc[page_num]
            page_text = page.get_text()
            pages_text.append(page_text)
            full_text += page_text + "\n"
        
        doc.close()
        return full_text, pages_text
    
    def generate_bullet_summary(self, text: str, num_points: int = 5) -> List[str]:
        """Generate bullet-point summary of entire PDF"""
        if not text or len(text.strip()) < 100:
            return ["Document is too short to summarize."]
        
        try:
            # Use LSA summarizer for better results
            parser = PlaintextParser.from_string(text, Tokenizer("english"))
            summarizer = LsaSummarizer()
            
            # Generate summary sentences
            summary_sentences = summarizer(parser.document, num_points)
            
            # Convert to bullet points
            bullets = []
            for sentence in summary_sentences:
                bullet = str(sentence).strip()
                if bullet and len(bullet) > 20:  # Filter out very short sentences
                    bullets.append(bullet)
            
            # Ensure we have exactly num_points (or close to it)
            if len(bullets) < num_points and len(bullets) > 0:
                # If we have fewer bullets, try LexRank for more
                summarizer2 = LexRankSummarizer()
                additional = summarizer2(parser.document, num_points - len(bullets))
                for sentence in additional:
                    bullet = str(sentence).strip()
                    if bullet not in bullets and len(bullet) > 20:
                        bullets.append(bullet)
            
            return bullets[:num_points] if bullets else ["Unable to generate summary."]
            
        except Exception as e:
            print(f"Summary error: {e}")
            # Fallback: Extract first sentences from different sections
            sentences = sent_tokenize(text)
            return sentences[:num_points] if len(sentences) >= num_points else sentences
    
    def generate_page_summary(self, page_text: str, max_sentences: int = 3) -> str:
        """Generate summary for a single page"""
        if not page_text or len(page_text.strip()) < 50:
            return "Page content is too short to summarize."
        
        try:
            parser = PlaintextParser.from_string(page_text, Tokenizer("english"))
            summarizer = LexRankSummarizer()
            
            summary_sentences = summarizer(parser.document, max_sentences)
            summary = " ".join([str(sentence) for sentence in summary_sentences])
            
            return summary if summary else "Unable to summarize this page."
            
        except Exception as e:
            # Fallback: Return first few sentences
            sentences = sent_tokenize(page_text)
            return " ".join(sentences[:max_sentences])
    
    def detect_important_lines(self, text: str, top_n: int = 10) -> List[Dict[str, Any]]:
        """Detect important lines using keyword frequency and position"""
        sentences = sent_tokenize(text)
        if not sentences:
            return []
        
        important_lines = []
        
        # Score sentences based on multiple factors
        for idx, sentence in enumerate(sentences):
            score = 0
            sentence_lower = sentence.lower()
            
            # Factor 1: Position (first and last sentences are often important)
            if idx < 3:
                score += 3
            if idx >= len(sentences) - 3:
                score += 2
            
            # Factor 2: Length (not too short, not too long)
            word_count = len(word_tokenize(sentence))
            if 10 <= word_count <= 30:
                score += 2
            
            # Factor 3: Contains important keywords
            important_keywords = [
                'important', 'critical', 'key', 'significant', 'essential',
                'conclusion', 'summary', 'result', 'finding', 'objective',
                'purpose', 'goal', 'recommendation', 'note', 'warning'
            ]
            for keyword in important_keywords:
                if keyword in sentence_lower:
                    score += 3
                    break
            
            # Factor 4: Contains numbers/dates (often important facts)
            if re.search(r'\d+', sentence):
                score += 1
            
            # Factor 5: Contains capitalized words (proper nouns, titles)
            caps_words = re.findall(r'\b[A-Z][a-z]+\b', sentence)
            if len(caps_words) >= 2:
                score += 1
            
            # Factor 6: Sentence starts with action verbs or markers
            action_starters = ['this', 'we', 'the study', 'research', 'analysis', 'results']
            if any(sentence_lower.startswith(starter) for starter in action_starters):
                score += 1
            
            important_lines.append({
                'text': sentence,
                'score': score,
                'position': idx,
                'word_count': word_count
            })
        
        # Sort by score and return top N
        important_lines.sort(key=lambda x: x['score'], reverse=True)
        return important_lines[:top_n]
    
    def detect_entities(self, text: str) -> Dict[str, List[str]]:
        """Detect and categorize entities: dates, amounts, definitions"""
        entities = {
            'dates': [],
            'amounts': [],
            'definitions': [],
            'emails': [],
            'phone_numbers': [],
            'urls': []
        }
        
        # Date patterns
        date_patterns = [
            r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b',  # DD/MM/YYYY or MM/DD/YYYY
            r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b',    # YYYY/MM/DD
            r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2},? \d{4}\b',  # Month DD, YYYY
            r'\b\d{1,2} (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{4}\b'     # DD Month YYYY
        ]
        
        for pattern in date_patterns:
            dates = re.findall(pattern, text, re.IGNORECASE)
            entities['dates'].extend(dates)
        
        # Amount patterns (currency)
        amount_patterns = [
            r'\$\s?\d+(?:,\d{3})*(?:\.\d{2})?',  # $1,234.56
            r'₹\s?\d+(?:,\d{3})*(?:\.\d{2})?',   # ₹1,234.56
            r'€\s?\d+(?:,\d{3})*(?:\.\d{2})?',   # €1,234.56
            r'£\s?\d+(?:,\d{3})*(?:\.\d{2})?',   # £1,234.56
            r'\b\d+(?:,\d{3})*(?:\.\d{2})?\s?(?:USD|INR|EUR|GBP)\b'  # 1234.56 USD
        ]
        
        for pattern in amount_patterns:
            amounts = re.findall(pattern, text, re.IGNORECASE)
            entities['amounts'].extend(amounts)
        
        # Email pattern
        email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        entities['emails'] = re.findall(email_pattern, text)
        
        # Phone number pattern
        phone_pattern = r'\b(?:\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'
        entities['phone_numbers'] = re.findall(phone_pattern, text)
        
        # URL pattern
        url_pattern = r'https?://(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&/=]*)'
        entities['urls'] = re.findall(url_pattern, text)
        
        # Definition patterns (sentences containing "is defined as", "means", "refers to")
        definition_markers = [
            r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+is\s+defined\s+as\s+([^.]+\.)',
            r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+means\s+([^.]+\.)',
            r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+refers\s+to\s+([^.]+\.)',
            r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*):\s+([^.]+\.)'
        ]
        
        for pattern in definition_markers:
            definitions = re.findall(pattern, text)
            for term, definition in definitions:
                entities['definitions'].append(f"{term}: {definition}")
        
        # Remove duplicates
        for key in entities:
            entities[key] = list(set(entities[key]))
        
        return entities
    
    def categorize_highlights(self, text: str) -> Dict[str, List[Dict[str, str]]]:
        """Categorize text into definitions, dates, and amounts with context"""
        categories = {
            'definitions': [],
            'dates': [],
            'amounts': []
        }
        
        sentences = sent_tokenize(text)
        
        for sentence in sentences:
            # Check for definitions
            if any(marker in sentence.lower() for marker in ['is defined as', 'means', 'refers to', 'is a', 'are']):
                # Look for capitalized terms
                terms = re.findall(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b', sentence)
                if terms:
                    categories['definitions'].append({
                        'text': sentence,
                        'term': terms[0],
                        'color': 'blue'
                    })
            
            # Check for dates
            if re.search(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)', sentence, re.IGNORECASE):
                categories['dates'].append({
                    'text': sentence,
                    'color': 'green'
                })
            
            # Check for amounts
            if re.search(r'[\$₹€£]\s?\d+|\\d+\s?(?:USD|INR|EUR|GBP)', sentence):
                categories['amounts'].append({
                    'text': sentence,
                    'color': 'yellow'
                })
        
        return categories
    
    def translate_text(self, text: str, source_lang: str = 'auto', target_lang: str = 'hi') -> str:
        """Translate text to target language"""
        try:
            # Language codes: 'en' = English, 'hi' = Hindi, 'ta' = Tamil
            translator = GoogleTranslator(source=source_lang, target=target_lang)
            
            # Split into chunks if text is too long (Google Translate has limits)
            max_chunk_size = 4500
            if len(text) <= max_chunk_size:
                return translator.translate(text)
            
            # Process in chunks
            chunks = [text[i:i+max_chunk_size] for i in range(0, len(text), max_chunk_size)]
            translated_chunks = []
            
            for chunk in chunks:
                translated = translator.translate(chunk)
                translated_chunks.append(translated)
            
            return ' '.join(translated_chunks)
            
        except Exception as e:
            return f"Translation error: {str(e)}"
    
    def translate_page_preserving_layout(self, pdf_path: str, page_num: int, target_lang: str = 'hi') -> Dict[str, Any]:
        """Translate a page while attempting to preserve layout information"""
        try:
            doc = fitz.open(pdf_path)
            page = doc[page_num]
            
            # Extract text blocks with position information
            blocks = page.get_text("dict")["blocks"]
            
            translated_blocks = []
            for block in blocks:
                if block.get("type") == 0:  # Text block
                    for line in block.get("lines", []):
                        line_text = ""
                        for span in line.get("spans", []):
                            line_text += span.get("text", "")
                        
                        if line_text.strip():
                            translated_text = self.translate_text(line_text, target_lang=target_lang)
                            translated_blocks.append({
                                'original': line_text,
                                'translated': translated_text,
                                'bbox': line.get("bbox"),  # Bounding box for positioning
                                'font': line.get("spans", [{}])[0].get("font", ""),
                                'size': line.get("spans", [{}])[0].get("size", 12)
                            })
            
            doc.close()
            
            return {
                'page_num': page_num,
                'blocks': translated_blocks,
                'total_blocks': len(translated_blocks)
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def analyze_full_pdf(self, pdf_path: str) -> Dict[str, Any]:
        """Complete PDF analysis with all features"""
        try:
            # Extract text
            full_text, pages_text = self.extract_text_from_pdf(pdf_path)
            
            # Generate analyses
            result = {
                'success': True,
                'full_summary': {
                    'bullets': self.generate_bullet_summary(full_text, num_points=5),
                    'word_count': len(word_tokenize(full_text)),
                    'page_count': len(pages_text)
                },
                'page_summaries': [],
                'important_lines': self.detect_important_lines(full_text, top_n=10),
                'entities': self.detect_entities(full_text),
                'categorized_highlights': self.categorize_highlights(full_text)
            }
            
            # Generate page-wise summaries
            for idx, page_text in enumerate(pages_text):
                summary = self.generate_page_summary(page_text, max_sentences=3)
                result['page_summaries'].append({
                    'page_number': idx + 1,
                    'summary': summary,
                    'word_count': len(word_tokenize(page_text))
                })
            
            return result
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }


# Standalone functions for API endpoints
def analyze_pdf(pdf_path: str) -> Dict[str, Any]:
    """Main analysis function"""
    analyzer = PDFAIAnalyzer()
    return analyzer.analyze_full_pdf(pdf_path)


def translate_pdf_text(text: str, target_lang: str = 'hi') -> str:
    """Translate PDF text"""
    analyzer = PDFAIAnalyzer()
    return analyzer.translate_text(text, target_lang=target_lang)


def get_page_summary(pdf_path: str, page_num: int) -> str:
    """Get summary for specific page"""
    analyzer = PDFAIAnalyzer()
    _, pages_text = analyzer.extract_text_from_pdf(pdf_path)
    if 0 <= page_num < len(pages_text):
        return analyzer.generate_page_summary(pages_text[page_num])
    return "Invalid page number"


if __name__ == "__main__":
    # Test the analyzer
    import sys
    
    if len(sys.argv) > 1:
        pdf_file = sys.argv[1]
        print("Analyzing PDF...")
        result = analyze_pdf(pdf_file)
        print(json.dumps(result, indent=2))
    else:
        print("Usage: python ai_analysis_service.py <pdf_file>")
