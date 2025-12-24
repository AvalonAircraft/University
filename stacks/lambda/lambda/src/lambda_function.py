import os, json, boto3, email
from email.utils import getaddresses
from urllib.parse import unquote_plus

s3 = boto3.client('s3')
sf = boto3.client('stepfunctions')

SM_ARN = os.environ['STATE_MACHINE_ARN']

def _first_recipient(msg) -> str | None:
    # zieh To/Delivered-To/X-Original-To; nimm erste Adresse ohne Namen
    fields = [msg.get('To'), msg.get('Delivered-To'), msg.get('X-Original-To')]
    for f in fields:
        if not f:
            continue
        addrs = [addr for _, addr in getaddresses([f]) if addr]
        if addrs:
            return addrs[0].strip().lower()
    return None

def _start_sfn(bucket: str, key: str, recipient: str):
    inp = {"bucket": bucket, "key": key, "email": recipient}
    resp = sf.start_execution(stateMachineArn=SM_ARN, input=json.dumps(inp))
    print(f"[SFN] gestartet: {resp['executionArn']}")

def _move_email(bucket: str, key: str, tenant_id: str, routing: dict | None):
    routing = routing or {}
    # bevorzugt Prefix aus Lambda6, sonst Standard
    prefix = routing.get('s3_prefix') or f"{tenant_id}/emails/"
    # Dateiname aus Quell-Key extrahieren (egal, ob der in emails/ lag)
    filename = key.split('/')[-1]
    new_key = f"{prefix}{filename}"

    # idempotent: wenn Ziel existiert, nichts tun
    try:
        s3.head_object(Bucket=bucket, Key=new_key)
        print(f"[MOVE] Ziel existiert schon: s3://{bucket}/{new_key}")
        return
    except s3.exceptions.ClientError:
        pass

    s3.copy_object(Bucket=bucket, CopySource={'Bucket': bucket, 'Key': key}, Key=new_key)
    s3.delete_object(Bucket=bucket, Key=key)
    print(f"[MOVE] Verschoben: s3://{bucket}/{new_key}")

def lambda_handler(event, context):
    print("Eingehendes Event:", json.dumps(event))

    # Pfad 1: Aufruf durch Step Functions ⇒ verschieben
    if event.get('mode') == 'move':
        bucket = event.get('bucket')
        key = unquote_plus(event.get('key', ''))
        tenant_id = event.get('tenant_id')
        routing = event.get('routing')

        # 👉 Logging zur Bestätigung
        print(f"[move] tenant_id erhalten: {tenant_id}")
        if routing:
            print(f"[move] routing erhalten: {json.dumps(routing, indent=2)}")

        if not bucket or not key or not tenant_id:
            print("[move] fehlende Felder"); return

        _move_email(bucket, key, tenant_id, routing)

        return{
                "status": "moved",
                "tenant_id": tenant_id,
                "new_key": f"{routing.get('s3_prefix', tenant_id + '/emails/')}{key.split('/')[-1]}"
            }




    # Pfad 2: Aufruf durch EventBridge (Starter)
    detail = event.get('detail')
    if not detail:
        print("[starter] fehlendes 'detail'"); return

    bucket = (detail.get('bucket') or {}).get('name')
    key = (detail.get('object') or {}).get('key')
    if not bucket or not key:
        print("[starter] Bucket/Key fehlen"); return
    key = unquote_plus(key)

    # E-Mail laden & Empfänger extrahieren
    try:
        obj = s3.get_object(Bucket=bucket, Key=key)
        raw = obj['Body'].read()
        msg = email.message_from_bytes(raw)
        recipient = _first_recipient(msg)
        if not recipient:
            print("[starter] kein Empfänger gefunden"); return
        print(f"[starter] Empfänger: {recipient}")
    except Exception as e:
        print(f"[starter] S3/Parse-Fehler: {e}"); return

    # Step Functions starten; versetzt die restliche Arbeit in den robusten Orchestrator
    _start_sfn(bucket, key, recipient)
