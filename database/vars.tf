variable "instance_type" {
  default = "db.t2.small"
}
variable "db_name" {
  default = "TestDB"
}
variable "min_capacity" {
  default = 1
}
variable "max_capacity" {
  default = 64
}
variable "environment" {
  default = "development"
}
variable "db_username" {
  default = "admin1"
}
variable "db_password" {
  default = "XXXXXXXXXX"
}
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
  default = "XXXXXXXXXXX"
}
