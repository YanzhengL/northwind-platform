output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

# Built from local.azs, so every list below is in the same AZ order.
output "private_subnet_ids" {
  description = "Private subnet IDs, in AZ order (nodes and pods)."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "public_subnet_ids" {
  description = "Public subnet IDs, in AZ order (load balancers and NAT)."
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_route_table_ids" {
  description = "Private route table IDs, in AZ order (for the S3 gateway endpoint)."
  value       = [for az in local.azs : aws_route_table.private[az].id]
}
