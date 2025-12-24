import os, json, logging
from typing import Optional, Dict, Any, Tuple
import boto3, pymysql

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ----------------------------
# Umgebung / Konfiguration
# ----------------------------
REGION = os.environ.get("REGION") or os.environ.get("AWS_REGION") or "us-east-1"
DB_HOST = os.environ["DB_HOST"]
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
META_DB_NAME = os.environ.get("META_DB_NAME", "miraedrive_db")
META_DB_USER = os.environ["META_DB_USER"]             # z.B. app_meta_user (IAM)
TENANT_SCHEMA_PREFIX = os.environ.get("TENANT_SCHEMA_PREFIX", "tenant_")
TENANT_DB_USER_TEMPLATE = os.environ.get("TENANT_DB_USER_TEMPLATE", "tenant_{tenant_id}_app")
CA_PATH = os.environ.get("RDS_CA_PATH", "/opt/python/rds-combined-ca-bundle.pem")
CONNECT_TIMEOUT = int(os.environ.get("CONNECT_TIMEOUT", "5"))
READ_TIMEOUT = int(os.environ.get("READ_TIMEOUT", "5"))
WRITE_TIMEOUT = int(os.environ.get("WRITE_TIMEOUT", "5"))
S3_BUCKET = os.environ.get("S3_BUCKET", "my-tenant-ingest-bucket")
S3_PREFIX_TEMPLATE = os.environ.get("S3_PREFIX_TEMPLATE", "tenants/{tenant_id}/emails/")
SES_IDENTITY_PREFIX = os.environ.get("SES_IDENTITY_PREFIX", "tenant-")

# Neu: Einstellungen für Write-/Update-Pfad
TARGET_TABLE = os.environ.get("TARGET_TABLE", "file_sync")
AUTO_MIGRATE = os.environ.get("AUTO_MIGRATE", "0") == "1"  # default AUS, da Tabelle existiert

RDS_CLIENT = boto3.client("rds", region_name=REGION)

# ----------------------------
# Utils (bestehend)
# ----------------------------
def _parse_email(event: Dict[str, Any]) -> Optional[str]:
    if not event:
        return None
    if event.get("email"):
        return str(event["email"]).strip()
    if event.get("body"):
        try:
            data = json.loads(event["body"])
            if isinstance(data, dict) and data.get("email"):
                return str(data["email"]).strip()
        except Exception:
            pass
    return None

# Debug-Helfer
import hashlib
def _debug_fs():
    path = CA_PATH  # /opt/python/rds-combined-ca-bundle.pem
    try:
        exists = os.path.exists(path)
        size = os.path.getsize(path) if exists else -1
        h = ""
        if exists:
            with open(path, "rb") as f:
                h = hashlib.sha256(f.read(2048)).hexdigest()
        logger.info(f"[TLS DEBUG] CA_PATH={path} exists={exists} size={size} sha256(head)={h}")
        try:
            logger.info(f"[TLS DEBUG] /opt content: {os.listdir('/opt')}")
            logger.info(f"[TLS DEBUG] /opt/python content (first 20): {os.listdir('/opt/python')[:20]}")
        except Exception:
            pass
    except Exception as e:
        logger.exception(f"[TLS DEBUG] FS check failed: {e}")

def _token(user: str) -> str:
    return RDS_CLIENT.generate_db_auth_token(
        DBHostname=DB_HOST, Port=DB_PORT, DBUsername=user, Region=REGION
    )

def _conn(user: str, database: Optional[str]):
    return pymysql.connect(
        host=DB_HOST,
        user=user,
        password=_token(user),
        database=database,
        port=DB_PORT,
        ssl={"ca": CA_PATH},
        connect_timeout=CONNECT_TIMEOUT,
        read_timeout=READ_TIMEOUT,
        write_timeout=WRITE_TIMEOUT,
        charset="utf8mb4",
        autocommit=True,
    )

def _resolve_tenant(meta_conn, email: str) -> Optional[Tuple[str, str, str]]:
    email_norm = email.strip().lower()
    with meta_conn.cursor() as cur:
        cur.execute(f"USE `{META_DB_NAME}`;")
        cur.execute("""
            SELECT tenant_id, email, '' as name
            FROM tenants
            WHERE LOWER(email) = %s
            LIMIT 1
        """, (email_norm,))
        row = cur.fetchone()
        if not row:
            return None
        return str(row[0]), str(row[1]), ""  # (tenant_id, email, name)

# ----------------------------
# Helpers für EventBridge/StepFunctions-Wrapper
# ----------------------------
def _take_detail(e: Dict[str, Any]) -> Dict[str, Any]:
    if isinstance(e, dict) and isinstance(e.get("detail"), dict):
        return e["detail"]
    return e or {}

# ----------------------------
# Write-/Update-Pfad (NEU)
# ----------------------------
def _ensure_file_sync_table(cur, table: str):
    cur.execute(f"""
        CREATE TABLE IF NOT EXISTS `{table}` (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            created_at BIGINT NOT NULL,
            updated_at BIGINT NOT NULL,
            tenant_id VARCHAR(128) NOT NULL,
            filename VARCHAR(512) NOT NULL,
            s3_url TEXT,
            cf_url TEXT,
            s3_bucket VARCHAR(256),
            s3_key TEXT,
            size_bytes BIGINT,
            delivered_to JSON,
            sync_status VARCHAR(32) NOT NULL, -- pending|dispatched|failed|stored|completed
            meta_subject TEXT,
            meta_from TEXT,
            meta_to TEXT,
            meta_cc TEXT,
            analysis_summary TEXT,
            analysis_intent VARCHAR(64),
            analysis_priority VARCHAR(32),
            analysis_entities JSON
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    """)

def _insert_file_sync(cur, table: str, rec: Dict[str, Any]):
    sql = f"""
        INSERT INTO `{table}` (
          created_at, updated_at, tenant_id, filename, s3_url, cf_url,
          s3_bucket, s3_key, size_bytes, delivered_to, sync_status,
          meta_subject, meta_from, meta_to, meta_cc,
          analysis_summary, analysis_intent, analysis_priority, analysis_entities
        ) VALUES (
          %(created_at)s, %(updated_at)s, %(tenant_id)s, %(filename)s, %(s3_url)s, %(cf_url)s,
          %(s3_bucket)s, %(s3_key)s, %(size_bytes)s, CAST(%(delivered_to)s AS JSON), %(sync_status)s,
          %(meta_subject)s, %(meta_from)s, %(meta_to)s, %(meta_cc)s,
          %(analysis_summary)s, %(analysis_intent)s, %(analysis_priority)s, CAST(%(analysis_entities)s AS JSON)
        )
    """
    cur.execute(sql, rec)

def _is_write_payload(event_like: Dict[str, Any]) -> bool:
    d = _take_detail(event_like)
    if not isinstance(d, dict):
        return False
    # Events mit "action" sind KEIN Insert
    if d.get("action"):
        return False
    f = d.get("file") or {}
    has_file_fields = any(k in f for k in ("bucket", "key", "s3_key", "s3_url", "cf_url", "filename"))
    return (d.get("tenantId") or d.get("tenant_id")) and (has_file_fields or "analysis" in d)

def _build_record_from_payload(d: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
    import time as _time, json as _json
    now = int(_time.time() * 1000)

    tenant_id = (d.get("tenantId") or d.get("tenant_id") or "unknown").strip()
    file      = d.get("file") or {}
    meta      = d.get("meta") or {}
    analysis  = d.get("analysis") or {}
    sync      = d.get("sync") or {}

    s3_key_val = file.get("key") or file.get("s3_key") or ""

    rec = {
        "created_at": now,
        "updated_at": now,
        "tenant_id": tenant_id,
        "filename": file.get("filename") or "",
        "s3_url": file.get("s3_url") or "",
        "cf_url": file.get("cf_url") or "",
        "s3_bucket": file.get("bucket") or "",
        "s3_key": s3_key_val,
        "size_bytes": int(file.get("bytes") or 0),
        "delivered_to": _json.dumps(sync.get("deliveredTo") or []),
        "sync_status": (sync.get("status") or "pending"),
        "meta_subject": meta.get("subject") or "",
        "meta_from": meta.get("from") or "",
        "meta_to": meta.get("to") or "",
        "meta_cc": meta.get("cc") or "",
        "analysis_summary": analysis.get("summary") or "",
        "analysis_intent": analysis.get("intent") or "",
        "analysis_priority": analysis.get("priority") or "",
        "analysis_entities": _json.dumps(analysis.get("entities") or []),
    }
    return tenant_id, rec

def _match_keys(d: Dict[str, Any]) -> Tuple[Optional[str], Optional[str]]:
    f = d.get("file") or {}
    s3_key = f.get("s3_key") or f.get("key")
    filename = f.get("filename")
    return s3_key, filename

def _update_sync_status(cur, table: str, tenant_id: str,
                        new_status: str, s3_key: Optional[str], filename: Optional[str]) -> int:
    import time as _time
    now = int(_time.time() * 1000)
    conds = []
    params = [new_status, now, tenant_id]
    if s3_key:
        conds.append("s3_key=%s")
        params.append(s3_key)
    if filename:
        conds.append("filename=%s")
        params.append(filename)
    if not conds:
        raise ValueError("need file.s3_key or file.filename for update_status")
    sql = f"""
        UPDATE `{table}`
           SET sync_status=%s, updated_at=%s
         WHERE tenant_id=%s AND ({' OR '.join(conds)})
    """
    cur.execute(sql, params)
    return cur.rowcount

# =========================
# Lambda-Handler (kombiniert)
# =========================
def lambda_handler(event, context):
    _debug_fs()  # wie gehabt: TLS/Layer-Diagnostik

    d = _take_detail(event)

    # --- UPDATE-Status-Pfad ---
    if isinstance(d, dict) and d.get("action") == "update_status":
        tenant_id = (d.get("tenantId") or d.get("tenant_id") or "").strip()
        new_status = (d.get("new_status") or "").strip()
        s3_key, filename = _match_keys(d)

        if not tenant_id or not new_status:
            return {"ok": False, "error": "missing tenantId or new_status"}

        schema = f"{TENANT_SCHEMA_PREFIX}{tenant_id}"
        t_user = TENANT_DB_USER_TEMPLATE.format(tenant_id=tenant_id)
        try:
            tconn = _conn(t_user, schema)
        except Exception as e:
            logger.exception("[DB] Connect failed (update_status)")
            return {"ok": False, "tenantId": tenant_id, "error": f"connect_failed: {type(e).__name__}: {e}"}

        try:
            with tconn.cursor() as cur:
                affected = _update_sync_status(cur, TARGET_TABLE, tenant_id, new_status, s3_key, filename)
                if affected == 0:
                    return {"ok": False, "tenantId": tenant_id, "error": "no_row_matched",
                            "file": {"s3_key": s3_key, "filename": filename}}
        except Exception as e:
            logger.exception("[DB] Update failed (update_status)")
            return {"ok": False, "tenantId": tenant_id, "error": f"update_failed: {type(e).__name__}: {e}"}
        finally:
            try: tconn.close()
            except: pass

        return {
            "ok": True,
            "tenantId": tenant_id,
            "sync": {"status": new_status},
            "file": {"s3_key": s3_key, "filename": filename},
            "db": {"schema": schema, "table": TARGET_TABLE, "status": "updated"}
        }

    # --- INSERT/Write-Pfad (Lambda5 -> Lambda6) ---
    if _is_write_payload(event):
        tenant_id, rec = _build_record_from_payload(d)
        schema = f"{TENANT_SCHEMA_PREFIX}{tenant_id}"
        t_user = TENANT_DB_USER_TEMPLATE.format(tenant_id=tenant_id)

        try:
            tconn = _conn(t_user, schema)
        except Exception as e:
            logger.exception(f"[DB] Connect failed (write path) tenant={tenant_id}")
            return {"ok": False, "tenantId": tenant_id, "error": f"connect_failed: {type(e).__name__}: {e}"}

        try:
            with tconn.cursor() as cur:
                if AUTO_MIGRATE:
                    _ensure_file_sync_table(cur, TARGET_TABLE)
                _insert_file_sync(cur, TARGET_TABLE, rec)
        except Exception as e:
            logger.exception("[DB] Insert failed (write path)")
            return {"ok": False, "tenantId": tenant_id, "error": f"insert_failed: {type(e).__name__}: {e}"}
        finally:
            try: tconn.close()
            except: pass

        return {
            "ok": True,
            "tenantId": tenant_id,
            "db": {"schema": schema, "table": TARGET_TABLE, "status": "stored"},
            "file": d.get("file") or {},
            "meta": d.get("meta") or {},
            "analysis": d.get("analysis") or {},
            "sync": d.get("sync") or {"status": "pending"}
        }

    # --- ALT: ursprünglicher Lookup-Flow (unverändert) ---
    email = _parse_email(event)
    if not email:
        logger.warning("Keine E-Mail-Adresse im Event.")
        return {"tenant_id": "unknown", "reason": "email_missing"}

    # 1) Meta-Lookup
    try:
        meta = _conn(META_DB_USER, META_DB_NAME)
    except Exception as e:
        logger.exception(f"Meta-DB Verbindung fehlgeschlagen: {type(e).__name__}: {e}")
        return {"tenant_id": "unknown", "reason": "meta_connect_error"}

    try:
        res = _resolve_tenant(meta, email)
        if not res:
            logger.warning(f"Kein Tenant für {email} gefunden.")
            return {"tenant_id": "unknown", "reason": "tenant_not_found"}

        tenant_id, user_email, user_name = res
        schema = f"{TENANT_SCHEMA_PREFIX}{tenant_id}"
    finally:
        try: meta.close()
        except: pass

    # 2) Strikt getrennt: neue Verbindung mit tenant-spezifischem IAM-DB-User
    t_user = TENANT_DB_USER_TEMPLATE.format(tenant_id=tenant_id)
    try:
        tconn = _conn(t_user, schema)
    except Exception as e:
        logger.exception(f"Tenant-DB Verbindung fehlgeschlagen: {type(e).__name__}: {e}")
        return {"tenant_id": tenant_id, "schema": schema, "reason": "tenant_connect_error"}

    try:
        with tconn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM users;")
            user_count = int(cur.fetchone()[0])
    finally:
        try: tconn.close()
        except: pass

    s3_prefix = S3_PREFIX_TEMPLATE.format(tenant_id=tenant_id)
    ses_identity_hint = f"{SES_IDENTITY_PREFIX}{tenant_id}"

    return {
        "tenant_id": tenant_id,
        "schema": schema,
        "user_count": user_count,
        "user": {"email": user_email, "name": user_name},
        "routing": {
            "s3_bucket": S3_BUCKET,
            "s3_prefix": s3_prefix,
            "ses_identity_hint": ses_identity_hint
        },
        "mode": "A_strict_isolation"
    }
