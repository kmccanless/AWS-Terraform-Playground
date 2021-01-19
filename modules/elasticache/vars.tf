variable "region" {
  default = "us-east-2"
}
variable "component" {
  default = "cache"
}
variable "environment" {
  default = "staging"
}
variable "profile" {
  default = "XXXXXXXXXXX"
}
variable "project" {
  default = "rds-test"
}
variable "instance_type" {
  default = "cache.t2.micro"
}
variable "engine_version" {
  default = "5.0.6"
}
variable "parameter_group_name" {
  default = "default.redis5.0"
}