
import requests
try:
    # Test health
    print("Testing health...")
    r = requests.get("http://localhost:8002/health", timeout=2)
    print(f"Health: {r.status_code}")
    
    # Test translation (text)
    print("Testing translation...")
    payload = {
        "text": "Hello world",
        "target_lang": "es",
        "source_lang": "en"
    }
    r = requests.post("http://localhost:8002/translate/text", data=payload, timeout=10)
    print(f"Translation: {r.status_code}")
    print(r.json())

except Exception as e:
    print(f"Error: {e}")
