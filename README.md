# Three-Tier AWS Architecture — Automated with Terraform

[![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-FF9900?style=flat-square&logo=amazon-aws&logoColor=white)](https://aws.amazon.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

> Infrastructure as Code for a production-style three-tier web architecture — VPC, load balancers, auto-scaling compute, and a data tier, spread across 3 Availability Zones. Built as a modular, staged Terraform deployment with remote state.

---

## 📖 Overview

This repository automates the deployment of a three-tier AWS architecture using Terraform:

- **Web tier** — Next.js frontend behind an internet-facing Application Load Balancer
- **App tier** — Node.js/Express backend behind an internal (private) Application Load Balancer
- **Data tier** — MySQL, isolated in private subnets with no internet exposure

Everything is spread across **3 Availability Zones** for redundancy, with strict security-group chaining so each tier only ever accepts traffic from the tier directly in front of it — never directly from the internet, and never skipping a layer.

This started as a manually-deployed version of the same architecture (built and debugged by hand) and was rebuilt from scratch as fully automated, modular Terraform to eliminate repetitive manual setup and make the whole environment reproducible with a handful of commands.

---

## 🏗️ Architecture

```
                            Internet
                               │
                    ┌──────────▼──────────┐
                    │   External ALB      │  (public subnets, internet-facing)
                    │   Internet-facing    │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                 │
        ┌─────▼─────┐   ┌──────▼─────┐    ┌──────▼─────┐
        │ Frontend   │   │ Frontend   │    │ Frontend   │   AZ-1a / 1b / 1c
        │ EC2 (ASG)  │   │ EC2 (ASG)  │    │ EC2 (ASG)  │   Next.js + Nginx
        └─────┬──────┘   └─────┬──────┘    └─────┬──────┘
              │                │                 │
                    ┌──────────▼──────────┐
                    │   Internal ALB       │  (private subnets, internal only)
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                 │
        ┌─────▼─────┐   ┌──────▼─────┐    ┌──────▼─────┐
        │ Backend    │   │ Backend    │    │ Backend    │   AZ-1a / 1b / 1c
        │ EC2 (ASG)  │   │ EC2 (ASG)  │    │ EC2 (ASG)  │   Node.js + Express
        └─────┬──────┘   └─────┬──────┘    └─────┬──────┘
              │                │                 │
        ┌─────▼─────┐   ┌──────▼─────┐    ┌──────▼─────┐
        │ Database   │   │ Database   │    │ Database   │   AZ-1a / 1b / 1c
        │ EC2 (MySQL)│   │ EC2 (MySQL)│    │ EC2 (MySQL)│   ⚠️ see limitation below
        └────────────┘   └────────────┘    └────────────┘
```

A NAT Gateway (single, in AZ-1a's public subnet) gives private-subnet resources outbound internet access — for package installs and updates — without ever being reachable *from* the internet.

Full diagram: [`docs/architecture-diagram.png`](docs/architecture-diagram.png.png)

---

## 💡 Technology Stack

| Layer | Technology |
|---|---|
| Infrastructure as Code | Terraform (`>= 1.5.0`), AWS provider `~> 5.0` |
| Remote state | S3 (versioned, encrypted) + DynamoDB (locking) |
| Networking | AWS VPC, public/private subnets across 3 AZs, IGW, single NAT Gateway |
| Compute | EC2 via Auto Scaling Groups + Launch Templates, `user_data` bootstrap scripts |
| Load balancing | 2× Application Load Balancer (1 internet-facing, 1 internal) |
| Frontend | Next.js + Nginx |
| Backend | Node.js + Express |
| Database | MySQL on EC2 (see [known limitation](known-limitation--database-tier)) |

---

## 📁 Project Structure

```
terraform-three-tier-aws/
│
├── modules/                    # Reusable, environment-agnostic infrastructure logic
│   ├── networking/             # VPC, 4-tier subnets × 3 AZs, IGW, NAT, route tables
│   ├── security/                # Chained security groups (5 layers)
│   ├── load_balancers/          # External + internal ALBs, target groups, listeners
│   ├── compute/                  # Auto Scaling Groups for frontend + backend
│   └── database/                 # Database tier (see limitation note)
│
├── envs/
│   └── dev/                     # Environment-specific configuration — this is what you run
│       ├── backend.tf            # Points to the S3 bucket created in bootstrap/
│       ├── providers.tf
│       ├── variables.tf
│       ├── main.tf               # Wires all modules together
│       ├── outputs.tf
│       └── terraform.tfvars.example
│
├── docs/
│   └── architecture-diagram.png
│
├── .gitignore
└── README.md
```

**Why this structure:** `modules/` is shared and environment-agnostic — the same networking, security, and compute logic gets reused whether you're standing up `dev`, `staging`, or `prod`. Only the values in `envs/<environment>/` change between them. Adding a new environment later is copy `envs/dev/` → `envs/staging/`, adjust `.tfvars` and the backend state key — not a redesign.

---

## 🔐 Security Design

Security groups are chained so each tier only trusts the one immediately in front of it:

```
Internet → External ALB → Frontend → Internal ALB → Backend → Database
```

| Security Group | Allows inbound from |
|---|---|
| External ALB | `0.0.0.0/0` on port 80/443 |
| Frontend | External ALB only, port 3000 |
| Internal ALB | Frontend only, port 80 |
| Backend | Internal ALB only, port 3001 |
| Database | Backend only, port 3306 |

No tier is ever reachable by skipping a layer — the database is unreachable from the internet even indirectly, and the backend can never be hit directly by a browser.

---

## ⚙️ Prerequisites

- An AWS account with an IAM user/role that has permissions to create VPC, EC2, ALB, S3, DynamoDB, and IAM resources
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.5.0`
- An existing EC2 key pair in your target region (for SSH access)

---

## 🚀 Setup — Step by Step

### 1. Bootstrap the remote backend (once, before anything else)

Terraform's state needs somewhere durable and shared to live — this creates that.

```bash
cd bootstrap
terraform init
terraform apply -var="state_bucket_name=YOUR-UNIQUE-BUCKET-NAME"
```

S3 bucket names are globally unique across **all** AWS accounts, not just yours. Get a name that's guaranteed free by appending your account ID:

```bash
aws sts get-caller-identity --query "Account" --output text
# use something like: three-tier-terraform-state-<that-account-id>
```

### 2. Point `envs/dev` at your new bucket

Edit `envs/dev/backend.tf` and replace the placeholder bucket name with the one you just created.

### 3. Set your real variable values

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual key pair name and database credentials. This file is git-ignored — your real values never get committed.

### 4. Build in stages — don't apply everything at once

Applying all five modules simultaneously means debugging multiple unrelated failures at the same time if something's wrong. Build one layer at a time instead:

```bash
terraform init

terraform apply -target=module.networking
# confirm the VPC and subnets exist in the AWS console before continuing

terraform apply -target=module.security
terraform apply -target=module.load_balancers
# target groups will show "unhealthy" here — expected, nothing's registered yet

terraform apply -target=module.compute
# targets should start passing health checks once instances finish booting

terraform apply -target=module.database

terraform apply   # final pass — catches anything the targeted applies missed
```

### 5. Test end-to-end

```bash
terraform output external_alb_dns
```

Open that DNS name in a browser and confirm the full request path works: browser → external ALB → frontend → internal ALB → backend → database.

### 6. Tear down

```bash
terraform destroy
```

The bootstrap S3 bucket has `prevent_destroy` set, so it survives even a full `terraform destroy` inside `bootstrap/` — remove that lifecycle block deliberately if you want to delete it too.

---

## Known Limitation — Database Tier

The `database` module, as written, creates **one independent MySQL EC2 instance per Availability Zone with no replication between them**. It matches the architecture diagram visually, but it is **not** a working multi-AZ database — it's three separate, unsynced databases.

Two real paths forward, documented as comments in `modules/database/main.tf`:

1. **Build actual MySQL primary/replica replication** inside the `user_data` bootstrap script — legitimate infrastructure work, genuinely non-trivial, and a good standalone follow-up project.
2. **Swap the module for `aws_db_instance` with `multi_az = true`** — lets RDS handle replication, failover, and backups automatically, while still being fully Terraform-managed.

This repo currently ships option 1's *scaffolding* (three independent instances) without the replication logic itself — flagged here deliberately rather than left for someone to discover in production.

---

## 🐛 Issues Encountered & Solutions

Real errors hit while building this, kept here rather than smoothed away:

**`InvalidAMIID.NotFound`** — a hardcoded AMI ID from an early draft no longer existed in-region (AMI IDs are region-specific and get deprecated). Fixed by replacing the static ID with a Terraform `data "aws_ami"` lookup that always resolves to the current Amazon Linux image at apply time.

**`InvalidParameterCombination: groupName cannot be used with the parameter subnet`** — an EC2 instance was referencing its security group by name (`security_groups`), which is a legacy EC2-Classic argument. VPC-based instances require `vpc_security_group_ids` (by ID) instead.

**`InvalidKeyPair.NotFound`** — `key_name` included a `.pem` extension. AWS key pair *names* never include the file extension; that only applies to the downloaded private key file.

**Empty `public_ip` output** — the public subnet didn't have `map_public_ip_on_launch = true`, so instances launched without a public IP even with a valid route to the Internet Gateway. Also learned that this setting doesn't retroactively apply to already-running instances — an Elastic IP is the more reliable fix for a stable address.

**`BucketAlreadyExists` on the state bucket** — S3 bucket names are global across all AWS accounts, not per-account. A descriptive but common name (`book-review-terraform-state`) was already taken by someone else entirely. Fixed by appending the AWS account ID to guarantee uniqueness.

**Module path resolution (`../modules/networking` vs `../../modules/networking`)** — the number of `../` needed depends on how many directories separate the calling `.tf` file from the project root. Moving the root configuration into `envs/dev/` (two levels deep) required `../../modules/...`, not the single `../modules/...` that would work from the project root directly.

---

## 📚 What I Learned

- **Data sources over hardcoded values** — anything that can go stale (AMI IDs, especially) should be looked up dynamically, not pinned as a literal string.
- **VPC vs EC2-Classic arguments aren't interchangeable** — `security_groups` and `vpc_security_group_ids` look similar but solve different eras of AWS networking; using the wrong one throws an error that doesn't obviously point at the fix.
- **Key pair names and key files are different things** — the `.pem` extension belongs to the file on disk, never to the name registered with AWS.
- **State files are sensitive** — they're a live snapshot of real infrastructure (IDs, IPs, sometimes secrets), which is why they're excluded from version control and stored encrypted in S3 rather than passed around directly.
- **Relative paths are directory-distance-dependent** — the same module reference needs a different number of `../` depending on how deeply nested the calling configuration is; this becomes obvious once visualized as literal folder navigation.
- **Building in stages surfaces problems faster** — applying five interdependent modules at once means debugging several unrelated failures simultaneously; targeting one module at a time isolates each issue.

---

## 🔮 Future Improvements

- [ ] Real MySQL replication in the database module, or a full swap to RDS Multi-AZ
- [ ] Remote state for additional environments (`staging`, `prod`) alongside `dev`
- [ ] HTTPS via ACM certificates on both load balancers
- [ ] CloudWatch alarms and centralized logging
- [ ] CI/CD pipeline for `terraform plan`/`apply` on merge (GitHub Actions)
- [ ] Terraform variable validation blocks and stricter type constraints

---

## Manual Build Origins

This automated version follows an earlier, manually-deployed build of the same architecture — clicked together through the AWS Console and debugged by hand (security group misconfigurations, CORS failures, an Nginx `proxy_pass` trailing-slash bug, among others). That version's documentation is preserved separately as a record of the original troubleshooting process this automation was built to eliminate.

---

## 👤 Author

**[Samuel Ehizokhai]** — DevOps/Cloud Engineer
[LinkedIn](https://linkedin.com/in/samuel-ehizokhai) · [GitHub](https://github.com/ehizokhaisamuel-netizen)

---

## 📄 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.
