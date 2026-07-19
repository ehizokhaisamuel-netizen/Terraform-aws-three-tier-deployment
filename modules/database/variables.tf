variable "project_name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "data_subnet_ids" {
  type = map(string)
}

variable "database_sg_id" {
  type = string
}
