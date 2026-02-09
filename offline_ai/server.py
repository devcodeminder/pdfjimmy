"""
FastAPI Server for AI-Powered PDF Analysis
Endpoints for all AI features
"""

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
import tempfile
import json
from typing import Optional

from ai_analysis_service import (
    PDFAIAnalyzer,
    analyze_pdf,
    translate_pdf_text,
    get_page_summary
)

from ocr_smart_ai_service import (
    ocr_service,
    search_service,
    classifier,
    perform_ocr,
    detect_language,
    extract_tables,
    recognize_handwriting,
    smart_search,
    classify_document,
    extract_keyphrases
)

app = FastAPI(title="PDF AI Analysis API", version="3.0")

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

analyzer = PDFAIAnalyzer()


@app.get("/")
async def root():
    """API status check"""
    return {
        "status": "running",
        "service": "PDF AI Analysis API",
        "version": "3.0",
        "features": [
            "Auto Summary (5 bullets)",
            "Page-wise Summaries",
            "Important Lines Detection",
            "Entity Detection (dates, amounts, definitions)",
            "Color-wise Highlights",
            "Multi-language Translation",
            "Layout-preserving Translation",
            "OCR (Offline Tesseract)",
            "Language Auto-detection",
            "Handwriting Recognition",
            "Table Extraction",
            "Smart Keyword Search",
            "Synonym Search",
            "Document Classification"
        ]
    }


@app.post("/analyze/full")
async def analyze_full_pdf(file: UploadFile = File(...)):
    """
    Complete PDF analysis with all features
    Returns: summary bullets, page summaries, important lines, entities, highlights
    """
    try:
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        # Analyze PDF
        result = analyze_pdf(tmp_path)
        
        # Clean up
        os.unlink(tmp_path)
        
        return JSONResponse(content=result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/analyze/summary")
async def get_summary(file: UploadFile = File(...), num_points: int = Form(5)):
    """
    Get bullet-point summary of entire PDF
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        bullets = analyzer.generate_bullet_summary(full_text, num_points=num_points)
        
        os.unlink(tmp_path)
        
        return {
            "success": True,
            "summary_bullets": bullets,
            "num_points": len(bullets)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/analyze/page-summaries")
async def get_page_summaries(file: UploadFile = File(...)):
    """
    Get summaries for each page
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        _, pages_text = analyzer.extract_text_from_pdf(tmp_path)
        
        page_summaries = []
        for idx, page_text in enumerate(pages_text):
            summary = analyzer.generate_page_summary(page_text)
            page_summaries.append({
                'page_number': idx + 1,
                'summary': summary,
                'word_count': len(page_text.split())
            })
        
        os.unlink(tmp_path)
        
        return {
            "success": True,
            "page_summaries": page_summaries,
            "total_pages": len(page_summaries)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/analyze/important-lines")
async def get_important_lines(file: UploadFile = File(...), top_n: int = Form(10)):
    """
    Detect important lines in PDF
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        important_lines = analyzer.detect_important_lines(full_text, top_n=top_n)
        
        os.unlink(tmp_path)
        
        return {
            "success": True,
            "important_lines": important_lines,
            "count": len(important_lines)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/analyze/entities")
async def detect_entities(file: UploadFile = File(...)):
    """
    Detect entities: dates, amounts, definitions, emails, phone numbers, URLs
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        entities = analyzer.detect_entities(full_text)
        
        os.unlink(tmp_path)
        
        return {
            "success": True,
            "entities": entities,
            "counts": {key: len(value) for key, value in entities.items()}
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/analyze/categorize-highlights")
async def categorize_highlights(file: UploadFile = File(...)):
    """
    Categorize text for color-coded highlights: definitions (blue), dates (green), amounts (yellow)
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        categories = analyzer.categorize_highlights(full_text)
        
        os.unlink(tmp_path)
        
        return {
            "success": True,
            "highlights": categories,
            "counts": {key: len(value) for key, value in categories.items()}
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/translate/text")
async def translate_text(
    text: str = Form(...),
    target_lang: str = Form("hi"),
    source_lang: str = Form("auto")
):
    """
    Translate text to target language
    Languages: en (English), hi (Hindi), ta (Tamil), es (Spanish), fr (French), etc.
    """
    try:
        translated = analyzer.translate_text(text, source_lang=source_lang, target_lang=target_lang)
        
        return {
            "success": True,
            "original": text,
            "translated": translated,
            "source_lang": source_lang,
            "target_lang": target_lang
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/translate/pdf")
async def translate_pdf(
    file: UploadFile = File(...),
    target_lang: str = Form("hi")
):
    """
    Translate entire PDF text
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        translated = analyzer.translate_text(full_text, target_lang=target_lang)
        
        os.unlink(tmp_path)
        
        return {
            "success": True,
            "original_length": len(full_text),
            "translated_text": translated,
            "target_lang": target_lang
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/translate/page-layout")
async def translate_page_with_layout(
    file: UploadFile = File(...),
    page_num: int = Form(...),
    target_lang: str = Form("hi")
):
    """
    Translate a specific page while preserving layout information
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        result = analyzer.translate_page_preserving_layout(tmp_path, page_num, target_lang=target_lang)
        
        os.unlink(tmp_path)
        
        if 'error' in result:
            raise HTTPException(status_code=400, detail=result['error'])
        
        return {
            "success": True,
            **result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))




@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "PDF AI Analysis"}


# ==================== OCR ENDPOINTS ====================

@app.post("/ocr/extract")
async def ocr_extract_text(
    image: UploadFile = File(...),
    language: str = Form("eng"),
    detect_language: bool = Form(False),
    preserve_layout: bool = Form(True)
):
    """
    Extract text from image using OCR
    """
    try:
        image_bytes = await image.read()
        
        # Detect language if requested
        if detect_language:
            lang_result = ocr_service.detect_language(image_bytes)
            language = lang_result.get('primary_language', 'eng')
        
        result = perform_ocr(image_bytes, language, preserve_layout)
        
        if detect_language:
            result['detected_language'] = language
        
        return JSONResponse(content=result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ocr/pdf-page")
async def ocr_pdf_page(
    pdf: UploadFile = File(...),
    page_number: int = Form(...),
    language: str = Form("eng"),
    detect_language: bool = Form(False),
    preserve_layout: bool = Form(True)
):
    """
    Perform OCR on a specific PDF page
    """
    try:
        import fitz
        from pdf2image import convert_from_bytes
        
        pdf_bytes = await pdf.read()
        
        # Convert PDF page to image
        images = convert_from_bytes(pdf_bytes, first_page=page_number, last_page=page_number)
        
        if not images:
            raise HTTPException(status_code=400, detail="Could not convert PDF page to image")
        
        # Convert PIL image to bytes
        import io
        img_byte_arr = io.BytesIO()
        images[0].save(img_byte_arr, format='PNG')
        image_bytes = img_byte_arr.getvalue()
        
        # Perform OCR
        if detect_language:
            lang_result = ocr_service.detect_language(image_bytes)
            language = lang_result.get('primary_language', 'eng')
        
        result = perform_ocr(image_bytes, language, preserve_layout)
        
        if detect_language:
            result['detected_language'] = language
        
        return JSONResponse(content=result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ocr/detect-language")
async def ocr_detect_language(image: UploadFile = File(...)):
    """
    Detect language in image text
    """
    try:
        image_bytes = await image.read()
        result = detect_language(image_bytes)
        return JSONResponse(content=result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ocr/handwriting")
async def ocr_handwriting(
    image: UploadFile = File(...),
    language: str = Form("eng")
):
    """
    Recognize handwriting in image (premium feature)
    """
    try:
        image_bytes = await image.read()
        result = recognize_handwriting(image_bytes, language)
        return JSONResponse(content=result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ocr/extract-tables")
async def ocr_extract_tables(
    image: UploadFile = File(...),
    language: str = Form("eng")
):
    """
    Extract tables from image using layout-aware OCR
    """
    try:
        image_bytes = await image.read()
        result = extract_tables(image_bytes, language)
        return JSONResponse(content=result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/ocr/languages")
async def get_ocr_languages():
    """
    Get list of supported OCR languages
    """
    try:
        languages = ocr_service.get_supported_languages()
        return {"languages": languages}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== SMART AI ENDPOINTS ====================

@app.post("/ai/smart-search")
async def ai_smart_search(
    pdf: UploadFile = File(...),
    query: str = Form(...),
    include_synonyms: bool = Form(True),
    highlight_paragraphs: bool = Form(True)
):
    """
    Perform smart keyword search with exact paragraph highlighting
    Example: search "termination clause" → exact paragraph highlight
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await pdf.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        # Extract text from PDF
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        
        # Perform smart search
        result = smart_search(full_text, query, include_synonyms)
        
        os.unlink(tmp_path)
        
        return JSONResponse(content=result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ai/synonym-search")
async def ai_synonym_search(
    pdf: UploadFile = File(...),
    query: str = Form(...),
    max_synonyms: int = Form(5)
):
    """
    Search with synonym expansion
    Example: "agreement" will also find "contract", "deal", etc.
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await pdf.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        # Extract text from PDF
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        
        # Get synonyms
        synonyms = search_service.get_synonyms(query, max_synonyms)
        
        # Perform search with synonyms
        result = smart_search(full_text, query, include_synonyms=True)
        
        os.unlink(tmp_path)
        
        return JSONResponse(content={
            'original_query': query,
            'synonyms': synonyms,
            'matches': result['matches'],
            'total_matches': result['total_matches']
        })
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ai/classify-document")
async def ai_classify_document(pdf: UploadFile = File(...)):
    """
    Classify document type automatically
    Returns: Invoice, ID, Notes, Contract, or Other
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await pdf.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        # Extract text from PDF
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        
        # Classify document
        result = classify_document(full_text)
        
        os.unlink(tmp_path)
        
        return JSONResponse(content=result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ai/semantic-similarity")
async def ai_semantic_similarity(
    text1: str = Form(...),
    text2: str = Form(...)
):
    """
    Get semantic similarity between two text segments
    """
    try:
        similarity = search_service.semantic_similarity(text1, text2)
        
        return {
            "text1": text1,
            "text2": text2,
            "similarity": similarity
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ai/extract-keyphrases")
async def ai_extract_keyphrases(
    pdf: UploadFile = File(...),
    top_n: int = Form(10)
):
    """
    Extract key phrases from document
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await pdf.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        # Extract text from PDF
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        
        # Extract keyphrases
        keyphrases = extract_keyphrases(full_text, top_n)
        
        os.unlink(tmp_path)
        
        return {
            "keyphrases": keyphrases,
            "count": len(keyphrases)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/ai/extract-topics")
async def ai_extract_topics(pdf: UploadFile = File(...)):
    """
    Get document topics using topic modeling
    """
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
            content = await pdf.read()
            tmp_file.write(content)
            tmp_path = tmp_file.name
        
        # Extract text from PDF
        full_text, _ = analyzer.extract_text_from_pdf(tmp_path)
        
        # Extract keyphrases as topics (simplified)
        keyphrases = extract_keyphrases(full_text, top_n=5)
        
        # Convert to topics format
        topics = [
            {
                'topic': kp['phrase'],
                'weight': kp['score'],
                'keywords': kp['phrase'].split()
            }
            for kp in keyphrases
        ]
        
        os.unlink(tmp_path)
        
        return {
            "topics": topics,
            "count": len(topics)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    print("Starting PDF AI Analysis Server...")
    print("Features: Auto-summary, Page summaries, Entity detection, Translation")
    print("Server running on http://localhost:8002")
    print("API docs available at http://localhost:8002/docs")
    
    uvicorn.run(app, host="0.0.0.0", port=8002, log_level="info")
