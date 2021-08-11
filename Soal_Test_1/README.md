# Section 1. Terraform Test

## Goals

User will create terraform config with these specifications.

- 1 VPC
- 1 public subnet (vSwitch)
- 1 subnet private (vSwitch) which mounted to 1 NAT Gateway
- 1 Autoscaling group with minSize 2 instances and maxSize 5 instances, scaling rule threshold >= 45% for CPU Usage. These instances will be created in the private subnet.  

## Prerequisites
- secret id and secret key
- installing terraform

## Proof Of Concept

For the first, we will create a VPC.
```
resource "alicloud_vpc" "vpc" {
  vpc_name   = "vpc-stockbit"
  cidr_block = "192.168.0.0/16"
}
```

Then, create vSwitches to separate the public and private.
```
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
```

Next, add security group because it will be needed when creating the instance.
```
resource "alicloud_security_group" "sgstockbit" {
  name   = "sg-stockbit"
  vpc_id = alicloud_vpc.vpc.id
}
```

To attach our private vSwitch to NAT Gateway, add this lines.
```
resource "alicloud_nat_gateway" "natprivate" {
  depends_on           = [alicloud_vswitch.vswprivate]
  vpc_id               = alicloud_vpc.vpc.id
  specification        = "Small"
  nat_gateway_name     = "nat-private"
  payment_type         = "PayAsYouGo"
  vswitch_id           = alicloud_vswitch.vswprivate.id
  nat_type             = "Enhanced"
}
```

Because NAT Gateway not have EIP yet to associate with it, add the EIP and associate.
```
resource "alicloud_eip_address" "eip" {
}

resource "alicloud_eip_association" "eip_asso" {
  allocation_id = alicloud_eip_address.eip.id
  instance_id   = alicloud_nat_gateway.natprivate.id
}
```

I try to use variable to define ess_name, it's optional and you can ignore this and define your scaling group name by yourself.
```
variable "ess_name" {
  default = "essscalingconfig"
}
```

To specify our instance type, from the goals it use type t2.medium. In Alibaba, we just need to see the similar specification which using 2 vCPUs and 4 GB Memory.

But in this config, i'll set it to 1 vCPU and 2 GB Memory.
```
data "alicloud_instance_types" "in_types" {
  availability_zone = "ap-southeast-5a"
  cpu_core_count    = 1
  memory_size       = 2
}
```

After that, we will need to specify the image we use.
```
data "alicloud_images" "img_list" {
  name_regex  = "^centos_7_9.*64"
  most_recent = true
  owners      = "system"
}
```

In the final chapter, you will need to add scaling group, scaling rule and its alarm.

You can see that the 'min_size' set to 2 and max_size set to 5. Also, when CPU >= 45%, it will trigger 'add an instance as adjustment'.
```
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
```