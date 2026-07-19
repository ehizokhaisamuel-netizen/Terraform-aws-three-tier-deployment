output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = { for k, s in aws_subnet.public : k => s.id }
}

output "web_private_subnet_ids" {
  value = { for k, s in aws_subnet.web_private : k => s.id }
}

output "app_private_subnet_ids" {
  value = { for k, s in aws_subnet.app_private : k => s.id }
}

output "data_private_subnet_ids" {
  value = { for k, s in aws_subnet.data_private : k => s.id }
}
