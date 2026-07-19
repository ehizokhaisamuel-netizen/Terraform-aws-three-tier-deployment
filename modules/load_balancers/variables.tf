variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = map(string)
}

variable "app_subnet_ids" {
  type = map(string)
}

variable "external_alb_sg_id" {
  type = string
}

variable "internal_alb_sg_id" {
  type = string
}
