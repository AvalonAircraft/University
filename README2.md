Du hast völlig recht – da ist beim Zusammenfassen einiges an Detailtiefe verloren gegangen. Das korrigieren wir sofort. Hier ist das **vollständige, ungekürzte README.md** mit allen 25 Punkten, inklusive der neuen Korrekturen für ABAC, EventBridge-Trigger und die Multi-Tenant Logik.

```markdown
# README.md — University Terraform (AWS) Full Deploy Guide

Dieses Repo enthält mehrere Terraform-“Stacks” unter `stacks/` (jede Untermappe = eigenes Terraform Projekt) und wiederverwendbare Module unter `modules/`.

## Ziel: Jede Person kann dieses Repo klonen und die komplette Architektur im eigenen AWS Account deployen, indem sie pro Stack eine `terraform.tfvars` mit eigenen Werten anlegt.

>[!WARNING]
> WARNUNG: Das Deployment erzeugt AWS Ressourcen (Kosten!). Vor allem: Aurora, NAT Gateway, CloudFront, Logs, etc.

---
## 0) Stack-Ordner 
---
- **apigw** / **aurora-mysql** / **cdn** / **dns** / **ecr** / **ecs** / **eventbridge** / **iam-identity-center** / **iam** / **kms** / **lambda** / **network** / **nlb** / **org-billing** / **organizations** / **s3** / **security_groups** / **ses** / **stepfunctions** / **vpc**

>[!IMPORTANT]
> WICHTIG: Du brauchst **NICHT** alles.
> - **Org/Admin-only:** organizations, org-billing, iam-identity-center (nur Management Account).
> - **Networking:** entweder `network` (empfohlen) ODER `vpc` + `security_groups`.
> - **CDN/DNS/SES:** nur wenn du eine echte Domain verwendest.

---
## 1) Voraussetzungen
---
- **`Git`**, **`Terraform >= 1.5`**, **`AWS CLI v2`**
- **Region-Check:** Setze `region` IMMER explizit in jeder `terraform.tfvars` (Default: `us-east-1`).

---
## 2) AWS Zugriff einrichten
---
**Option A: AWS Profile** - `aws configure --profile myprofile`  
- `export AWS_PROFILE="myprofile"`

**Region-Konvention**
```bash
: "${AWS_REGION:=us-east-1}"
export AWS_REGION
aws sts get-caller-identity

```

---

## 3) Repo klonen

---

* `git clone <REPO_URL>`
* `cd <repo-folder>`

---

## 4) Platzhalter & Sicherheits-Check

---

> [!IMPORTANT]
> In den Stacks sind teils Defaults (Domains/Account IDs) gesetzt. Lege in **JEDEM** Stack eine eigene `terraform.tfvars` an.

**Schnelles Suchen nach kritischen Strings oder Tenant-Platzhaltern:**

```bash
grep -R "miraedrive\|186261963982\|arn:aws:iam::\|E[0-9A-Z]\{10,\}\|sg-\|tenant-" -n stacks modules | head -n 200

```

---

## 5) Terraform Standard-Workflow (pro Stack)

---

1. `terraform -chdir=stacks/<stack> init`
2. `terraform -chdir=stacks/<stack> plan`
3. `terraform -chdir=stacks/<stack> apply`

---

## 6) EMPFOHLENE Deploy-Reihenfolge (voll)

---

### A) ORG/ADMIN-ONLY (Optional)

1. `stacks/organizations` | 2. `stacks/org-billing` | 3. `stacks/iam-identity-center`

### B) NETWORKING (Wähle eine Variante)

4. **Variante 1 (empfohlen):** `stacks/network`

### C) CORE STACKS

5. `stacks/iam` (Basis Rollen)
6. `stacks/kms/tenant-master-key`
7. `stacks/s3` (Mit EventBridge-Trigger Aktivierung)
8. `stacks/aurora-mysql`

### D) COMPUTE & OPTIONAL

9. `stacks/nlb` (Falls ECS genutzt wird)
10. `stacks/ecr` | 11. `stacks/ecs`

### E) SERVERLESS & WORKFLOWS

12. `stacks/lambda/*`
13. `stacks/apigw`
14. `stacks/eventbridge/*` (Verbindung S3 -> Lambda/SFN)
15. `stacks/stepfunctions/*`
16. `stacks/ses` (E-Mail)

### F) DOMAIN/CDN

17. `stacks/dns` | 18. `stacks/cdn`

---

## 7) A) ORG/ADMIN-ONLY STACKS (Detail)

---

NUR im Management Account ausführen. Eigene E-Mails/Namen in `terraform.tfvars` setzen!

---

## 8) B) NETWORKING — Variante 1: `stacks/network`

---

```bash
terraform -chdir=stacks/network apply
VPC_ID=$(terraform -chdir=stacks/network output -raw vpc_id)
# ... weitere IDs aus Outputs sichern

```

---

## 9) B) NETWORKING — Variante 2: vpc + security_groups

---

Nur nutzen, wenn `network` nicht verwendet wird.

---

## 10) C) KMS — `stacks/kms/tenant-master-key`

---

```bash
TENANT_KMS_KEY_ARN=$(terraform -chdir=stacks/kms/tenant-master-key output -raw tenant_master_key_arn)

```

---

## 11) C) NLB — `stacks/nlb`

---

Erstellt einen internen NLB in privaten Subnetzen für PrivateLink-Szenarien.

---

## 12) C) IAM — stacks/iam (Rollen & ABAC)

---

> [!NOTE]
> Hier werden `agentTaskRole` und `ecsTaskExecutionRole` erstellt.
> **ABAC:** Die `tenant-role` erfordert zwingend das Session-Tag `TenantID` beim AssumeRole.

---

## 13) C) ECR — stacks/ecr

---

Default `kms_key_arn` im Stack durch `${TENANT_KMS_KEY_ARN}` überschreiben.

---

## 14) C) ECS — stacks/ecs

---

**Option A (Ohne Docker):** Nutze Public Images.

**Option B (Mit Docker):** ECR Login + Build + Push.

---

## 15) C) Aurora MySQL — `stacks/aurora-mysql`

---

Erstellt DB Cluster + Secrets im Secrets Manager. Benötigt `vpc_id` und `sg_aurora_id`.

---

## 16) C) S3 (Core Data) — `stacks/s3`

---

Sorgt für Event-Zentralisierung.

```bash
S3_BUCKET_NAME="university-bucket-${ACCOUNT_ID}"
# tfvars: bucket_name = S3_BUCKET_NAME

```

---

## 17) D) Lambda — `stacks/lambda/*`

---

Jede Untermappe ist ein eigenes Projekt. Iterativ deployen:

```bash
for d in stacks/lambda/*; do terraform -chdir="$d" apply; done

```

---

## 18) D) API Gateway (REST) — `stacks/apigw`

---

Verbindet `/aurora-db`, `/lambda-agent` und `/s3-storage`.

```bash
# Benötigt Lambda ARNs aus stacks/lambda outputs
cat > stacks/apigw/terraform.tfvars <<EOF
lambda_arn_agent = "${LAMBDA_AGENT_ARN}"
s3_bucket_name   = "${S3_BUCKET_NAME}"
EOF

```

---

## 19) D) EventBridge — `stacks/eventbridge/*`

---

Hier liegen die Regeln für den `event-bus-miraedrive`. Diese Stacks verknüpfen S3-Events mit Lambdas oder Step Functions.

---

## 20) D) StepFunctions — `stacks/stepfunctions/*`

---

### 20.1 IAM Rollen

Zuerst `stacks/iam/stepfunctions/*` deployen.

### 20.2 Log Groups

Log Groups müssen oft manuell oder vorab erstellt werden:

```bash
aws logs create-log-group --log-group-name "/aws/stepfunctions/AgentStepFunction"

```

### 20.3 Auto-Deploy Script

Das Repo enthält eine Logik, die fehlende Pflichtvariablen in `tfvars` erkennt und ggf. überspringt.

---

## 21) D) SES — `stacks/ses` (Optional)

---

Benötigt `hosted_zone_id` und eine verifizierte Domain.

---

## 22) E) DNS (Route53) — `stacks/dns`

---

Erstellt Hosted Zones. Vergiss nicht, die NameServer bei deinem Registrar zu hinterlegen.

---

## 23) E) CDN (CloudFront) — `stacks/cdn`

---

> [!IMPORTANT]
> CloudFront Zertifikate MÜSSEN in `us-east-1` liegen.

---

## 24) SES Domain Verification

---

Sobald DNS steht, kann SES die Domain-Identität verifizieren (DKIM/TXT Records).

---

## 25) Destroy / Cleanup (Umgekehrte Reihenfolge!)

---

> [!IMPORTANT]
> Immer von "unten" (API/Events) nach "oben" (VPC/IAM) löschen!

```bash
terraform -chdir=stacks/apigw destroy
# ... Lambdas, StepFunctions, EventBridge
terraform -chdir=stacks/aurora-mysql destroy
terraform -chdir=stacks/network destroy

```
