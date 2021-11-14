# alb-ec2-sample

# This sample will:

 - use default vpc
 - use ubuntu-focal-20.04-amd64 ami from canonical
 - build two security groups 
   * first one for the auto scaling group instances (port 22 opened, optionally)
   * second one for the ALB (port 80 opened)
 - build a launch configuration that installs nginx (will be used as template for the auto scaling group instances)
 - build an auto scaling group
 - build a target group (linked to the auto scaling group instances)
 - build a load balancer (application)
 - build a listener for the load balancer (forwards traffic to the target group)
