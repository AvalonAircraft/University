# README.md — University Terraform (AWS) Full Deploy Guide
#
Dieses Repo enthält mehrere Terraform-“Stacks” unter `stacks/` (jede Untermappe = eigenes Terraform Projekt)
und wiederverwendbare Module unter `modules/`.
#
## Ziel: Jede Person kann dieses Repo klonen und die komplette Architektur im eigenen AWS Account deployen, indem sie pro Stack eine `terraform.tfvars` mit eigenen Werten anlegt.
#
>[!WARNING]
WARNUNG: Das Deployment erzeugt AWS Ressourcen (Kosten!). Vor allem: Aurora, NAT, CloudFront, Logs, etc.
#
# --------------------------------------------------------------------
## 0) Stack-Ordner 
# --------------------------------------------------------------------
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
#
>[!IMPORTANT]
WICHTIG: Du brauchst NICHT alles.

# - "Org/Admin-only": organizations, org-billing, iam-identity-center (nur Management Account)
# - Networking: entweder network (empfohlen) ODER vpc + security_groups
# - CDN/DNS/SES: nur wenn du eine echte Domain verwendest (Route53 + CloudFront + SES)
#
# --------------------------------------------------------------------
## 1) Voraussetzungen
# --------------------------------------------------------------------
- **`Git`**
- **`Terraform >= 1.5`**
- **`AWS CLI v2`**
# - Optional: Docker (nur für ECS/ECR, wenn du Container pushen willst)
#
# --------------------------------------------------------------------
## 2) AWS Zugriff einrichten
# --------------------------------------------------------------------
**Option A: AWS Profile**  
- `aws configure --profile myprofile`  
- `export AWS_PROFILE="myprofile"`

# Region-Defaults:
# - Workloads (VPC/ECS/Lambda/etc.) typischerweise z.B. ap-northeast-2
# - CloudFront ACM Zertifikate müssen i.d.R. in us-east-1 angelegt werden (für stacks/cdn)
- `export AWS_REGION="ap-northeast-2"`
- `aws sts get-caller-identity`

# --------------------------------------------------------------------
## 3) Repo klonen
# --------------------------------------------------------------------
- `git clone <REPO_URL>`
- `cd University-main`
# --------------------------------------------------------------------
>[!IMPORTANT]
WICHTIG: Platzhalter/Defaults finden & überschreiben
# --------------------------------------------------------------------
In den Stacks sind teils Defaults (Domains/Account IDs/etc.) gesetzt.  
  
**Best Practice:**  
Lege in **JEDEM** Stack eine eigene terraform.tfvars an und überschreibe dort die Werte.
#
**Schnelles Suchen nach author-spezifischen Strings/IDs:**
`grep -R "miraedrive\|186261963982\|arn:aws:iam::\|E[0-9A-Z]\{10,\}\|sg-" -n stacks modules | head -n 200`

# --------------------------------------------------------------------
## 5) Terraform Standard-Workflow (pro Stack)
# --------------------------------------------------------------------
- `terraform -chdir=stacks/<stack> init`
- `terraform -chdir=stacks/<stack> plan`
- `terraform -chdir=stacks/<stack> apply`
#
# Outputs ansehen:
# terraform -chdir=stacks/`<stack>` output
#
# --------------------------------------------------------------------
## 6) EMPFOHLENE Deploy-Reihenfolge (voll)
# --------------------------------------------------------------------
### A) ORG/ADMIN-ONLY (nur falls du wirklich Organizations/Billing/SSO zentral aufsetzen willst)
**1)** `stacks/organizations`  
**2)** `stacks/org-billing`  
**3)** `stacks/iam-identity-center`  
#
### B) NETWORKING (wähle EINE Variante)
**Variante 1 (empfohlen):** `stacks/network`  
**Variante 2:** `stacks/vpc` **->** `stacks/security_groups`  
#
### C) [CORE](#core)
**1)** `stacks/kms/tenant-master-key`  
**2)** `stacks/nlb`  
**3)** `stacks/iam` (Rollen)  
**4)** `stacks/ecr`  
**5)** `stacks/ecs`  
**6)** `stacks/aurora-mysql` (optional)  
**7)** `stacks/s3` (optional/empfohlen)  
#
### D) [SERVERLESS / API / EVENTS / WORKFLOWS](#SERVERLESS / API / EVENTS / WORKFLOWS)
**1)** `stacks/lambda/*`  
**2)** `stacks/apigw`  
**3)** `stacks/eventbridge/*`  
**4)** `stacks/stepfunctions/*` (+ passende IAM Roles + Log Groups)  
**5)** `stacks/ses` (optional)  
#
### E) DOMAIN/CDN (optional; benötigt echte Domain)
**1)** `stacks/dns`  
**2)** `stacks/cdn`  
#
# --------------------------------------------------------------------
## 7) A) ORG/ADMIN-ONLY STACKS (optional!)
# --------------------------------------------------------------------
# NUR ausführen, wenn du im AWS Organizations MANAGEMENT ACCOUNT bist und wirklich Accounts/OUs/Billing/SSO setzen willst.
# Du MUSST hier eigene E-Mails, Account-Namen etc. setzen – NICHT die Defaults benutzen.
#
### 7.1 organizations
cat > stacks/organizations/terraform.tfvars <<'EOF'
# Beispiel – DU MUSST HIER DEINE EIGENEN WERTE SETZEN
# org_name = "my-org"
# accounts = [...]
EOF
terraform -chdir=stacks/organizations init
terraform -chdir=stacks/organizations plan
terraform -chdir=stacks/organizations apply

### 7.2 org-billing
cat > stacks/org-billing/terraform.tfvars <<'EOF'
# Beispiel – eigene Billing-Konfiguration
EOF
terraform -chdir=stacks/org-billing init
terraform -chdir=stacks/org-billing plan
terraform -chdir=stacks/org-billing apply

### 7.3 iam-identity-center
cat > stacks/iam-identity-center/terraform.tfvars <<'EOF'
# Beispiel – eigene SSO User/Groups/Assignments
EOF
terraform -chdir=stacks/iam-identity-center init
terraform -chdir=stacks/iam-identity-center plan
terraform -chdir=stacks/iam-identity-center apply

# Wenn du das nicht brauchst: diese 3 Stacks einfach überspringen.

# --------------------------------------------------------------------
## 8) B) NETWORKING — Variante 1 (empfohlen): stacks/network
# --------------------------------------------------------------------
cat > stacks/network/terraform.tfvars <<'EOF'
region = "ap-northeast-2"
EOF

terraform -chdir=stacks/network init
terraform -chdir=stacks/network plan
terraform -chdir=stacks/network apply

# Wichtige Outputs (der network Stack outputtet diese Keys):
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

# --------------------------------------------------------------------
## 9) B) NETWORKING — Variante 2: stacks/vpc + stacks/security_groups (Alternative)
# --------------------------------------------------------------------
# Nur nutzen, wenn du stacks/network NICHT nutzt.
# cat > stacks/vpc/terraform.tfvars <<'EOF'
# region = "ap-northeast-2"
# EOF
# terraform -chdir=stacks/vpc init && terraform -chdir=stacks/vpc apply
#
# VPC_ID=$(terraform -chdir=stacks/vpc output -raw vpc_id)
# SUBNET_PUBLIC1=$(terraform -chdir=stacks/vpc output -raw subnet_public1_id)
# SUBNET_PUBLIC2=$(terraform -chdir=stacks/vpc output -raw subnet_public2_id)
# SUBNET_PRIVATE1=$(terraform -chdir=stacks/vpc output -raw subnet_private1_id)
# SUBNET_PRIVATE2=$(terraform -chdir=stacks/vpc output -raw subnet_private2_id)
#
# cat > stacks/security_groups/terraform.tfvars <<EOF
# region = "ap-northeast-2"
# vpc_id = "${VPC_ID}"
# EOF
# terraform -chdir=stacks/security_groups init && terraform -chdir=stacks/security_groups apply
#
# SG_ECS_FARGATE=$(terraform -chdir=stacks/security_groups output -raw sg_ecs_fargate_id)
# SG_NLB_PRIVATELINK=$(terraform -chdir=stacks/security_groups output -raw sg_nlb_fargate_privatelink_id)
# SG_AURORA=$(terraform -chdir=stacks/security_groups output -raw sg_aurora_id)

# --------------------------------------------------------------------
## 10) C) KMS — stacks/kms/tenant-master-key
# --------------------------------------------------------------------
cat > stacks/kms/tenant-master-key/terraform.tfvars <<'EOF'
region = "ap-northeast-2"
EOF

terraform -chdir=stacks/kms/tenant-master-key init
terraform -chdir=stacks/kms/tenant-master-key plan
terraform -chdir=stacks/kms/tenant-master-key apply

TENANT_KMS_KEY_ARN=$(terraform -chdir=stacks/kms/tenant-master-key output -raw tenant_master_key_arn)
echo "TENANT_KMS_KEY_ARN=$TENANT_KMS_KEY_ARN"

# --------------------------------------------------------------------
## 11) C) NLB — stacks/nlb
# --------------------------------------------------------------------
# Benötigt: public subnets + security group (nlb sg) aus network/security_groups
cat > stacks/nlb/terraform.tfvars <<EOF
region = "ap-northeast-2"
subnet_ids = ["${SUBNET_PUBLIC1}", "${SUBNET_PUBLIC2}"]
security_group_id = "${SG_NLB_PRIVATELINK}"
EOF

terraform -chdir=stacks/nlb init
terraform -chdir=stacks/nlb plan
terraform -chdir=stacks/nlb apply

TARGET_GROUP_ARN=$(terraform -chdir=stacks/nlb output -raw target_group_arn)
NLB_DNS=$(terraform -chdir=stacks/nlb output -raw nlb_dns_name)
echo "TARGET_GROUP_ARN=$TARGET_GROUP_ARN"
echo "NLB_DNS=$NLB_DNS"

# --------------------------------------------------------------------
## 12) C) IAM — stacks/iam (Rollen)
# --------------------------------------------------------------------
# Diese Rollen werden z.B. von ECS referenziert (ECS Stack nutzt Rollen-NAMEN):
# - agentTaskRole
# - ecsTaskExecutionRole-ai-agent
#
# Deploye die IAM Substacks, die du brauchst (oder alle).
for d in stacks/iam/*; do
  [ -d "$d" ] || continue
  echo "=== IAM APPLY: $d ==="
  terraform -chdir="$d" init
  terraform -chdir="$d" plan
  terraform -chdir="$d" apply
done

# --------------------------------------------------------------------
## 13) C) ECR — stacks/ecr
# --------------------------------------------------------------------
# Default kms_key_arn im Stack ist author-spezifisch -> hier überschreiben!
ECR_REPO_NAME="ai-agent"

cat > stacks/ecr/terraform.tfvars <<EOF
region = "ap-northeast-2"
repository_name = "${ECR_REPO_NAME}"
kms_key_arn = "${TENANT_KMS_KEY_ARN}"
EOF

terraform -chdir=stacks/ecr init
terraform -chdir=stacks/ecr plan
terraform -chdir=stacks/ecr apply

ECR_URI=$(terraform -chdir=stacks/ecr output -raw ecr_repository)
echo "ECR_URI=$ECR_URI"

# --------------------------------------------------------------------
## 14) C) ECS — stacks/ecs
# --------------------------------------------------------------------
# Dieser Stack erwartet u.a.:
# - subnet_ids (private)
# - security_group_id (ECS SG)
# - target_group_arn (von NLB)
# - container_image (aus ECR)
#
>[!IMPORTANT]
WICHTIG: Du musst ein Image in dieses ECR pushen, sonst läuft ECS zwar, aber Container kann fehlschlagen.
#
### 14.1 Docker Login + Build + Push
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Beispiel: build aus Repository-Root (wenn du einen Dockerfile hast)
# docker build -t "${ECR_REPO_NAME}:latest" .
# docker tag "${ECR_REPO_NAME}:latest" "${ECR_URI}:latest"
# docker push "${ECR_URI}:latest"

CONTAINER_IMAGE="${ECR_URI}:latest"

cat > stacks/ecs/terraform.tfvars <<EOF
region = "ap-northeast-2"
subnet_ids = ["${SUBNET_PRIVATE1}", "${SUBNET_PRIVATE2}"]
security_group_id = "${SG_ECS_FARGATE}"
target_group_arn = "${TARGET_GROUP_ARN}"
container_image = "${CONTAINER_IMAGE}"
EOF

terraform -chdir=stacks/ecs init
terraform -chdir=stacks/ecs plan
terraform -chdir=stacks/ecs apply

# --------------------------------------------------------------------
## 15) C) Aurora MySQL (optional) — stacks/aurora-mysql
# --------------------------------------------------------------------
# Dieser Stack nutzt das aurora-mysql Modul und erstellt DB + Secret in Secrets Manager.
# Benötigt: vpc_id, subnet_ids (private), security_group_ids (Aurora SG)
cat > stacks/aurora-mysql/terraform.tfvars <<EOF
region = "ap-northeast-2"
vpc_id = "${VPC_ID}"
subnet_ids = ["${SUBNET_PRIVATE1}", "${SUBNET_PRIVATE2}"]
security_group_ids = ["${SG_AURORA}"]
cluster_identifier = "aurora-mysql-cluster"
db_name = "mydb"
EOF

terraform -chdir=stacks/aurora-mysql init
terraform -chdir=stacks/aurora-mysql plan
terraform -chdir=stacks/aurora-mysql apply

# --------------------------------------------------------------------
## 16) C) S3 (optional/empfohlen) — stacks/s3
# --------------------------------------------------------------------
# Der S3 Stack hat Defaults für cloudfront_distribution_arns, logs_account_id etc. die author-spezifisch sein können.
# Wenn du erstmal nur einen Bucket brauchst: setze diese Werte auf leer/neutral.
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET_NAME="university-bucket-${ACCOUNT_ID}-${AWS_REGION}"

cat > stacks/s3/terraform.tfvars <<EOF
region = "ap-northeast-2"
bucket_name = "${S3_BUCKET_NAME}"

# neutralisieren (später ggf. echte Werte setzen)
cloudfront_distribution_arns = []
logs_account_id = "${ACCOUNT_ID}"
ses_account_id  = "${ACCOUNT_ID}"
logs_prefix = "logs/"
ses_prefix  = "ses/"
EOF

terraform -chdir=stacks/s3 init
terraform -chdir=stacks/s3 plan
terraform -chdir=stacks/s3 apply

# --------------------------------------------------------------------
## 17) D) Lambda — stacks/lambda/*
# --------------------------------------------------------------------
# Deploye die Lambda Substacks, die du brauchst (oder alle).
for d in stacks/lambda/*; do
  [ -d "$d" ] || continue
  echo "=== LAMBDA APPLY: $d ==="
  terraform -chdir="$d" init
  terraform -chdir="$d" plan
  terraform -chdir="$d" apply
done

# APIGW benötigt 2 Lambda ARNs + 2 Invoke-ARNs (API Gateway Integration URI).
# Das Repo liefert die Invoke-ARNs NICHT als Output in den Lambda Stacks, daher bauen wir sie so:
#
# LAMBDA_ARN:     bekommst du via AWS CLI (FunctionArn)
# LAMBDA_INVOKE:  "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"
#
# Beispiel (ersetze Function Names durch DEINE Funktionen, die du an /agent & /query hängen willst):
LAMBDA_1_NAME="AgentHandlerFunction"
LAMBDA_2_NAME="<YOUR_SECOND_FUNCTION_NAME>"

LAMBDA_1_ARN=$(aws lambda get-function --function-name "${LAMBDA_1_NAME}" --query 'Configuration.FunctionArn' --output text)
LAMBDA_2_ARN=$(aws lambda get-function --function-name "${LAMBDA_2_NAME}" --query 'Configuration.FunctionArn' --output text)

LAMBDA_1_INVOKE_ARN="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_1_ARN}/invocations"
LAMBDA_2_INVOKE_ARN="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_2_ARN}/invocations"

echo "LAMBDA_1_ARN=$LAMBDA_1_ARN"
echo "LAMBDA_1_INVOKE_ARN=$LAMBDA_1_INVOKE_ARN"
echo "LAMBDA_2_ARN=$LAMBDA_2_ARN"
echo "LAMBDA_2_INVOKE_ARN=$LAMBDA_2_INVOKE_ARN"

# --------------------------------------------------------------------
## 18) D) API Gateway (REST) — stacks/apigw
# --------------------------------------------------------------------
# apigw erwartet: existing_lambda_function_arn_1/2 + existing_lambda_invoke_arn_1/2 + existing_s3_bucket_name
cat > stacks/apigw/terraform.tfvars <<EOF
region = "ap-northeast-2"
existing_lambda_function_arn_1 = "${LAMBDA_1_ARN}"
existing_lambda_invoke_arn_1   = "${LAMBDA_1_INVOKE_ARN}"
existing_lambda_function_arn_2 = "${LAMBDA_2_ARN}"
existing_lambda_invoke_arn_2   = "${LAMBDA_2_INVOKE_ARN}"
existing_s3_bucket_name        = "${S3_BUCKET_NAME}"
EOF

terraform -chdir=stacks/apigw init
terraform -chdir=stacks/apigw plan
terraform -chdir=stacks/apigw apply

API_URL=$(terraform -chdir=stacks/apigw output -raw api_invoke_url)
echo "API_URL=$API_URL"

# Test:
curl -i "${API_URL}/agent"
curl -i "${API_URL}/query"

# --------------------------------------------------------------------
## 19) D) EventBridge — stacks/eventbridge/*
# --------------------------------------------------------------------
for d in stacks/eventbridge/*; do
  [ -d "$d" ] || continue
  echo "=== EVENTBRIDGE APPLY: $d ==="
  terraform -chdir="$d" init
  terraform -chdir="$d" plan
  terraform -chdir="$d" apply
done

# --------------------------------------------------------------------
## 20) D) StepFunctions — stacks/stepfunctions/* (+ IAM Roles + LogGroups)
# --------------------------------------------------------------------
# Die StepFunctions Stacks erwarten:
# - existing_role_arn (aus passenden IAM stacks unter stacks/iam/stepfunctions/*-role)
# - log_group_name (CloudWatch Log Group muss existieren)
#
### 20.1 IAM StepFunctions Rollen deployen (falls noch nicht gemacht)
for d in stacks/iam/stepfunctions/*; do
  [ -d "$d" ] || continue
  echo "=== IAM STEPFUNCTION ROLE APPLY: $d ==="
  terraform -chdir="$d" init
  terraform -chdir="$d" plan
  terraform -chdir="$d" apply
done

### 20.2 Log Groups anlegen (Beispiel)
# Du kannst Namen frei wählen, aber sie müssen in stepfunctions tfvars eingetragen werden.
aws logs create-log-group --log-group-name "/aws/stepfunctions/AgentStepFunction" --region "${AWS_REGION}" 2>/dev/null || true
aws logs create-log-group --log-group-name "/aws/stepfunctions/EmailGenerationStepFunction" --region "${AWS_REGION}" 2>/dev/null || true
aws logs create-log-group --log-group-name "/aws/stepfunctions/QueryAgentStepFunction" --region "${AWS_REGION}" 2>/dev/null || true
aws logs create-log-group --log-group-name "/aws/stepfunctions/ComplexQueryStepFunction" --region "${AWS_REGION}" 2>/dev/null || true
aws logs create-log-group --log-group-name "/aws/stepfunctions/QueryStepFunction" --region "${AWS_REGION}" 2>/dev/null || true

### 20.3 StepFunctions deployen (du musst pro Stack tfvars setzen)
# Beispiel AgentStepFunction:
ROLE_ARN_AGENT_SFN="<SET_ME_FROM_IAM_ROLE_OUTPUT>"
LOG_GROUP_AGENT_SFN="/aws/stepfunctions/AgentStepFunction"

cat > stacks/stepfunctions/AgentStepFunction/terraform.tfvars <<EOF
region = "ap-northeast-2"
existing_role_arn = "${ROLE_ARN_AGENT_SFN}"
log_group_name = "${LOG_GROUP_AGENT_SFN}"
EOF

terraform -chdir=stacks/stepfunctions/AgentStepFunction init
terraform -chdir=stacks/stepfunctions/AgentStepFunction plan
terraform -chdir=stacks/stepfunctions/AgentStepFunction apply

# Wiederhole analog für:
# - stacks/stepfunctions/EmailGenerationStepFunction
# - stacks/stepfunctions/QueryAgentStepFunction
# - stacks/stepfunctions/ComplexQueryStepFunction
# - stacks/stepfunctions/QueryStepFunction

# --------------------------------------------------------------------
## 21) D) SES — stacks/ses (optional; Domain + Route53 erforderlich)
# --------------------------------------------------------------------
# SES Stack benötigt hosted_zone_id + domain_name + s3_bucket_name.
# Empfohlene Reihenfolge für Domain-Setup: dns -> ses -> cdn (oder dns -> cdn -> ses je nach Setup).
#
# --------------------------------------------------------------------
## 22) E) DNS (Route53) — stacks/dns (optional; echte Domain)
# --------------------------------------------------------------------
>[!WARNING]
Achtung: Default domain/records sind author-spezifisch. Du musst deine Domain setzen.
# Beispiel: Erstmal nur Hosted Zone anlegen (ohne extra records):
cat > stacks/dns/terraform.tfvars <<'EOF'
zone_name = "example.com"
dns_records = []
EOF

terraform -chdir=stacks/dns init
terraform -chdir=stacks/dns plan
terraform -chdir=stacks/dns apply

HOSTED_ZONE_ID=$(terraform -chdir=stacks/dns output -raw zone_id)
echo "HOSTED_ZONE_ID=$HOSTED_ZONE_ID"
# Danach musst du beim Domain Registrar die NameServers setzen:
terraform -chdir=stacks/dns output -json name_servers

# --------------------------------------------------------------------
## 23) E) CDN (CloudFront) — stacks/cdn (optional; Domain + S3 Origin + us-east-1)
# --------------------------------------------------------------------
# CloudFront ACM Zertifikate müssen i.d.R. in us-east-1 sein.
# Daher: temporär Region switchen:
export AWS_REGION="us-east-1"

# Du brauchst:
# - domain_name + www_domain_name
# - hosted_zone_id (aus dns)
# - s3_origin_bucket_name (dein bucket)
cat > stacks/cdn/terraform.tfvars <<EOF
region = "us-east-1"
domain_name = "example.com"
www_domain_name = "www.example.com"
hosted_zone_id = "${HOSTED_ZONE_ID}"
s3_origin_bucket_name = "${S3_BUCKET_NAME}"
EOF

terraform -chdir=stacks/cdn init
terraform -chdir=stacks/cdn plan
terraform -chdir=stacks/cdn apply

# Outputs:
CF_DOMAIN_MAIN=$(terraform -chdir=stacks/cdn output -raw cloudfront_domain_name_main)
CF_ZONE_ID_MAIN=$(terraform -chdir=stacks/cdn output -raw cloudfront_hosted_zone_id_main)
echo "CF_DOMAIN_MAIN=$CF_DOMAIN_MAIN"
echo "CF_ZONE_ID_MAIN=$CF_ZONE_ID_MAIN"

# Nach CDN: DNS Records für Root/www auf CloudFront zeigen lassen -> in stacks/dns dns_records eintragen.
# (Oder man erweitert dns_records um Alias A/AAAA Records.)

# Zurück zur Workload Region:
export AWS_REGION="ap-northeast-2"

# --------------------------------------------------------------------
## 24) SES deployen (wenn Domain vorhanden)
# --------------------------------------------------------------------
cat > stacks/ses/terraform.tfvars <<EOF
region = "ap-northeast-2"
domain_name = "example.com"
hosted_zone_id = "${HOSTED_ZONE_ID}"
s3_bucket_name = "${S3_BUCKET_NAME}"
EOF

terraform -chdir=stacks/ses init
terraform -chdir=stacks/ses plan
terraform -chdir=stacks/ses apply

# --------------------------------------------------------------------
## 25) Destroy / Cleanup (umgekehrte Reihenfolge!)
# --------------------------------------------------------------------
>[!IMPORTANT]
Wichtig: Immer von "oben" nach "unten" destroyen, damit Dependencies sauber wegfallen.
#
# Beispiel (Workload):
terraform -chdir=stacks/apigw destroy
for d in stacks/lambda/*; do [ -d "$d" ] && terraform -chdir="$d" destroy; done
for d in stacks/stepfunctions/*; do [ -d "$d" ] && terraform -chdir="$d" destroy; done
for d in stacks/eventbridge/*; do [ -d "$d" ] && terraform -chdir="$d" destroy; done
terraform -chdir=stacks/ecs destroy
terraform -chdir=stacks/ecr destroy
terraform -chdir=stacks/nlb destroy
terraform -chdir=stacks/aurora-mysql destroy
terraform -chdir=stacks/s3 destroy
terraform -chdir=stacks/kms/tenant-master-key destroy
terraform -chdir=stacks/network destroy
# (oder vpc + security_groups falls genutzt)
#
# Domain:
# export AWS_REGION="us-east-1"
# terraform -chdir=stacks/cdn destroy
# export AWS_REGION="ap-northeast-2"
# terraform -chdir=stacks/ses destroy
# terraform -chdir=stacks/dns destroy
#
# Org/Admin:
# terraform -chdir=stacks/iam-identity-center destroy
# terraform -chdir=stacks/org-billing destroy
# terraform -chdir=stacks/organizations destroy
