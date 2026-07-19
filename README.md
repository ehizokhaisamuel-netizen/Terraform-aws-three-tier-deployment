# Three-Tier AWS Architecture — Terraform

Automates the three-tier deployment shown in the architecture diagram: an external ALB
routing to a Next.js frontend, an internal ALB routing to a Node.js/Express backend, and
a MySQL data tier — spread across 3 Availability Zones with public/private subnet isolation.

## Structure

```
terraform-three-tier-aws/
├── bootstrap/          # one-time remote state setup (run first, alone)
├── modules/
│   ├── networking/      # VPC, subnets, IGW, NAT, route tables
│   ├── security/        # chained security groups
│   ├── load_balancers/  # external + internal ALBs
│   ├── compute/         # Auto Scaling Groups (frontend, backend)
│   └── database/        # MySQL EC2 instances (see limitation note in module)
└── envs/
    └── dev/              # environment-specific wiring — this is what you run
```

## Setup — step by step

### 1. Bootstrap the remote backend (once)

```bash
cd bootstrap
terraform init
terraform apply -var="state_bucket_name=YOUR-UNIQUE-BUCKET-NAME"
```

Bucket names are globally unique across all AWS accounts. Get a safe unique name with:
```bash
aws sts get-caller-identity --query "Account" --output text
# use: your-project-terraform-state-<that-account-id>
```

### 2. Point envs/dev at your bucket

Edit `envs/dev/backend.tf` and replace `REPLACE-WITH-YOUR-BUCKET-NAME` with the bucket
name you just created.

### 3. Set your real variable values

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your actual key pair name, db username/password
```

### 4. Build in stages — don't apply everything at once

```bash
terraform init

terraform apply -target=module.networking
# confirm VPC + subnets in the AWS console before continuing

terraform apply -target=module.security
terraform apply -target=module.load_balancers
# targets will show "unhealthy" here — expected, nothing's registered yet

terraform apply -target=module.compute
# targets should start passing health checks once instances boot

terraform apply -target=module.database

terraform apply   # final pass, catches anything targeted applies missed
```

### 5. Test end-to-end

```bash
terraform output external_alb_dns
```
Open that DNS name in a browser and confirm the full path works: browser → external ALB
→ frontend → internal ALB → backend → database.

## Known limitation — read before relying on the database module

The database module creates one MySQL EC2 instance per AZ with **no replication between
them**. It matches the architecture diagram visually but is not a working multi-AZ
database as-is. See the comment block at the top of `modules/database/main.tf` for the
two real paths forward (build actual replication, or swap to RDS Multi-AZ).

## Tearing down

```bash
cd envs/dev
terraform destroy
```
The bootstrap S3 bucket has `prevent_destroy` set — it won't be deleted even if you
run `terraform destroy` inside `bootstrap/`. Remove that lifecycle block deliberately
if you ever want to tear it down too.
