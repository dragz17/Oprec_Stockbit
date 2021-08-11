# Section 1. Terraform Test

## Goals

User will create terraform config with these specifications.

- 1 VPC
- 1 public subnet (vSwitch)
- 1 subnet private (vSwitch) which mounted to 1 NAT Gateway
- 1 Autoscaling group with minSize 2 instances and maxSize 5 instances, scaling rule threshold >= 45% for CPU Usage. These instances will be created in the private subnet.  

## Prerequisites
- access key and secret key
- install terraform

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

You can see that the 'min_size' set to 2 and max_size set to 5. Also, when CPU >= 40%, it will trigger 'add an instance as adjustment'.
> Nb. sorry, it's my typo to set threshold to 40%
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

## Screenshots

1. inside directory
![image](https://user-images.githubusercontent.com/20719811/129022106-5ecbad61-cc13-41a2-bc8a-37b154e7bbae.png)

2. Export access key and secret key
![image](https://user-images.githubusercontent.com/20719811/129022192-e3c79d7b-7334-466e-9c0b-244c900cdc99.png)

3. VPC been created with 2 vSwitch
![image](https://user-images.githubusercontent.com/20719811/129022395-a0a05bb8-04dc-41c4-a3eb-62212b1c51ef.png)

4. Attach NAT to private vSwitch
![image](https://user-images.githubusercontent.com/20719811/129022478-65ff8de2-0196-4900-9670-0650a75dc2b7.png)

5. Scaling Group with minimum instance 2 and maximum instance 5
![image](https://user-images.githubusercontent.com/20719811/129022569-5f693f2a-0389-4660-bd1a-3681c14ee478.png)

6. Scaling Rule will trigger instanceAdd 1 instance if reaching threshold
![image](https://user-images.githubusercontent.com/20719811/129022678-6cb6d029-8ce4-4647-bc57-0adf79922f80.png)

7. Treshold 40, 2 consecutive times, it will trigger scaling rule.
![image](https://user-images.githubusercontent.com/20719811/129022862-95ee4480-b2f0-4777-a0db-3264a9fe1cee.png)

