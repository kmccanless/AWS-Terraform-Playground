output "cluster_id" {
  value = module.rds_cluster_aurora_mysql_serverless.cluster_identifier
}
output "cluster_sg"{
  value = module.rds_cluster_aurora_mysql_serverless.cluster_security_groups
}
output "cluster_endpoint" {
  value = module.rds_cluster_aurora_mysql_serverless.endpoint
}
output "database_name" {
  value = module.rds_cluster_aurora_mysql_serverless.database_name
}
output "database_sg" {
  value = aws_security_group.mysql_sg.id
}