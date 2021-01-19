variable "environment" {
  default = "development"
}
variable "project" {
  default = "rds-test"
}
variable "region" {
  default = "us-east-2"
}
variable "component" {
  default = "network"
}
variable "profile" {
  default = "XXXXXXXX"
}
variable "cidr_block" {
  default = "10.0.0.0/16"
}
variable "availability_zones" {
  default = ["us-east-2a", "us-east-2b"]
}
variable "private_subnets_cidrs_per_availability_zone" {
  default = ["10.0.128.0/19", "10.0.160.0/19", "10.0.192.0/19" ]
}
variable "public_subnets_cidrs_per_availability_zone" {
  default = [ "10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19" ]
}
variable "name_prefix" {
  default = "km"
}