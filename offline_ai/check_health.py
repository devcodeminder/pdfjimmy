
import requests
try:
    r = requests.get("http://localhost:8002/health", timeout=2)
    print(r.status_code)
    print(r.json())
except Exception as e:
    print(e)
