output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets_ids" {
  description = "List with the Public Subnets IDs"
  value       = aws_subnet.public_subnets.*.id
}

output "public_subnets_route_table_id" {
  description = "ID of the Route Tables used on Public networks"
  value       = aws_route_table.public_subnets_route_table.*.id
}

output "nat_gw_ids" {
  description = "List with the IDs of the NAT Gateways created on public subnets to provide internet to private subnets"
  value       = aws_nat_gateway.nat_gw.*.id
}
output "private_subnets_ids" {
  description = "List with the Private Subnets IDs"
  value       = aws_subnet.private_subnets.*.id
}

output "private_subnets_route_table_id" {
  description = "ID of the Route Table used on Private networks"
  value       = aws_route_table.private_subnets_route_table.*.id
}
