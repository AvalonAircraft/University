# lambda_function.py  (Lambda5 – minimal, ohne EventBridge/SNS/SQS)
import os
import json
import time
import urllib.parse
from typing import Any, Dict, List, Tuple

DEFAULT_CLIENTS = [c.strip() for c in os.getenv("DEFAULT_CLIENTS", "").split(",") if c.strip()]
STRICT_MODE = os.getenv("STRICT_MODE", "0") == "1"
MAX_DETAIL_BYTES = 200_000  # Falls jemand riesige Felder schickt

def _take_detail(e: Dict[str, Any]) -> Dict[str, Any]:
    return e.get("detail") if isinstance(e, dict) and isinstance(e.get("detail"), dict) else e

def _now_ms() -> int:
    return int(time.time() * 1000)

def _basename_from_key(key: str) -> str:
    return urllib.parse.unquote((key or "").rsplit("/", 1)[-1]) if key else ""

def _safe_trim(obj: Dict[str, Any]) -> Dict[str, Any]:
    s = json.dumps(obj, ensure_ascii=False, default=str)
    if len(s.encode("utf-8")) <= MAX_DETAIL_BYTES:
        return obj
    # Bei Übergröße nur sichere Minimalfelder zurückgeben
    return {
        "tenantId": obj.get("tenantId", "unknown"),
        "file": {
            "bucket": (obj.get("file") or {}).get("bucket"),
            "key":    (obj.get("file") or {}).get("key"),
            "filename": (obj.get("file") or {}).get("filename"),
        },
        "meta": (obj.get("meta") or {}),
        "analysis": {},  # gekappt
        "warnings": (obj.get("warnings") or []) + ["trimmed_payload"]
    }

def _build_payload(inp: Dict[str, Any]) -> Tuple[Dict[str, Any], List[str]]:
    warnings: List[str] = []

    tenant   = inp.get("tenantId") or inp.get("tenant_id") or "unknown"
    bucket   = inp.get("bucket") or (inp.get("file") or {}).get("bucket")
    key      = inp.get("key")    or (inp.get("file") or {}).get("key")
    cf_url   = inp.get("cf_url") or (inp.get("file") or {}).get("cf_url") or ""
    s3_url   = inp.get("s3_url") or (inp.get("file") or {}).get("s3_url") or (f"s3://{bucket}/{key}" if bucket and key else "")
    size     = inp.get("bytes")  or (inp.get("file") or {}).get("bytes")
    filename = (inp.get("file") or {}).get("filename") or _basename_from_key(key or "")

    meta     = inp.get("meta") or {}
    analysis = inp.get("analysis") or {}
    clients  = inp.get("clients") or DEFAULT_CLIENTS or ["*"]  # "*" = broadcast an alle

    if not bucket or not key:
        warnings.append("missing_bucket_or_key")

    msg = {
        "tenantId": tenant,
        "file": {
            "bucket": bucket,
            "key": key,
            "filename": filename,
            "bytes": size,
            "s3_url": s3_url,
            "cf_url": cf_url
        },
        "meta": {
            "subject": meta.get("subject", ""),
            "from": meta.get("from", ""),
            "to": meta.get("to", ""),
            "cc": meta.get("cc", "")
        },
        "analysis": {
            "summary": (analysis.get("summary")
                        or (analysis.get("bedrock", {}) or {}).get("summary")
                        or ((analysis.get("bedrock", {}) or {}).get("bedrock_json", {}) or {}).get("summary", "")),
            "intent":   analysis.get("intent")   or ((analysis.get("bedrock", {}) or {}).get("bedrock_json", {}) or {}).get("intent", ""),
            "priority": analysis.get("priority") or ((analysis.get("bedrock", {}) or {}).get("bedrock_json", {}) or {}).get("priority", ""),
            "entities": analysis.get("entities") or ((analysis.get("bedrock", {}) or {}).get("bedrock_json", {}) or {}).get("entities", []),
        },
        "clients": clients,
        "distributedAt": _now_ms()
    }
    return msg, warnings

def lambda_handler(event, context):
    try:
        data = _take_detail(event if isinstance(event, dict) else {})
        msg, warns = _build_payload(data)

        result = {
            "ok": True,
            "tenantId": msg["tenantId"],
            "file": msg["file"],
            "meta": msg["meta"],
            "analysis": msg["analysis"],
            "clients": msg["clients"],
            "sync": {
                "status": "pending",          # Lambda6 setzt später z. B. "stored" / "completed" / "failed"
                "deliveredTo": msg.get("clients", [])
            },
            "distributedAt": msg["distributedAt"],
            "warnings": warns
        }

        # Zu große Payloads sicher trimmen
        return _safe_trim(result)

    except Exception as e:
        if STRICT_MODE:
            raise
        return {"ok": False, "error": str(e)[:4000], "where": "lambda5"}
