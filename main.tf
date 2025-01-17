provider "alicloud" {
  profile                 = var.profile != "" ? var.profile : null
  shared_credentials_file = var.shared_credentials_file != "" ? var.shared_credentials_file : null
  region                  = var.region != "" ? var.region : null
  skip_region_validation  = var.skip_region_validation
  configuration_source    = "terraform-alicloud-modules/emr-hadoop"
}

data "alicloud_emr_instance_types" "default" {
  destination_resource  = "InstanceType"
  cluster_type          = "HADOOP"
  support_local_storage = var.support_local_storage
  instance_charge_type  = var.charge_type
  support_node_type     = ["MASTER", "CORE", "TASK", "GATEWAY"]
  zone_id               = var.zone_id
}

data "alicloud_emr_disk_types" "data_disk" {
  destination_resource = "DataDisk"
  cluster_type         = "HADOOP"
  instance_charge_type = var.charge_type
  instance_type        = data.alicloud_emr_instance_types.default.types.0.id
  zone_id              = var.zone_id == "" ? data.alicloud_emr_instance_types.default.types.0.zone_id : var.zone_id
}

data "alicloud_emr_disk_types" "system_disk" {
  destination_resource = "SystemDisk"
  cluster_type         = "HADOOP"
  instance_charge_type = var.charge_type
  instance_type        = data.alicloud_emr_instance_types.default.types.0.id
  zone_id              = var.zone_id == "" ? data.alicloud_emr_instance_types.default.types.0.zone_id : var.zone_id
}

resource "random_uuid" "this" {}

resource "alicloud_ram_role" "default" {
  count = var.create ? 1 : 0

  name        = var.ram_role_name == "" ? substr("tf-ram-role-for-hadoop-${replace(random_uuid.this.result, "-", "")}", 0, 32) : var.ram_role_name
  document    = <<EOF
    {
        "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Effect": "Allow",
            "Principal": {
            "Service": [
                "emr.aliyuncs.com",
                "ecs.aliyuncs.com"
            ]
            }
        }
        ],
        "Version": "1"
    }
    EOF
  description = "The ram role used to create a emr cluster"
  force       = true
}

resource "alicloud_emr_cluster" "this" {
  count = var.create ? 1 : 0

  name         = var.emr_cluster_name
  emr_ver      = var.emr_version
  cluster_type = "HADOOP"

  zone_id           = var.zone_id == "" ? data.alicloud_emr_instance_types.default.types.0.zone_id : var.zone_id
  security_group_id = var.security_group_id
  vswitch_id        = var.vswitch_id

  user_defined_emr_ecs_role = alicloud_ram_role.default.0.name
  high_availability_enable  = var.high_availability_enable
  ssh_enable                = var.ssh_enable
  master_pwd                = var.master_pwd
  charge_type               = var.charge_type
  is_open_public_ip         = var.is_open_public_ip

  dynamic "host_group" {
    for_each = var.host_groups
    content {
      host_group_name   = lookup(host_group.value, "host_group_name", null)
      host_group_type   = lookup(host_group.value, "host_group_type", null)
      node_count        = lookup(host_group.value, "node_count", null)
      disk_count        = lookup(host_group.value, "disk_count", null)
      instance_type     = lookup(host_group.value, "instance_type", var.instance_type != "" ? var.instance_type : data.alicloud_emr_instance_types.default.types.0.id)
      disk_type         = lookup(host_group.value, "disk_type", var.disk_type != "" ? var.disk_type : data.alicloud_emr_disk_types.data_disk.types.0.value)
      disk_capacity     = lookup(host_group.value, "disk_capacity", var.disk_capacity != 0 ? var.disk_capacity : (data.alicloud_emr_disk_types.data_disk.types.0.min > 160 ? data.alicloud_emr_disk_types.data_disk.types.0.min : 160))
      sys_disk_type     = lookup(host_group.value, "sys_disk_type", var.system_disk_type != "" ? var.system_disk_type : data.alicloud_emr_disk_types.system_disk.types.0.value)
      sys_disk_capacity = lookup(host_group.value, "sys_disk_capacity", var.system_disk_capacity != 0 ? var.system_disk_capacity : (data.alicloud_emr_disk_types.system_disk.types.0.min > 160 ? data.alicloud_emr_disk_types.system_disk.types.0.min : 160))
    }
  }
}