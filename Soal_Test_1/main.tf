resource "alicloud_vpc" "vpc" {
  vpc_name       = "vpc-stockbit"
  cidr_block = "192.168.0.0/16"
}

resource "alicloud_vswitch" "vswprivate" {
  vswitch_name      = "stockbit-private"
  vpc_id            = alicloud_vpc.vpc.id
  cidr_block        = "192.168.0.0/24"
  zone_id           = "ap-southeast-5a"
}

resource "alicloud_vswitch" "vswpublic" {
  vswitch_name      = "stockbit-public"
  vpc_id            = alicloud_vpc.vpc.id
  cidr_block        = "192.168.1.0/24"
  zone_id           = "ap-southeast-5a"
}

resource "alicloud_security_group" "sgstockbit" {
  name   = "sg-stockbit"
  vpc_id = alicloud_vpc.vpc.id
}

resource "alicloud_nat_gateway" "natprivate" {
  depends_on           = [alicloud_vswitch.vswprivate]
  vpc_id               = alicloud_vpc.vpc.id
  specification        = "Small"
  nat_gateway_name     = "nat-private"
  payment_type         = "PayAsYouGo"
  vswitch_id           = alicloud_vswitch.vswprivate.id
  nat_type             = "Enhanced"
}


resource "alicloud_eip_address" "eip" {
}

resource "alicloud_eip_association" "eip_asso" {
  allocation_id = alicloud_eip_address.eip.id
  instance_id   = alicloud_nat_gateway.natprivate.id
}

variable "ess_name" {
  default = "essscalingconfig"
}

data "alicloud_instance_types" "in_types" {
  availability_zone = "ap-southeast-5a"
  cpu_core_count    = 1
  memory_size       = 2
}

data "alicloud_images" "img_list" {
  name_regex  = "^centos_7_9.*64"
  most_recent = true
  owners      = "system"
}

resource "alicloud_ess_scaling_group" "ess_group" {
  min_size           = 2
  max_size           = 5
  scaling_group_name = "${var.ess_name}"
  removal_policies   = ["OldestInstance", "NewestInstance"]
  vswitch_ids        = ["${alicloud_vswitch.vswprivate.id}"]
}

resource "alicloud_ess_scaling_configuration" "default" {
  scaling_group_id  = "${alicloud_ess_scaling_group.ess_group.id}"
  image_id          = "${data.alicloud_images.img_list.images.0.id}"
  instance_type     = "${data.alicloud_instance_types.in_types.instance_types.0.id}"
  security_group_id = "${alicloud_security_group.sgstockbit.id}"
  force_delete      = true
  active            = true
}

resource "alicloud_ess_scaling_rule" "ess_rule" {
  scaling_group_id          = "${alicloud_ess_scaling_group.ess_group.id}"
  metric_name               = "CpuUtilization"
  target_value              = 45
  scaling_rule_type         = "SimpleScalingRule"
  adjustment_type           = "QuantityChangeInCapacity"
  adjustment_value          = 1
}

resource "alicloud_ess_alarm" "ess_alarm" {
  name                = "tf-Autoscaling"
  description         = "Alarming Autoscaling"
  alarm_actions       = ["${alicloud_ess_scaling_rule.ess_rule.ari}"]
  scaling_group_id    = "${alicloud_ess_scaling_group.ess_group.id}"
  metric_type         = "system"
  metric_name         = "CpuUtilization"
  period              = 60
  statistics          = "Average"
  threshold           = 40
  comparison_operator = ">="
  evaluation_count    = 2
}