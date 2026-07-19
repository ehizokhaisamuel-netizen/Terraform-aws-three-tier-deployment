variable "project_name" {
  description = "Name prefix used for tagging all resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of Availability Zones to deploy across (must match the architecture diagram, e.g. 3 AZs)"
  type        = list(string)
}
