# lambda_function.py
import os
import json
import time
from datetime import datetime
from typing import Any, Dict, Tuple, List, Optional

import boto3
from botocore.exceptions import ClientError

# ----------------------------
# Konfiguration über Env-Vars
# ----------------------------
OUTPUT_BUCKET         = os.getenv("OUTPUT_BUCKET")
PDF_TENANT_SUBFOLDER  = os.getenv("PDF_TENANT_SUBFOLDER", "KI_Results")  # z. B. "KI_Results"
ROOT_PREFIX           = os.getenv("ROOT_PREFIX", "")                      # optional: z.B. "email-artifacts"
CF_DOMAIN             = os.getenv("CF_DOMAIN")                            # z. B. "www.miraedrive.com"
KMS_KEY_ID            = os.getenv("KMS_KEY_ID")                           # optional: KMS-Key für SSE

# Fixer Root-Ordner für Tenants
TENANTS_ROOT_DIR      = "tenants"

# Index/URL-Optionen
ROLLING_LIMIT         = int(os.getenv("KI_RESULTS_ROLLING_LIMIT", "200"))
PRESIGN_EXPIRES       = int(os.getenv("PRESIGN_EXPIRES", "600"))
USE_PRESIGNED_URL     = os.getenv("USE_PRESIGNED", "0") == "1"  # 1 = S3 presigned statt CF-Domain

s3 = boto3.client("s3")

# ----------------------------
# Utilities
# ----------------------------
def _get(d: Dict[str, Any], dotted: str, default: Any = None) -> Any:
    cur = d
    for part in dotted.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return default
    return cur

def _take_detail(event: Dict[str, Any]) -> Dict[str, Any]:
    """EventBridge-Envelope abstreifen, falls vorhanden."""
    if isinstance(event, dict) and "detail" in event and isinstance(event["detail"], dict):
        return event["detail"]
    return event

def _safe_name(s: str, max_len: int = 60) -> str:
    # Nur alnum, '-', '_' erlauben; Rest entfernen
    keep = []
    for ch in s:
        if ch.isalnum() or ch in "-_":
            keep.append(ch)
    name = "".join(keep).strip()
    if not name:
        name = "email"
    return name[:max_len]

def _to_pdf_ascii(s: str) -> str:
    # PDF-Standardfont (Helvetica) ist Latin-1: non-latin1 Zeichen ersetzen
    return s.encode("latin-1", "replace").decode("latin-1")

def _split_lines(s: str, width: int = 95) -> List[str]:
    out, cur = [], ""
    for word in s.split():
        if len(cur) + len(word) + 1 > width:
            out.append(cur.rstrip())
            cur = word + " "
        else:
            cur += word + " "
    if cur.strip():
        out.append(cur.rstrip())
    return out or [""]

# ----------------------------
# Minimaler PDF-Generator
# ----------------------------
def _make_pdf_bytes(title: str, fields: Dict[str, str], body: str) -> bytes:
    """
    Erzeugt eine einfache PDF-Seite mit Titel + Key/Value Feldern + Body-Text.
    Ohne externe Libs, nur ein einfacher PDF-Stream.
    """
    # Inhalte vorbereiten (ASCII/Latin-1)
    title = _to_pdf_ascii(title or "Email Analysis")
    lines: List[str] = []
    for k, v in fields.items():
        v = _to_pdf_ascii(v or "")
        for i, seg in enumerate(_split_lines(v, 100)):
            prefix = f"{k}: " if i == 0 else "    "
            lines.append(prefix + seg)
    if body:
        body = _to_pdf_ascii(body)
        lines.append("")  # Leerzeile
        lines.append("Body:")
        lines.extend(_split_lines(body, 100))

    # Escape für PDF-Textobjekt
    def esc(s: str) -> str:
        return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

    # Seitengeometrie
    width, height = 612, 792  # Letter
    start_y = height - 72
    lh_title = 20

    # Text-Stream bauen
    content_lines = []
    content_lines.append("BT")
    content_lines.append("/F1 18 Tf")
    content_lines.append(f"72 {start_y} Td")
    content_lines.append(f"({esc(title)}) Tj")
    y = start_y - (lh_title + 10)

    content_lines.append("ET")
    content_lines.append("BT")
    content_lines.append("/F1 10 Tf")
    content_lines.append("12 TL")                 # Leading setzen
    content_lines.append(f"72 {y} Td")

    # Zeilen schreiben
    for i, ln in enumerate(lines):
        if i == 0:
            content_lines.append(f"({esc(ln)}) Tj")
        else:
            content_lines.append("T*")
            content_lines.append(f"({esc(ln)}) Tj")

    content_lines.append("ET")

    content_stream = ("\n".join(content_lines) + "\n").encode("latin-1", "replace")
    stream_len = len(content_stream)

    # PDF-Objekte bauen
    pdf_parts: List[bytes] = []
    xref_offsets: List[int] = []

    def w(b: bytes):
        pdf_parts.append(b)

    def mark():
        xref_offsets.append(sum(len(p) for p in pdf_parts))

    w(b"%PDF-1.4\n%\xE2\xE3\xCF\xD3\n")

    # 1: Catalog
    mark()
    w(b"1 0 obj\n")
    w(b"<< /Type /Catalog /Pages 2 0 R >>\n")
    w(b"endobj\n")

    # 2: Pages
    mark()
    w(b"2 0 obj\n")
    w(b"<< /Type /Pages /Count 1 /Kids [3 0 R] >>\n")
    w(b"endobj\n")

    # 3: Page (vor Font/Contents schreiben, damit XRef-Reihenfolge 1..5 ist)
    mark()
    w(b"3 0 obj\n")
    w(b"<< /Type /Page /Parent 2 0 R ")
    w(f"/MediaBox [0 0 {width} {height}] ".encode("ascii"))
    w(b"/Resources << /Font << /F1 4 0 R >> >> ")
    w(b"/Contents 5 0 R >>\n")
    w(b"endobj\n")

    # 4: Font
    mark()
    w(b"4 0 obj\n")
    w(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n")
    w(b"endobj\n")

    # 5: Contents
    mark()
    w(b"5 0 obj\n")
    w(f"<< /Length {stream_len} >>\n".encode("ascii"))
    w(b"stream\n")
    w(content_stream)
    w(b"endstream\n")
    w(b"endobj\n")

    # xref
    xref_start = sum(len(p) for p in pdf_parts)
    w(b"xref\n")
    w(b"0 6\n")
    w(b"0000000000 65535 f \n")
    for off in xref_offsets:
        w(f"{off:010d} 00000 n \n".encode("ascii"))

    # Trailer
    w(b"trailer\n")
    w(b"<< /Size 6 /Root 1 0 R >>\n")
    w(b"startxref\n")
    w(f"{xref_start}\n".encode("ascii"))
    w(b"%%EOF\n")

    return b"".join(pdf_parts)

# ----------------------------
# Index-/URL-Helfer
# ----------------------------
def _json_get(bucket: str, key: str) -> dict:
    try:
        obj = s3.get_object(Bucket=bucket, Key=key)
        return json.loads(obj["Body"].read())
    except ClientError as e:
        if e.response.get("Error", {}).get("Code") in ("NoSuchKey", "404"):
            return {}
        raise

def _json_put(bucket: str, key: str, doc: dict):
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode("utf-8"),
        ContentType="application/json",
        CacheControl="no-store, must-revalidate"   # damit das Dashboard sofort die Änderung sieht
    )

def _basename(key: str) -> str:
    import urllib.parse
    return urllib.parse.unquote(key.rsplit("/", 1)[-1]) if key else ""

def _head(bucket: str, key: str) -> dict:
    try:
        r = s3.head_object(Bucket=bucket, Key=key)
        return {"size": r.get("ContentLength"), "contentType": r.get("ContentType")}
    except ClientError:
        return {}

def _cf_url_for(key: str) -> str:
    return f"https://{CF_DOMAIN}/{key}" if CF_DOMAIN else ""

def _s3_presigned_for(bucket: str, key: str, expires: int = PRESIGN_EXPIRES) -> str:
    return s3.generate_presigned_url("get_object", Params={"Bucket": bucket, "Key": key}, ExpiresIn=expires)

def _ymd_from_key(key: str) -> Tuple[str, str, str]:
    parts = key.split("/")
    i = parts.index(PDF_TENANT_SUBFOLDER)  # .../KI_Results/YYYY/MM/DD/...
    return parts[i+1], parts[i+2], parts[i+3]

def _update_ki_results_indexes(*, tenant_id: str, out_bucket: str, file_key: str,
                               title: Optional[str] = None, size: Optional[int] = None,
                               content_type: Optional[str] = None,
                               created_at_iso: Optional[str] = None,
                               direct_cf_url: Optional[str] = None) -> None:
    """Hängt die frisch hochgeladene Datei an files.json + Tagesindex an."""
    # Metadaten ergänzen
    if size is None or content_type is None:
        meta = _head(out_bucket, file_key)
        size = size if size is not None else meta.get("size")
        content_type = content_type or meta.get("contentType") or "application/pdf"

    url = direct_cf_url or (_cf_url_for(file_key) if not USE_PRESIGNED_URL else _s3_presigned_for(out_bucket, file_key))
    now_iso = created_at_iso or datetime.utcnow().isoformat() + "Z"

    item = {
        "title": title or _basename(file_key),
        "s3Key": file_key,
        "url": url,
        "size": size,
        "contentType": content_type,
        "createdAt": now_iso
    }

    # 1) Rolling: tenants/<tenant>/KI_Results/files.json
    rolling_key = f"{TENANTS_ROOT_DIR}/{tenant_id}/{PDF_TENANT_SUBFOLDER}/files.json"
    rolling = _json_get(out_bucket, rolling_key) or {"items": []}
    rolling["items"] = [item] + (rolling.get("items") or [])
    rolling["items"] = rolling["items"][:ROLLING_LIMIT]
    rolling["updatedAt"] = now_iso
    _json_put(out_bucket, rolling_key, rolling)

    # 2) Daily: tenants/<tenant>/KI_Results/YYYY/MM/DD/index.json
    y, m, d = _ymd_from_key(file_key)
    daily_key = f"{TENANTS_ROOT_DIR}/{tenant_id}/{PDF_TENANT_SUBFOLDER}/{y}/{m}/{d}/index.json"
    daily = _json_get(out_bucket, daily_key) or {"date": f"{y}-{m}-{d}", "items": []}
    daily["items"] = [item] + (daily.get("items") or [])
    _json_put(out_bucket, daily_key, daily)

# ----------------------------
# S3-Key bestimmen
# ----------------------------
def _choose_bucket_and_key(data: Dict[str, Any]) -> Tuple[str, str]:
    """
    Zielpfad:
      [ROOT_PREFIX/]<tenants>/<tenantId>/<PDF_TENANT_SUBFOLDER>/<YYYY>/<MM>/<DD>/<ts>_<subject>.pdf
    """
    tenant = (data.get("tenantId") or data.get("tenant_id") or "unknown").strip()
    subject = str(_get(data, "meta.subject", "") or "").strip()
    safe_subject = _safe_name(subject)
    ts_dir = datetime.utcnow().strftime("%Y/%m/%d")
    filename = f"{int(time.time()*1000)}_{safe_subject}.pdf"

    parts = []
    if ROOT_PREFIX:
        parts.append(ROOT_PREFIX.strip("/"))
    # immer unter tenants/{tenantId}/KI_Results/...
    parts.append(TENANTS_ROOT_DIR)
    parts.append(tenant)
    parts.append(PDF_TENANT_SUBFOLDER)
    parts.append(ts_dir)

    key = "/".join(parts) + "/" + filename

    bucket = OUTPUT_BUCKET or _get(data, "s3.bucket")
    if not bucket:
        raise RuntimeError("No OUTPUT_BUCKET set and no detail.s3.bucket provided.")
    return bucket, key

# ----------------------------
# Lambda-Handler
# ----------------------------
def lambda_handler(event, context):
    """
    Erwartete Eingabe:
      - Entweder direkt { tenantId, meta, analysis, ... }
      - Oder EventBridge-Wrapper { detail: { ... } }

    Verwendete Felder:
      - tenantId
      - meta.subject|from|to|cc|text (text optional)
      - analysis.bedrock.bedrock_json.summary|intent|priority|entities (optional)
      - s3.bucket (optional, falls OUTPUT_BUCKET nicht gesetzt ist)
    """
    try:
        data = _take_detail(event)
        tenant = (data.get("tenantId") or data.get("tenant_id") or "unknown").strip()
        meta: Dict[str, Any] = data.get("meta") or {}
        analysis: Dict[str, Any] = data.get("analysis") or {}

        bedrock_json: Dict[str, Any] = _get(analysis, "bedrock.bedrock_json", {}) or {}
        summary  = str(bedrock_json.get("summary", "") or "")
        intent   = str(bedrock_json.get("intent", "") or "")
        priority = str(bedrock_json.get("priority", "") or "")
        entities = bedrock_json.get("entities", [])

        # Text-Kandidat für Body: bevorzugt meta.text (falls vorhanden), sonst summary
        meta_text = str(meta.get("text", "") or "")
        body_text = meta_text.strip() or summary

        # Titel & Felder fürs PDF
        title = meta.get("subject") or "Email Analysis"
        fields = {
            "Tenant": tenant,
            "Subject": meta.get("subject", "") or "",
            "From": meta.get("from", "") or "",
            "To": meta.get("to", "") or "",
            "CC": meta.get("cc", "") or "",
            "Summary": summary,
            "Intent": intent,
            "Priority": priority,
        }
        if isinstance(entities, list) and entities:
            try:
                fields["Entities"] = ", ".join(
                    [e if isinstance(e, str) else (e.get("Text") or e.get("text") or "") for e in entities]
                )
            except Exception:
                pass

        pdf_bytes = _make_pdf_bytes(title=title, fields=fields, body=body_text)

        bucket, key = _choose_bucket_and_key(data)

        put_kwargs: Dict[str, Any] = {
            "Bucket": bucket,
            "Key": key,
            "Body": pdf_bytes,
            "ContentType": "application/pdf",
        }
        if KMS_KEY_ID:
            put_kwargs["ServerSideEncryption"] = "aws:kms"
            put_kwargs["SSEKMSKeyId"] = KMS_KEY_ID

        # PDF hochladen
        s3.put_object(**put_kwargs)
        print(f"[pdf-upload] key={key} bytes={len(pdf_bytes)}")

        # URLs
        s3_url = f"s3://{bucket}/{key}"
        cf_url = f"https://{CF_DOMAIN}/{key}" if CF_DOMAIN else None

        # Indexdateien aktualisieren (nicht hart failen, damit Haupt-Flow liefert)
        try:
            _update_ki_results_indexes(
                tenant_id=tenant,
                out_bucket=bucket,
                file_key=key,
                title=_basename(key),
                size=len(pdf_bytes),                 # optional; sonst via head geholt
                content_type="application/pdf",
                created_at_iso=datetime.utcnow().isoformat() + "Z",
                direct_cf_url=cf_url
            )
        except Exception as idx_e:
            print("[index update failed]", str(idx_e)[:200])

        return {
            "ok": True,
            "tenantId": tenant,
            "bucket": bucket,
            "key": key,
            "bytes": len(pdf_bytes),
            "s3_url": s3_url,
            "cf_url": cf_url,
            "meta": {
                "subject": meta.get("subject", ""),
                "from": meta.get("from", ""),
                "to": meta.get("to", ""),
                "cc": meta.get("cc", ""),
            },
            "analysis": {
                "intent": intent,
                "priority": priority,
                "summary_len": len(summary),
                "entities_count": len(entities) if isinstance(entities, list) else 0,
            }
        }

    except ClientError as ce:
        return {"ok": False, "error": f"AWS error: {str(ce)}"}
    except Exception as e:
        return {"ok": False, "error": str(e)}
