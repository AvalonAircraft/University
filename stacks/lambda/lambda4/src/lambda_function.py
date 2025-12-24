# lambda_function.py  (Handler: lambda_function.handler)
import os, json, time
from typing import Any, Dict

DEFAULT_STATUS = os.getenv("DEFAULT_STATUS", "available")

def _take_detail(e: Dict[str, Any]):
    return e.get("detail") if isinstance(e, dict) and isinstance(e.get("detail"), dict) else e

def handler(event, context):
    data = _take_detail(event) or {}

    tenant = data.get("tenantId") or data.get("tenant_id") or "unknown"
    user_id = (data.get("userID") or data.get("userId")
               or (data.get("meta") or {}).get("userId") or "unknown")

    # aus L3: PDF-Resultat
    doc = (data.get("document") or
           (data.get("enrichment") or {}).get("document") or {})

    bucket = doc.get("bucket")
    key    = doc.get("key")
    url    = doc.get("cf_url") or doc.get("url") or doc.get("s3_url")
    filename = (data.get("filename")
                or (key.split("/")[-1] if isinstance(key, str) else "document.pdf"))

    meta = data.get("meta") or {}
    analysis = (data.get("analysis") or {}).get("bedrock") or (data.get("analysis") or {})

    file_event = {
        "tenantId": tenant,
        "userID": user_id,
        "status": DEFAULT_STATUS,           # e.g. "available"
        "filename": filename,
        "document": {
            "url": url,
            "bucket": bucket,
            "key": key
        },
        "meta": {
            "subject": meta.get("subject",""),
            "from": meta.get("from",""),
            "to": meta.get("to",""),
            "cc": meta.get("cc","")
        },
        "analysis": analysis,
        "emittedAt": int(time.time()*1000)
    }

    # Step Functions bekommt genau dieses Objekt weiter
    return file_event
