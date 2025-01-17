variable "profile" {
  default = "default"
}

variable "region" {
  default = "cn-hangzhou"
}

provider "alicloud" {
  region  = var.region
  profile = var.profile
}

data "alicloud_emr_main_versions" "default" {
  cluster_type = ["HADOOP"]
}

data "alicloud_vpcs" "default" {
  is_default = true
}

data "alicloud_vswitches" "all" {
  vpc_id = data.alicloud_vpcs.default.ids.0
}

module "security_group" {
  region  = var.region
  profile = var.profile
  source  = "alibaba/security-group/alicloud"
  vpc_id  = data.alicloud_vpcs.default.ids.0
  version = "~> 2.0"
}

module "emr-hadoop" {
  source = "../.."
  region = var.region

  create = true

  emr_version = data.alicloud_emr_main_versions.default.main_versions.0.emr_version
  charge_type = "PostPaid"

  vswitch_id        = data.alicloud_vswitches.all.ids.0
  security_group_id = module.security_group.this_security_group_id

  high_availability_enable = true
  is_open_public_ip        = true
  ssh_enable               = true
  master_pwd               = "YourPassword123!"
  zone_id                  = data.alicloud_vswitches.all.vswitches.0.zone_id
}