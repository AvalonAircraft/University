import os
import json
from typing import Any, Dict
import boto3
from botocore.config import Config

# Kurze Timeouts + wenige Retries (hängt nicht fest, wenn Endpoint fehlt)
_BOTO_CFG = Config(connect_timeout=2, read_timeout=5, retries={'max_attempts': 2})

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
EMBED_MODEL = os.getenv("BEDROCK_EMBED_MODEL_ID", "amazon.titan-embed-text-v2:0")

bedrock = boto3.client("bedrock-runtime", region_name=AWS_REGION, config=_BOTO_CFG)

def _take_detail(evt: Dict[str, Any]) -> Dict[str, Any]:
    if isinstance(evt, dict) and isinstance(evt.get("detail"), dict):
        return evt["detail"]
    return evt

def _pick_text(evt: Dict[str, Any]) -> str:
    """
    Bevorzugt den von Lambda1 vorbereiteten Text:
      detail.normalized.text_for_embedding
    Fallbacks: analysis.bedrock.summary -> meta.text -> meta.subject/from/to
    """
    d = _take_detail(evt)
    norm = d.get("normalized", {}) if isinstance(d, dict) else {}
    txt = (norm.get("text_for_embedding") or "").strip()
    if txt:
        return txt

    # Fallbacks für direkte Tests ohne Lambda1
    analysis = d.get("analysis", {}) if isinstance(d, dict) else {}
    bedrock_json = analysis.get("bedrock", {}).get("bedrock_json", {})
    if isinstance(bedrock_json, dict):
        s = (bedrock_json.get("summary") or "").strip()
        if s:
            return s

    meta = d.get("meta", {}) if isinstance(d, dict) else {}
    if isinstance(meta.get("text"), str) and meta["text"].strip():
        return meta["text"].strip()

    subj = (meta.get("subject") or "").strip()
    frm  = (meta.get("from") or "").strip()
    to   = (meta.get("to") or "").strip()
    base = " | ".join([p for p in [subj, frm, to] if p])
    return base

def _embed_titan(text: str) -> Dict[str, Any]:
    body = {"inputText": text}
    resp = bedrock.invoke_model(modelId=EMBED_MODEL, body=json.dumps(body))
    payload = json.loads(resp["body"].read())
    # Titan liefert {"embedding":[...]}
    vec = payload.get("embedding") or []
    return {"vector": vec, "dim": len(vec), "raw": payload}

def _embed_cohere(text: str) -> Dict[str, Any]:
    body = {"texts": [text], "input_type": "search_document"}
    resp = bedrock.invoke_model(modelId=EMBED_MODEL, body=json.dumps(body))
    payload = json.loads(resp["body"].read())
    # Cohere liefert {"embeddings":[[...]]}
    arr = payload.get("embeddings") or []
    vec = arr[0] if arr and isinstance(arr[0], list) else []
    return {"vector": vec, "dim": len(vec), "raw": payload}

def _embed(text: str) -> Dict[str, Any]:
    mid = EMBED_MODEL.lower()
    if "titan-embed-text" in mid:
        return _embed_titan(text)
    if "cohere.embed" in mid:
        return _embed_cohere(text)
    # Default: versuche Titan
    return _embed_titan(text)

def lambda_handler(event, context):
    d = _take_detail(event)
    tenant = (d.get("tenantId") or d.get("tenant_id") or "unknown")

    text = _pick_text(event)
    if not text:
        return {
            "ok": False,
            "tenantId": tenant,
            "error": "no_text_for_embedding",
            "model": EMBED_MODEL
        }

    try:
        out = _embed(text)
        return {
            "ok": True,
            "tenantId": tenant,
            "model": EMBED_MODEL,
            "embedding": {
                "dim": out["dim"],
                "vector": out["vector"]  # groß! In Prod evtl. nicht loggen
            },
            "source": {
                "text": text[:5000]  # für Debug/Tracing begrenzen
            }
        }
    except Exception as e:
        return {
            "ok": False,
            "tenantId": tenant,
            "model": EMBED_MODEL,
            "error": str(e)
        }
