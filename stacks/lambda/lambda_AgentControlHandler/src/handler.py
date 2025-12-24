import base64
import boto3
import json
import os
import re
import time
from typing import Any, Dict, Tuple, List, Optional
from email import policy
from email.parser import BytesParser
from email.message import EmailMessage

import urllib3
from urllib3.util import Retry

# --- CONNECTIVITY DEBUG ---
import socket, ssl

def _connectivity_check(hostname: str, port: int, path: str = "/health", scheme: str = "http") -> dict:
    """
    Prüft DNS(v4)->TCP->(optional TLS)->(optional) HTTP-Response-Line.
    scheme = "http" oder "https"
    """
    res = {"host": hostname, "port": port, "scheme": scheme, "steps": []}
    try:
        addrs = socket.getaddrinfo(hostname, port, family=socket.AF_INET, type=socket.SOCK_STREAM)
        v4_list = list({a[4][0] for a in addrs})
        res["steps"].append({"dns_ok": True, "resolved_v4": v4_list})
    except Exception as e:
        res["steps"].append({"dns_ok": False, "error": str(e)})
        return res

    try:
        ip = addrs[0][4]  # (addr, port)
        sock = socket.create_connection(ip, timeout=5)
        res["steps"].append({"tcp_ok": True, "ip": ip[0]})
    except Exception as e:
        res["steps"].append({"tcp_ok": False, "error": str(e)})
        return res

    try:
        if scheme.lower() == "https":
            ctx = ssl.create_default_context()
            conn = ctx.wrap_socket(sock, server_hostname=hostname)
            res["steps"].append({"tls_ok": True, "cipher": conn.cipher()})
        else:
            conn = sock  # plain TCP

        # Minimaler HTTP-GET (falls dein Service /health oder / bedient)
        conn.settimeout(5)
        req = f"GET {path} HTTP/1.1\r\nHost: {hostname}\r\nConnection: close\r\n\r\n"
        conn.sendall(req.encode())
        first = conn.recv(128)
        first_line = first.split(b"\r\n", 1)[0].decode("latin1", "ignore")
        res["steps"].append({"http_probe": first_line})
        conn.close()
    except Exception as e:
        res["steps"].append({"http_or_tls_error": str(e)})
    return res
# --- END CONNECTIVITY DEBUG ---

s3 = boto3.client("s3")
secrets = boto3.client("secretsmanager")
ssm = boto3.client("ssm")

# -------- Konfiguration über Umgebungsvariablen --------
DEFAULT_NLB_HOST = os.getenv("DEFAULT_NLB_HOST", "")        # z.B. "nlb-xyz.elb..amazonaws.com:8080"
DEFAULT_NLB_PATH = os.getenv("DEFAULT_NLB_PATH", "/ingest/email")
NLB_SCHEME       = os.getenv("NLB_SCHEME", "http")          # "http" oder "https"
# Falls Host keinen :port enthält, fällt auf diesen Wert zurück:
try:
    NLB_PORT = int(os.getenv("NLB_PORT", "0") or "0")
except ValueError:
    NLB_PORT = 0

TENANT_SECRET_NAME = os.getenv("TENANT_SECRET_NAME", "")
TENANT_PARAM_PREFIX = os.getenv("TENANT_PARAM_PREFIX", "")

# --- Force urllib3 to use IPv4 sockets only ---
import urllib3.util.connection as urllib3_connection
def _ipv4_only():
    return socket.AF_INET
urllib3_connection.allowed_gai_family = _ipv4_only
# --- end force IPv4 ---

# HTTP Pool mit Retry/Backoff
http = urllib3.PoolManager(
    timeout=urllib3.Timeout(connect=5.0, read=30.0),
    retries=Retry(
        total=3,
        connect=3,
        read=1,
        backoff_factor=0.6,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=frozenset(["GET", "POST", "PUT"])
    ),
)

def _b2s(b: Optional[bytes]) -> str:
    return b.decode("utf-8", errors="replace") if b is not None else ""

def _load_raw_email(bucket: str, key: str) -> bytes:
    resp = s3.get_object(Bucket=bucket, Key=key)
    return resp["Body"].read()

def _parse_email(raw: bytes) -> Tuple[EmailMessage, Dict[str, Any]]:
    msg: EmailMessage = BytesParser(policy=policy.default).parsebytes(raw)

    headers = {k: v for (k, v) in msg.items()}

    text_plain_parts: List[str] = []
    text_html_parts: List[str] = []

    if msg.is_multipart():
        for part in msg.walk():
            ctype = part.get_content_type()
            disp = (part.get("Content-Disposition") or "").lower()
            if ctype == "text/plain" and "attachment" not in disp:
                try:
                    text_plain_parts.append(part.get_content())
                except Exception:
                    text_plain_parts.append(part.get_payload(decode=True).decode("utf-8", errors="replace"))
            elif ctype == "text/html" and "attachment" not in disp:
                try:
                    text_html_parts.append(part.get_content())
                except Exception:
                    text_html_parts.append(part.get_payload(decode=True).decode("utf-8", errors="replace"))
    else:
        ctype = msg.get_content_type()
        if ctype == "text/plain":
            text_plain_parts.append(msg.get_content())
        elif ctype == "text/html":
            text_html_parts.append(msg.get_content())

    text_plain = "\n\n".join([t for t in text_plain_parts if t])
    text_html = "\n\n".join([t for t in text_html_parts if t])

    attachments_meta = []
    for part in msg.iter_attachments():
        filename = part.get_filename() or "attachment"
        ctype = part.get_content_type()
        payload = part.get_payload(decode=True) or b""
        size = len(payload)
        attachments_meta.append({
            "filename": filename,
            "content_type": ctype,
            "size_bytes": size,
        })

    parsed = {
        "headers": headers,
        "subject": headers.get("Subject", ""),
        "from": headers.get("From", ""),
        "to": headers.get("To", ""),
        "cc": headers.get("Cc", ""),
        "date": headers.get("Date", ""),
        "text": text_plain,
        "html": text_html,
        "attachments": attachments_meta,
    }
    return msg, parsed

def _resolve_auth_for_tenant(tenant_id: str, routing: Dict[str, Any]) -> Dict[str, str]:
    # 1) Direkt aus routing
    if routing and isinstance(routing.get("auth_headers"), dict):
        return {str(k): str(v) for k, v in routing["auth_headers"].items()}

    headers: Dict[str, str] = {}
    # 2) Secrets Manager (JSON dict erwartet)
    if TENANT_SECRET_NAME:
        try:
            sec = secrets.get_secret_value(SecretId=TENANT_SECRET_NAME)
            blob = sec.get("SecretString") or base64.b64decode(sec.get("SecretBinary", b"")).decode("utf-8")
            data = json.loads(blob)
            if tenant_id in data and isinstance(data[tenant_id], dict):
                for k, v in data[tenant_id].items():
                    headers[str(k)] = str(v)
                return headers
        except Exception:
            pass

    # 3) SSM Parameter (z.B. /agent/tenants/<tenant>/auth_header)
    if TENANT_PARAM_PREFIX:
        try:
            p = ssm.get_parameters(
                Names=[f"{TENANT_PARAM_PREFIX}/{tenant_id}/auth_header"],
                WithDecryption=True
            )
            for prm in p.get("Parameters", []):
                if prm["Name"].endswith("/auth_header"):
                    hv = prm["Value"]
                    m = re.match(r"^\s*([^:]+)\s*:\s*(.+)$", hv)
                    if m:
                        headers[m.group(1).strip()] = m.group(2).strip()
                        return headers
        except Exception:
            pass

    return headers

def _split_host_port(h: str, default_port: int) -> Tuple[str, int]:
    """Zerlegt 'host[:port]' in (hostname, port)."""
    if not h:
        raise RuntimeError("NLB-Host ist leer.")
    if ":" in h:
        hostpart, p = h.rsplit(":", 1)
        try:
            return hostpart, int(p)
        except ValueError:
            return hostpart, default_port
    return h, default_port

def _nlb_target(routing: Dict[str, Any]) -> Tuple[str, str, str, int]:
    """
    Bestimmt Hostname (ohne Port), Path, Scheme, Port für den NLB-Aufruf.
    Priorität: routing.* -> Env -> Host:Port -> Defaults
    """
    scheme = (routing.get("scheme") or NLB_SCHEME or "http").lower()
    path = (routing.get("nlb_path") or routing.get("path") or DEFAULT_NLB_PATH or "/")
    raw_host = (routing.get("nlb_host") or routing.get("host") or DEFAULT_NLB_HOST or "")
    # Port-Default je Scheme:
    scheme_default = 443 if scheme == "https" else 80

    # Portquellen: routing.port -> env NLB_PORT -> parse host:port -> default nach Scheme
    port = 0
    if isinstance(routing.get("port"), int):
        port = routing["port"]
    elif NLB_PORT:
        port = NLB_PORT

    if not raw_host and not port:
        raise RuntimeError("Kein NLB-Host konfiguriert (routing.nlb_host/host oder DEFAULT_NLB_HOST).")

    host_only, parsed_port = _split_host_port(raw_host, scheme_default)
    if not port:
        port = parsed_port

    if not path.startswith("/"):
        path = "/" + path

    return host_only, path, scheme, int(port)

def _post_to_nlb(hostname: str, port: int, path: str, scheme: str,
                 payload: Dict[str, Any], extra_headers: Dict[str, str]) -> Tuple[int, str]:
    # Bei nicht-Standard-Ports explizit mit :port in der URL arbeiten
    default_port = 443 if scheme == "https" else 80
    host_for_url = f"{hostname}:{port}" if port and port != default_port else hostname
    url = f"{scheme}://{host_for_url}{path}"

    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        # Host-Header ohne Port ist i.d.R. ok; für SNI bei HTTPS genügt server_hostname im TLS-Client.
        "Host": hostname,
    }
    headers.update(extra_headers or {})

    encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    print(f"[POST] url={url} bytes={len(encoded)} headers={list(headers.keys())}")

    resp = http.request(
        "POST",
        url,
        body=encoded,
        headers=headers,
        preload_content=True
    )
    body_text = resp.data.decode("utf-8", errors="replace") if resp.data else ""
    print(f"[POST] status={resp.status} len={len(body_text)}")
    return int(resp.status), body_text

def handler(event, context):
    """
    Erwartetes Event:
    {
      "tenantId": "...",
      "bucket": "...",
      "key": "tenants/<id>/emails/xxx.eml",
      "routing": {
         "nlb_host": "...elb.amazonaws.com[:port]",
         "nlb_path": "/ingest/email",
         "scheme": "http"|"https",
         "port": 8080,
         "auth_headers": {"Authorization":"Bearer <token>"}   # optional
      }
    }
    """
    start = time.time()
    tenant_id = event.get("tenantId") or event.get("tenant_id")
    bucket = event.get("bucket")
    key = event.get("key")
    routing = event.get("routing") or {}

    if not tenant_id or not bucket or not key:
        raise ValueError("tenantId, bucket und key müssen gesetzt sein.")

    # 2) Ziel bestimmen + Auth ermitteln (VOR dem S3-Load, damit wir Konnektivität früh testen können)
    hostname, path, scheme, port = _nlb_target(routing)
    auth_headers = _resolve_auth_for_tenant(tenant_id, routing)

    # --- CONNECTIVITY DEBUG CALL (vor S3/POST) ---
    dbg = _connectivity_check(hostname, port, "/health", scheme)
    print("[connectivity]", json.dumps(dbg))
    for step in dbg.get("steps", []):
        if step.get("dns_ok") is False or step.get("tcp_ok") is False:
            return {
                "ok": False,
                "stage": "preflight",
                "nlb_host": f"{hostname}:{port}",
                "path": path,
                "connectivity": dbg
            }
    # --- END CONNECTIVITY DEBUG CALL ---

    # 1) Lade & parse E-Mail (JETZT erst)
    raw = _load_raw_email(bucket, key)
    _, parsed = _parse_email(raw)

    # 3) Payload
    to_fargate = {
        "tenantId": tenant_id,
        "s3": {"bucket": bucket, "key": key},
        "email": {
            "meta": parsed,
            "raw_base64": base64.b64encode(raw).decode("ascii")
        },
        "receivedAt": int(time.time() * 1000)
    }

    # 4) POST zum NLB → ECS/Fargate
    status_code, body_text = _post_to_nlb(hostname, port, path, scheme, to_fargate, auth_headers)

    # 5) Antwort
    elapsed_ms = int((time.time() - start) * 1000)
    return {
        "ok": 200 <= status_code < 300,
        "http_status": status_code,
        "nlb_host": f"{hostname}:{port}",
        "path": path,
        "elapsed_ms": elapsed_ms,
        "tenantId": tenant_id,
        "email_summary": {
            "subject": parsed.get("subject", ""),
            "from": parsed.get("from", ""),
            "to": parsed.get("to", ""),
            "has_html": bool(parsed.get("html")),
            "has_text": bool(parsed.get("text")),
            "attachments_count": len(parsed.get("attachments", [])),
        },
        "service_reply_sample": body_text[:2048]
    }
