
# README.md — University Terraform (AWS) Full Deploy Guide

Dieses Repo enthält mehrere Terraform-“Stacks” unter `stacks/` (jede Untermappe = eigenes Terraform-Projekt)
und wiederverwendbare Module unter `modules/`.

## Ziel
Jede Person kann dieses Repo klonen und die komplette Architektur im eigenen AWS Account deployen, indem sie pro Stack eine `terraform.tfvars` mit eigenen Werten anlegt.

> [!WARNING]
> WARNUNG: Das Deployment erzeugt AWS Ressourcen (Kosten!). Vor allem: Aurora, NAT, CloudFront, Logs, etc.

---

## 0) Stack-Ordner

- **apigw**
- **aurora-mysql**
- **cdn**
- **dns**
- **ecr**
- **ecs**
- **eventbridge**
- **iam-identity-center**
- **iam**
- **kms**
- **lambda**
- **network**
- **nlb**
- **org-billing**
- **organizations**
- **s3**
- **security_groups**
- **ses**
- **stepfunctions**
- **vpc**

> [!IMPORTANT]
> WICHTIG: Du brauchst **NICHT** alles.
>
> - **Org/Admin-only:** organizations, org-billing, iam-identity-center (nur Management Account)
> - **Networking:** entweder network (empfohlen) **ODER** vpc + security_groups
> - **CDN/DNS/SES:** nur wenn du eine echte Domain verwendest (Route53 + CloudFront + SES)

---

## 1) Voraussetzungen

- **Git**
- **Terraform >= 1.5**
- **AWS CLI v2**
- Optional: **Docker** (nur für ECR/ECS, wenn du dein eigenes Image bauen/pushen willst)

> [!IMPORTANT]
> Auch wenn manche Stacks einen Default für `region` haben:
> **Setze `region` IMMER explizit in jeder terraform.tfvars**, damit nichts unbemerkt in die falsche Region deployed.
>
> Dieses Repo deployt die meisten Workload-Ressourcen in **us-east-1**.
> (CloudFront/ACM hat Sonderregeln → siehe CDN/SES Kapitel.)

---

## 2) AWS Zugriff einrichten

**Option A: AWS Profile**

- `aws configure --profile myprofile`
- `export AWS_PROFILE="myprofile"`

**Region-Konvention**

```bash
# Workload Region (VPC/ECS/Lambda/API GW etc.)
: "${AWS_REGION:=us-east-1}"
export AWS_REGION
echo "AWS_REGION=$AWS_REGION"

aws sts get-caller-identity
````

> [!IMPORTANT]
> Stelle sicher, dass deine Credentials genug Rechte haben.
> Für ein “Full Deploy” brauchst du i.d.R. breite IAM-Rechte (VPC/IAM/KMS/Lambda/API GW/ECS/ECR/CloudWatch/…).
> In Uni-Kontexten ist oft ein “AdministratorAccess” im eigenen Account am einfachsten.

---

## 3) Repo klonen

* `git clone <REPO_URL>`
* `cd <repo-folder>`

---

## 4) Platzhalter/Defaults finden & überschreiben

> [!IMPORTANT]
> In den Stacks sind teils Defaults (Domains/Account IDs/etc.) gesetzt.
> **Best Practice:** Lege in **JEDEM** Stack eine eigene `terraform.tfvars` an und überschreibe dort die Werte.

**Schnelles Suchen nach author-spezifischen Strings/IDs:**

```bash
grep -R "miraedrive\|186261963982\|arn:aws:iam::\|E[0-9A-Z]\{10,\}\|sg-" -n stacks modules | head -n 200
```

**Typische Stellen, die du fast immer anpasst:**

* `region`
* Domains (`example.com`, `miraedrive.com`, …)
* Account IDs / ARNs
* Tags (Project/Environment/TenantID)
* Logging-Targets (CloudFront/SES Logs Bucket, Account IDs, Prefixes)

---

## 5) Terraform Standard-Workflow (pro Stack)

**1)** `terraform -chdir=stacks/<stack> init`
**2)** `terraform -chdir=stacks/<stack> plan`
**3)** `terraform -chdir=stacks/<stack> apply`

**Outputs ansehen:**

* `terraform -chdir=stacks/<stack> output`

> [!TIP]
> Wenn du Variablen übergibst, nutze konsequent `terraform.tfvars` je Stack.
> So bleibt es portable für andere Personen.

---

## 6) Empfohlene Deploy-Reihenfolge

### A) ORG/ADMIN-ONLY (optional)

Nur falls du wirklich Organizations/Billing/SSO zentral aufsetzen willst (Management Account).

**1)** `stacks/organizations`
**2)** `stacks/org-billing`
**3)** `stacks/iam-identity-center`

### B) NETWORKING (wähle EINE Variante)

**4)** Variante 1 (empfohlen): `stacks/network`
**ODER**
**4)** Variante 2: `stacks/vpc` → `stacks/security_groups`

### C) CORE

**5)** `stacks/iam` (Rollen/Policies)
**6)** `stacks/kms/tenant-master-key`
**7)** `stacks/s3` (optional/empfohlen)
**8)** `stacks/aurora-mysql` (optional)

### D) OPTIONAL (ECS Path)

**9)** `stacks/nlb` (nur wenn ECS genutzt wird)
**10)** `stacks/ecr` (nur wenn du eigenes Image pushen willst)
**11)** `stacks/ecs`

### E) SERVERLESS / API / EVENTS / WORKFLOWS

**12)** `stacks/lambda/*`
**13)** `stacks/apigw`
**14)** `stacks/eventbridge/*`
**15)** `stacks/stepfunctions/*` (+ passende IAM Roles + Log Groups)
**16)** `stacks/ses` (optional)

### F) DOMAIN/CDN (optional; benötigt echte Domain)

**17)** `stacks/dns`
**18)** `stacks/cdn`

> [!TIP]
> **Minimal-Deploy (typisch für Uni-Demo):**
> `network` → `iam` → `kms` → `s3` → `lambda/*` → `apigw`
> (ohne Aurora/ECS/Domain)

---

## 7) A) ORG/ADMIN-ONLY STACKS (optional!)

> [!NOTE]
> NUR ausführen, wenn du im AWS Organizations **MANAGEMENT ACCOUNT** bist und wirklich `Accounts/OUs/Billing/SSO` setzen willst.
> Du MUSST hier eigene E-Mails, Account-Namen etc. setzen – NICHT die Defaults benutzen.

### 7.1 organizations

```bash
cat > stacks/organizations/terraform.tfvars <<'EOF'
# Beispiel – DU MUSST HIER DEINE EIGENEN WERTE SETZEN
# org_name = "my-org"
# accounts = [...]
EOF

terraform -chdir=stacks/organizations init
terraform -chdir=stacks/organizations plan
terraform -chdir=stacks/organizations apply
```

### 7.2 org-billing

```bash
cat > stacks/org-billing/terraform.tfvars <<'EOF'
# Beispiel – EIGENE Billing-Konfiguration
EOF

terraform -chdir=stacks/org-billing init
terraform -chdir=stacks/org-billing plan
terraform -chdir=stacks/org-billing apply
```

### 7.3 iam-identity-center

```bash
cat > stacks/iam-identity-center/terraform.tfvars <<'EOF'
# Beispiel – EIGENE SSO User/Groups/Assignments
EOF

terraform -chdir=stacks/iam-identity-center init
terraform -chdir=stacks/iam-identity-center plan
terraform -chdir=stacks/iam-identity-center apply
```

> [!NOTE]
> Wenn du das nicht brauchst: diese 3 Stacks einfach überspringen.

---

## 8) B) NETWORKING — Variante 1 (empfohlen): `stacks/network`

```bash
cat > stacks/network/terraform.tfvars <<EOF
region = "${AWS_REGION}"
EOF

terraform -chdir=stacks/network init
terraform -chdir=stacks/network plan
terraform -chdir=stacks/network apply
```

> [!IMPORTANT]
> Wichtige Outputs (der network Stack outputtet diese Keys):

```bash
VPC_ID=$(terraform -chdir=stacks/network output -raw vpc_id)
SUBNET_PUBLIC1=$(terraform -chdir=stacks/network output -raw subnet_public1_id)
SUBNET_PUBLIC2=$(terraform -chdir=stacks/network output -raw subnet_public2_id)
SUBNET_PRIVATE1=$(terraform -chdir=stacks/network output -raw subnet_private1_id)
SUBNET_PRIVATE2=$(terraform -chdir=stacks/network output -raw subnet_private2_id)

SG_ECS_FARGATE=$(terraform -chdir=stacks/network output -raw sg_ecs_fargate_id)
SG_NLB_PRIVATELINK=$(terraform -chdir=stacks/network output -raw sg_nlb_fargate_privatelink_id)
SG_AURORA=$(terraform -chdir=stacks/network output -raw sg_aurora_id)

echo "VPC_ID=$VPC_ID"
echo "SUBNET_PUBLIC1=$SUBNET_PUBLIC1"
echo "SUBNET_PUBLIC2=$SUBNET_PUBLIC2"
echo "SUBNET_PRIVATE1=$SUBNET_PRIVATE1"
echo "SUBNET_PRIVATE2=$SUBNET_PRIVATE2"
echo "SG_ECS_FARGATE=$SG_ECS_FARGATE"
echo "SG_NLB_PRIVATELINK=$SG_NLB_PRIVATELINK"
echo "SG_AURORA=$SG_AURORA"
```

---

## 9) B) NETWORKING — Variante 2: `stacks/vpc` + `stacks/security_groups` (Alternative)

> [!NOTE]
> Nur nutzen, wenn du `stacks/network` NICHT nutzt.

```bash
cat > stacks/vpc/terraform.tfvars <<EOF
region = "${AWS_REGION}"
EOF

terraform -chdir=stacks/vpc init
terraform -chdir=stacks/vpc apply

VPC_ID=$(terraform -chdir=stacks/vpc output -raw vpc_id)
SUBNET_PUBLIC1=$(terraform -chdir=stacks/vpc output -raw subnet_public1_id)
SUBNET_PUBLIC2=$(terraform -chdir=stacks/vpc output -raw subnet_public2_id)
SUBNET_PRIVATE1=$(terraform -chdir=stacks/vpc output -raw subnet_private1_id)
SUBNET_PRIVATE2=$(terraform -chdir=stacks/vpc output -raw subnet_private2_id)

cat > stacks/security_groups/terraform.tfvars <<EOF
region = "${AWS_REGION}"
vpc_id = "${VPC_ID}"
EOF

terraform -chdir=stacks/security_groups init
terraform -chdir=stacks/security_groups apply

SG_ECS_FARGATE=$(terraform -chdir=stacks/security_groups output -raw sg_ecs_fargate_id)
SG_NLB_PRIVATELINK=$(terraform -chdir=stacks/security_groups output -raw sg_nlb_fargate_privatelink_id)
SG_AURORA=$(terraform -chdir=stacks/security_groups output -raw sg_aurora_id)
```

---

## 10) C) KMS — `stacks/kms/tenant-master-key`

```bash
cat > stacks/kms/tenant-master-key/terraform.tfvars <<EOF
region = "${AWS_REGION}"
EOF

terraform -chdir=stacks/kms/tenant-master-key init
terraform -chdir=stacks/kms/tenant-master-key plan
terraform -chdir=stacks/kms/tenant-master-key apply

TENANT_KMS_KEY_ARN=$(terraform -chdir=stacks/kms/tenant-master-key output -raw tenant_master_key_arn)
echo "TENANT_KMS_KEY_ARN=$TENANT_KMS_KEY_ARN"
```

---

## 11) C) NLB — `stacks/nlb` (nur für ECS)

> [!NOTE]
> Dieser Stack erstellt einen **internal** Network Load Balancer (**internal = true**) in **PRIVATE** Subnetzen
> und hängt eine Security Group per `aws_lb_security_group_attachment` an (relevant für PrivateLink / eingeschränkten Inbound-Flow).
>
> **Benötigt:**
>
> * `VPC_ID`
> * `SUBNET_PRIVATE1`, `SUBNET_PRIVATE2`
> * `SG_NLB_PRIVATELINK`

```bash
cat > stacks/nlb/terraform.tfvars <<EOF
region = "${AWS_REGION}"
vpc_id = "${VPC_ID}"
subnet_private1 = "${SUBNET_PRIVATE1}"
subnet_private2 = "${SUBNET_PRIVATE2}"
nlb_sg_id = "${SG_NLB_PRIVATELINK}"

# Optional: Default ist dualstack
# ip_address_type = "ipv4"

tags = {
  Project     = "University"
  Environment = "Dev"
  Type        = "NLB"
  TenantID    = ""
}
EOF

terraform -chdir=stacks/nlb init
terraform -chdir=stacks/nlb plan
terraform -chdir=stacks/nlb apply

TARGET_GROUP_ARN=$(terraform -chdir=stacks/nlb output -raw target_group_arn)
NLB_DNS=$(terraform -chdir=stacks/nlb output -raw nlb_dns_name)

echo "TARGET_GROUP_ARN=$TARGET_GROUP_ARN"
echo "NLB_DNS=$NLB_DNS"
```

> [!NOTE]
> Der NLB ist internal. `NLB_DNS` ist i.d.R. nur aus dem VPC erreichbar (z.B. ECS Task/EC2 im privaten Netz).

---

## 12) C) IAM — `stacks/iam` (Rollen)

> [!NOTE]
> Diese Rollen werden z.B. von ECS referenziert (ECS Stack nutzt **Rollen-NAMEN**):
>
> * `agentTaskRole`
> * `ecsTaskExecutionRole-ai-agent`

**Deploye die IAM Substacks, die du brauchst (oder alle).**

```bash
for d in stacks/iam/*; do
  [ -d "$d" ] || continue
  ls "$d"/*.tf >/dev/null 2>&1 || continue
  echo "=== IAM APPLY: $d ==="
  terraform -chdir="$d" init
  terraform -chdir="$d" plan
  terraform -chdir="$d" apply
done
```

> [!IMPORTANT]
> Falls du ABAC/Tagging nutzt (TenantID), stelle sicher, dass du die Tags auch wirklich setzt,
> sonst wirken Policies “zu restriktiv” (typischer AccessDenied).

---

## 13) C) ECR — `stacks/ecr` (optional)

> [!NOTE]
> Default `kms_key_arn` im Stack ist ggf. author-spezifisch → hier überschreiben!

```bash
ECR_REPO_NAME="ai-agent"

cat > stacks/ecr/terraform.tfvars <<EOF
region = "${AWS_REGION}"
repository_name = "${ECR_REPO_NAME}"
kms_key_arn = "${TENANT_KMS_KEY_ARN}"
EOF

terraform -chdir=stacks/ecr init
terraform -chdir=stacks/ecr plan
terraform -chdir=stacks/ecr apply

ECR_URI=$(terraform -chdir=stacks/ecr output -raw repository_url)
echo "ECR_URI=$ECR_URI"
```

---

## 14) C) ECS — `stacks/ecs`

> [!NOTE]
> Dieser Stack erwartet u.a.:
>
> * `subnet_ids` (private)
> * `security_group_id` (ECS SG)
> * `target_group_arn` (von NLB)
> * `container_image` (**public ODER ECR**)

> [!IMPORTANT]
> WICHTIG:
>
> * **Für Uni/Professor-Deploy ohne Docker:** Nutze **Option A (Public Image)** → kein ECR/Docker nötig.
> * **Wenn du dein eigenes Image willst:** Nutze **Option B (ECR + Docker Build/Push)**.

### 14.1 Option A: Deploy OHNE Docker (Public Image)

> [!IMPORTANT]
> Du musst `CONTAINER_IMAGE` setzen (Beispiel: ein öffentliches Image aus Docker Hub oder GHCR).
> Beispiel (Dummy): `CONTAINER_IMAGE="nginx:latest"`

```bash
CONTAINER_IMAGE="nginx:latest"

cat > stacks/ecs/terraform.tfvars <<EOF
region = "${AWS_REGION}"
subnet_ids = ["${SUBNET_PRIVATE1}", "${SUBNET_PRIVATE2}"]
security_group_id = "${SG_ECS_FARGATE}"
target_group_arn = "${TARGET_GROUP_ARN}"
container_image = "${CONTAINER_IMAGE}"

task_role_name      = "agentTaskRole"
execution_role_name = "ecsTaskExecutionRole-ai-agent"
EOF

terraform -chdir=stacks/ecs init
terraform -chdir=stacks/ecs plan
terraform -chdir=stacks/ecs apply
```

### 14.2 Option B: Deploy MIT Docker (ECR Login + Build + Push)

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Build aus Repository-Root (wenn du einen Dockerfile hast)
docker build -t "${ECR_REPO_NAME}:latest" .
docker tag "${ECR_REPO_NAME}:latest" "${ECR_URI}:latest"
docker push "${ECR_URI}:latest"

CONTAINER_IMAGE="${ECR_URI}:latest"

cat > stacks/ecs/terraform.tfvars <<EOF
region = "${AWS_REGION}"
subnet_ids = ["${SUBNET_PRIVATE1}", "${SUBNET_PRIVATE2}"]
security_group_id = "${SG_ECS_FARGATE}"
target_group_arn = "${TARGET_GROUP_ARN}"
container_image = "${CONTAINER_IMAGE}"

task_role_name      = "agentTaskRole"
execution_role_name = "ecsTaskExecutionRole-ai-agent"
EOF

terraform -chdir=stacks/ecs init
terraform -chdir=stacks/ecs plan
terraform -chdir=stacks/ecs apply
```

---

## 15) C) Aurora MySQL (optional) — `stacks/aurora-mysql`

> [!NOTE]
> Dieser Stack nutzt das aurora-mysql Modul und erstellt DB + Secret in Secrets Manager.
> Benötigt: `vpc_id`, `subnet_ids` (private), `security_group_ids` (Aurora SG)

```bash
cat > stacks/aurora-mysql/terraform.tfvars <<EOF
region = "${AWS_REGION}"
vpc_id = "${VPC_ID}"
subnet_ids = ["${SUBNET_PRIVATE1}", "${SUBNET_PRIVATE2}"]
security_group_ids = ["${SG_AURORA}"]
cluster_identifier = "aurora-mysql-cluster"
db_name = "mydb"
EOF

terraform -chdir=stacks/aurora-mysql init
terraform -chdir=stacks/aurora-mysql plan
terraform -chdir=stacks/aurora-mysql apply
```

---

## 16) C) S3 (optional/empfohlen) — `stacks/s3`

> [!NOTE]
> Der S3 Stack hat Defaults für `cloudfront_distribution_arns`, `logs_account_id` etc., die author-spezifisch sein können.
> Wenn du erstmal **nur einen Bucket** brauchst, neutralisiere CloudFront-Refs und setze Account IDs auf deinen Account.

> [!IMPORTANT]
> Dieser Stack aktiviert (in diesem Repo) typischerweise `eventbridge = true` für den Bucket.
> Dadurch können S3 Events (Object Created) an EventBridge gesendet werden → relevant für `stacks/eventbridge/*`.

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET_NAME="university-bucket-${ACCOUNT_ID}-${AWS_REGION}"

cat > stacks/s3/terraform.tfvars <<EOF
region = "${AWS_REGION}"
bucket_name = "${S3_BUCKET_NAME}"

# Neutralisieren, falls du noch kein CloudFront/SES Logging verkabeln willst:
cloudfront_distribution_arns = []
logs_account_id = "${ACCOUNT_ID}"
ses_account_id  = "${ACCOUNT_ID}"
logs_prefix = "logs/"
ses_prefix  = "ses/"
EOF

terraform -chdir=stacks/s3 init
terraform -chdir=stacks/s3 plan
terraform -chdir=stacks/s3 apply
```

**Optional: Bucket Name aus Outputs ziehen (falls Stack outputtet):**

```bash
# S3_BUCKET_NAME=$(terraform -chdir=stacks/s3 output -raw bucket_name)
echo "S3_BUCKET_NAME=$S3_BUCKET_NAME"
```

---

## 17) D) Lambda — `stacks/lambda/*`

> [!NOTE]
> Deploye die Lambda-Substacks, die du brauchst (oder alle).

```bash
for d in stacks/lambda/*; do
  [ -d "$d" ] || continue
  ls "$d"/*.tf >/dev/null 2>&1 || continue
  echo "=== LAMBDA APPLY: $d ==="
  terraform -chdir="$d" init
  terraform -chdir="$d" plan
  terraform -chdir="$d" apply
done
```

> [!IMPORTANT]
> API Gateway benötigt in diesem Repo KEINE "Invoke-ARNs" als Input.
> Das Modul `modules/apigw_rest` baut die Integration-URI intern.

**Beispiel-Outputs sammeln (ARNs):**

```bash
LAMBDA_AGENT_ARN=$(terraform -chdir=stacks/lambda/lambda_AgentControlHandler output -raw lambda_function_arn)
LAMBDA_AURORA_ARN=$(terraform -chdir=stacks/lambda/lambda6 output -raw lambda_function_arn)

echo "LAMBDA_AGENT_ARN=$LAMBDA_AGENT_ARN"
echo "LAMBDA_AURORA_ARN=$LAMBDA_AURORA_ARN"
```

---

## 18) D) API Gateway (REST) — `stacks/apigw`

> [!NOTE]
> Dieser Stack verwendet das Modul `modules/apigw_rest` und erstellt eine REST API (EDGE).

### 18.1 terraform.tfvars erstellen

```bash
cat > stacks/apigw/terraform.tfvars <<EOF
region = "${AWS_REGION}"
api_name = "GeneralGateway"
lambda_arn_agent  = "${LAMBDA_AGENT_ARN}"
lambda_arn_aurora = "${LAMBDA_AURORA_ARN}"
s3_bucket_name    = "${S3_BUCKET_NAME}"
EOF
```

### 18.2 Deploy

```bash
terraform -chdir=stacks/apigw init
terraform -chdir=stacks/apigw apply

API_URL=$(terraform -chdir=stacks/apigw output -raw invoke_url)
echo "API_URL=${API_URL}"
```

---

## 19) D) EventBridge — `stacks/eventbridge/*` (S3 Automation)

> [!IMPORTANT]
> Die Rules in diesen Stacks lauschen typischerweise auf einen zentralen Event Bus (z.B. `event-bus-miraedrive`).
> Stelle sicher, dass der Name/ARN bei dir korrekt ist (Defaults ggf. überschreiben).
>
> Sie verarbeiten S3 `Object Created` Benachrichtigungen (aktiviert in S3 Stack, Punkt 16).

```bash
for d in stacks/eventbridge/*; do
  [ -d "$d" ] || continue
  ls "$d"/*.tf >/dev/null 2>&1 || continue
  echo "=== EVENTBRIDGE APPLY: $d ==="
  terraform -chdir="$d" init
  terraform -chdir="$d" plan
  terraform -chdir="$d" apply
done
```

---

## 20) D) StepFunctions — `stacks/stepfunctions/*`

> [!NOTE]
> Die StepFunctions Stacks erwarten häufig bestehende Log Groups (außer explizit im Stack anders gelöst).
> Wenn dein Deploy mit “Log Group does not exist” scheitert → zuerst Log Groups anlegen.

### 20.1 Log Groups anlegen (Beispiel)

```bash
aws logs create-log-group --log-group-name "/aws/stepfunctions/AgentStepFunction" --region "${AWS_REGION}" 2>/dev/null || true
# ... weitere analog anlegen
```

### 20.2 StepFunctions deploy

```bash
for d in stacks/stepfunctions/*; do
  [ -d "$d" ] || continue
  ls "$d"/*.tf >/dev/null 2>&1 || continue
  echo "=== STEPFUNCTIONS APPLY: $d ==="
  terraform -chdir="$d" init
  terraform -chdir="$d" plan
  terraform -chdir="$d" apply
done
```

---

## 21) D) SES — `stacks/ses` (optional)

> [!IMPORTANT]
> SES benötigt in der Praxis i.d.R. eine verifizierte Domain.
> Wenn du keine Domain hast: diesen Stack überspringen.

> [!NOTE]
> Je nach Region/Account kann SES “Sandbox Mode” aktiv sein (Versand eingeschränkt).
> Das ist AWS-seitig und nicht Terraform-spezifisch.

---

## 22) E) DNS (Route53) — `stacks/dns` (optional)

```bash
cat > stacks/dns/terraform.tfvars <<'EOF'
zone_name = "example.com"
dns_records = []
EOF

terraform -chdir=stacks/dns init
terraform -chdir=stacks/dns apply

HOSTED_ZONE_ID=$(terraform -chdir=stacks/dns output -raw zone_id)
echo "HOSTED_ZONE_ID=$HOSTED_ZONE_ID"
```

---

## 23) E) CDN (CloudFront) — `stacks/cdn` (optional)

> [!IMPORTANT]
> **ACM Zertifikate für CloudFront müssen zwingend in `us-east-1` liegen.**
> Auch wenn deine Workload in einer anderen Region ist: das CloudFront Zertifikat bleibt `us-east-1`.

> [!NOTE]
> Wenn du keine echte Domain/Aliases nutzt, kannst du CloudFront oft komplett überspringen.

---

## 24) SES deployen (wenn Domain vorhanden)

```bash
cat > stacks/ses/terraform.tfvars <<EOF
region = "${AWS_REGION}"
domain_name = "example.com"
hosted_zone_id = "${HOSTED_ZONE_ID}"
s3_bucket_name = "${S3_BUCKET_NAME}"
EOF

terraform -chdir=stacks/ses init
terraform -chdir=stacks/ses apply
```

---

## 25) Destroy / Cleanup (umgekehrte Reihenfolge!)

> [!IMPORTANT]
> Immer von “oben” nach “unten” destroyen, damit Dependencies sauber wegfallen.

**Beispiel (Workload):**

```bash
terraform -chdir=stacks/apigw destroy

for d in stacks/lambda/*; do
  [ -d "$d" ] && terraform -chdir="$d" destroy
done

for d in stacks/stepfunctions/*; do
  [ -d "$d" ] && terraform -chdir="$d" destroy
done

for d in stacks/eventbridge/*; do
  [ -d "$d" ] && terraform -chdir="$d" destroy
done

terraform -chdir=stacks/ecs destroy
terraform -chdir=stacks/ecr destroy
terraform -chdir=stacks/nlb destroy
terraform -chdir=stacks/aurora-mysql destroy
terraform -chdir=stacks/s3 destroy
terraform -chdir=stacks/kms/tenant-master-key destroy
terraform -chdir=stacks/network destroy
# (oder vpc + security_groups falls genutzt)
```

**Domain:**

```bash
terraform -chdir=stacks/cdn destroy
terraform -chdir=stacks/ses destroy
terraform -chdir=stacks/dns destroy
```

**Org/Admin:**

```bash
terraform -chdir=stacks/iam-identity-center destroy
terraform -chdir=stacks/org-billing destroy
terraform -chdir=stacks/organizations destroy
```

---

## Troubleshooting

* **Falsche Region / Ressourcen “verschwunden”** → prüfe `region` in `terraform.tfvars` (pro Stack!)
* **AccessDenied** → IAM Rechte/ABAC Tags/Session Tags prüfen
* **ECS bekommt keine Targets healthy** → SG/Ports/TargetGroup HealthCheck + Container Port prüfen
* **StepFunctions Fehler “Log group does not exist”** → Log Groups vorab anlegen (Punkt 20)
* **CloudFront Zertifikat** → ACM muss in `us-east-1` sein (Punkt 23)

