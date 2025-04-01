output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_public_subnet_ids" {
  value = [for i in aws_subnet.web : i.id]
}

output "vpc_private_subnet_ids" {
  value = [for i in aws_subnet.app : i.id]
}