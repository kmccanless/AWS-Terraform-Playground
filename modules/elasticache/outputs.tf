output "elasticache_arn" {
  value = aws_elasticache_cluster.redis.arn
}

output "elasticache_id" {
  value = aws_elasticache_cluster.redis.id
}

output "elasticache_port" {
  value = aws_elasticache_cluster.redis.port
}

output "elasticache_address" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.address
}

output "elasticache_sg" {
  value = aws_security_group.elasticache_sg.id
}