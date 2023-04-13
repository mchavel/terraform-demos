# terraform-demos

### Sample Terraform files for AWS 

* aws-vpc-ec2:  
Creates a VPC spanning two Availability Zones \
 one public and one private subnet in each AZ \
 NAT Gateway for each private subnet \
 Internet Gateway and EC2 jump server with public EIP \
 Elastic Load Balancer targeting EC2 web servers \
 in the private subnet of each AZ
 
* aws-vpc-ec2-asg:  
As above, but with an Auto Scaling Node Group and EC2 Launch Template replacing the two static EC2 web servers.

* aws-vpc-eks:  
As above, but with an EKS Cluster and EKS Node Group \
Also creates an IAM OIDC Provider and the following add-ons: 
  * EBS CSI Driver for Dynamic Persistent Volumes
  * CoreDNS
  * kube-proxy
  * VPV CNI 
  * AWS Load Balancer Controller 


All of these demos can be run against an AWS free tier account.  The EKS cluster will generate some modest charges if not removed within an hour or so.  

### Prerequisites:

1. Terraform installed
2. AWS account and IAM user credentials
3. One pre-generated AWS EC2 ssh key pair 

### Usage:

1. Clone Repo 
2. Change to desired demo subdirectory 
3. Edit providers.tf to point to your IAM user credentials file (same as an AWS CLI credentials file)
4. Edit variables.tf as desired.  At a minimum, set AWS region, availability zones, and EC2 ssh keypair name
5. terraform init
6. terraform plan
7. terraform apply

### Cleanup:

1. terraform destroy




 
 


 