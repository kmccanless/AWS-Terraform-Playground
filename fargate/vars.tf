variable "namespace" {
  default = "km"
}
variable "project" {
  default = "rds-test"
}
variable "region" {
  default = "us-east-2"
}
variable "component" {
  default = "database"
}
variable "profile" {
  default = "XXXXXXXXXX"
}
variable "idle_timeout" {
  default = 120
}
variable "certificate_arn" {
  default = "XXXXXXXXXXX"
}
variable "image_name" {
  default = "kmccanless/redis-mysql-node-app"
}
variable "container_name" {
  default = "sample-app"
}
variable "cloudwatch_log_group" {
  default = "flask-ecs"
}
variable "zone_id" {
  default = "XXXXXXXXXXXXXX"
  description = "Route53 Hosted Zone Id"
}