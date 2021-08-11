# Oprec_Stockbit

In this section, you'll see two different folders which will be directing you to specific test.  

To check the recruitment test, pls hit this button

## [Section 1. Terraform Test](./Soal_Test_1)
User will create terraform config with these specifications.

- 1 VPC
- 1 public subnet (vSwitch)
- 1 subnet private (vSwitch) which mounted to 1 NAT Gateway
- 1 Autoscaling group with minSize 2 instances and maxSize 5 instances, scaling rule threshold >= 45% for CPU Usage. These instances will be created in the private subnet.  


## [Section 2. CI/CD Test](./Soal_Test_2)
User will create CI/CD flow about web application, we will use nginx as webserver and simply add hello.txt into the image.

Then, push the image into registry then deploy the apps to our instance.
