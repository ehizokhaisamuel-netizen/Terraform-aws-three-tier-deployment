
# backend.tf
terraform {
  backend "s3" {
    bucket       = "book-review-terraform-state-306601824372"
    key          = "three-tier-app/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
