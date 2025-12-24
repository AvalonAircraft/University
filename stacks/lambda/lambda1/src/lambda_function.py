# lambda_function.py
import os
import json
import re
from typing import Any, Dict, List, Optional, Tuple

# ----------------------------
# Konfiguration über Env-Vars
# ----------------------------
STRICT_VALIDATION = (os.getenv("STRICT_VALIDATION", "0") == "1")   # bei Fehlern Exception statt ok=False
REQUIRE_BEDROCK    = (os.getenv("REQUIRE_BEDROCK", "0") == "1")    # Bedrock-Ergebnis Pflicht?
TENANT_ALLOWLIST   = [t.strip().lower() for t in os.getenv("TENANT_ALLOWLIST", "").split(",") if t.strip()]
TENANT_BLOCKLIST   = [t.strip().lower() for t in os.getenv("TENANT_BLOCKLIST", "").split(",") if t.strip()]
# 'text' als Pflichtfeld standardmäßig mit aufnehmen
REQ_META_FIELDS    = [f.strip() for f in os.getenv("REQUIRE_META_FIELDS", "subject,from,to,text").split(",") if f.strip()]

# robust gegen leere/fehlende Werte
MAX_TEXT_LEN = int(os.getenv("MAX_TEXT_LEN", "20000") or "20000")  # harte Kappung, Schutz gegen Jumbo-Events

# ----------------------------
# Hilfsfunktionen
# ----------------------------
def _take_detail(event: Dict[str, Any]) -> Dict[str, Any]:
    """EventBridge-Envelope abstreifen, falls vorhanden."""
    if isinstance(event, dict) and "detail" in event and isinstance(event["detail"], dict):
        return event["detail"]
    return event

def _norm_tenant(d: Dict[str, Any]) -> Optional[str]:
    # akzeptiere tenantId oder tenant_id
    t = d.get("tenantId") or d.get("tenant_id")
    if isinstance(t, str):
        return t.strip()
    return None

def _validate_tenant(tenant: Optional[str]) -> Tuple[bool, List[str]]:
    errs: List[str] = []
    if not tenant:
        errs.append("tenant_missing")
        return False, errs

    tl = tenant.lower()
    if TENANT_BLOCKLIST and tl in TENANT_BLOCKLIST:
        errs.append(f"tenant_blocked:{tenant}")
    if TENANT_ALLOWLIST and tl not in TENANT_ALLOWLIST:
        errs.append(f"tenant_not_allowed:{tenant}")

    return (len(errs) == 0), errs

def _validate_meta(meta: Dict[str, Any]) -> List[str]:
    errs: List[str] = []
    for f in REQ_META_FIELDS:
        v = meta.get(f)
        if not isinstance(v, str) or not v.strip():
            errs.append(f"meta_missing:{f}")
    return errs

def _extract_bedrock(analysis: Dict[str, Any]) -> Dict[str, Any]:
    """
    Erwartetes Format:
    analysis.bedrock.bedrock_json = {
      "summary": "...",
      "intent": "...",
      "priority": "low|normal|high",
      "entities": [...]
    }
    """
    out = {"summary": "", "intent": "", "priority": "", "entities": []}
    try:
        br = analysis.get("bedrock", {})
        bj = br.get("bedrock_json", {})
        if isinstance(bj, dict):
            out["summary"]  = str(bj.get("summary", "") or "")[:MAX_TEXT_LEN]
            out["intent"]   = str(bj.get("intent", "") or "")
            out["priority"] = str(bj.get("priority", "") or "")
            ents = bj.get("entities", [])
            if isinstance(ents, list):
                out["entities"] = ents
    except Exception:
        # defensiv: leer lassen
        pass
    return out

def _pick_text_for_embedding(meta: Dict[str, Any], brx: Dict[str, Any]) -> str:
    """
    Priorität:
    1) Bedrock summary
    2) meta.text (falls vorhanden)
    3) meta.subject + from + to (fallback)
    """
    if brx.get("summary"):
        return brx["summary"][:MAX_TEXT_LEN]

    if isinstance(meta.get("text"), str) and meta["text"].strip():
        return meta["text"][:MAX_TEXT_LEN]

    subj = (meta.get("subject") or "").strip()
    frm  = (meta.get("from") or "").strip()
    to   = (meta.get("to") or "").strip()
    base = " | ".join([p for p in [subj, frm, to] if p])
    return base[:MAX_TEXT_LEN] if base else ""

# ----------------------------
# Lambda-Handler
# ----------------------------
def handler(event, context):
    """
    Erwartete Eingabe (über EventBridge -> Step Functions):
    - Weg A (Matched event als Ganzes): event enthält { detail:{ tenantId, meta, analysis, ... }, ... }
    - Weg B (Input-Transformer): event ist direkt { tenantId, meta, analysis, ... }

    Empfehlung für Step Functions:
    - Wenn du das gesamte EventBridge-Event übergibst, setze bei der Task "Payload.$": "$.detail"
    """
    original_event = event
    data = _take_detail(event)

    tenant     = _norm_tenant(data)
    meta       = data.get("meta") or {}
    analysis   = data.get("analysis") or {}
    s3info     = data.get("s3") or {}
    received_at = data.get("receivedAt") or data.get("received_at")

    errors: List[str] = []
    warnings: List[str] = []

    # 1) Tenant-Prüfung
    ok_tenant, tenant_errs = _validate_tenant(tenant)
    errors.extend(tenant_errs)

    # 2) Meta-Prüfung
    if not isinstance(meta, dict):
        errors.append("meta_invalid")
        meta = {}
    else:
        errors.extend(_validate_meta(meta))

    # 3) Bedrock-Pflicht (optional)
    brx = _extract_bedrock(analysis)
    if REQUIRE_BEDROCK and not brx.get("summary"):
        errors.append("bedrock_missing")

    # 4) Text für Embedding bestimmen
    text_for_embed = _pick_text_for_embedding(meta, brx)

    # 5) Validierungsergebnis
    ok = len(errors) == 0

    # meta.text (falls vorhanden) gekürzt durchreichen
    meta_text_out = ""
    if isinstance(meta.get("text"), str) and meta["text"].strip():
        meta_text_out = meta["text"][:MAX_TEXT_LEN]

    result: Dict[str, Any] = {
        "ok": ok,
        "validated": ok,
        "tenantId": tenant or "unknown",
        "receivedAt": received_at,
        "meta": {
            "subject": meta.get("subject", ""),
            "from": meta.get("from", ""),
            "to": meta.get("to", ""),
            "cc": meta.get("cc", ""),
            "attachments": meta.get("attachments", []),
            "text": meta_text_out,   # kompletter Inhalt (gekürzt)
        },
        "analysis": {
            "bedrock": {
                "summary": brx.get("summary", ""),
                "intent": brx.get("intent", ""),
                "priority": brx.get("priority", ""),
                "entities": brx.get("entities", []),
            }
        },
        "s3": s3info,
        "normalized": {
            "text_for_embedding": text_for_embed
        },
        "errors": errors,
        "warnings": warnings,
        "_debug": {
            "input_had_detail_wrapper": bool(isinstance(original_event, dict) and "detail" in original_event)
        }
    }

    # Bei stricter Validierung Lauf abbrechen (Step Functions-Task schlägt fehl -> greift Retry/Fehlerpfad)
    if not ok and STRICT_VALIDATION:
        raise Exception("validation_failed: " + ";".join(errors))

    return result

# Wichtig für AWS Lambda (Handler-Einstellung: lambda_function.lambda_handler)
lambda_handler = handler
