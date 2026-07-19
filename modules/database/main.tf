# IMPORTANT LIMITATION — read before relying on this module:
#
# This creates one MySQL EC2 instance per AZ (matching the architecture diagram
# visually), but there is NO replication configured between them. As written,
# this is 3 independent, unsynced databases — not a working multi-AZ database.
#
# To make this genuinely functional, you have two real options:
#   1. Build actual MySQL primary/replica replication yourself inside the
#      user_data script below — a legitimate but substantial undertaking.
#   2. Replace this entire module with a single `aws_db_instance` resource
#      using `multi_az = true` (Amazon RDS) — replication, failover, and
#      backups are handled for you. This is what real teams use in production.
#
# Recommended path: get end-to-end `terraform apply` working with this module
# as-is first, then decide which of the two options above to pursue —
# and document that decision. That comparison is a genuinely strong thing
# to write up afterward.

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "database" {
  for_each                = var.data_subnet_ids
  ami                      = data.aws_ami.amazon_linux.id
  instance_type            = var.instance_type
  subnet_id                = each.value
  key_name                 = var.key_name
  vpc_security_group_ids   = [var.database_sg_id]

  tags = { Name = "${var.project_name}-db-${each.key}" }
}
