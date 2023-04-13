# Variable definitions & defaults

variable "aws_region" {                # AWS region
  default = "us-east-1"
  type    = string
}

variable "aws_availability_zone1" {    # availability zone 1 of 2
  default = "us-east-1a"
  type    = string
}

variable "aws_availability_zone2" {    # availability zone 2 of 2
  default = "us-east-1b"
  type    = string
}

variable "aws_ec2_keypair" {           # ssh keypair for all ec2 instances
  default = "ponderosa1"
  type    = string
}

variable "aws_sg_ingress_ipv4_block" { # security group allowed ipv4 ingress addresses
  default = "0.0.0.0/0"
  type    = string
}

variable "aws_sg_ingress_ipv6_block" { # security group allowed ipv6 ingress addresses
  default = "::/0"
  type    = string
}

variable "aws_ec2_ami_jump" {          # ec2 instance ami for jump server
  default = ""                         # a value will be found via data souce filter if not specified
  type    = string
}

variable "aws_ec2_type_jump" {         # ec2 instance type for jump box
  default = "t2.micro"                 # t2.micro is aws free tier elligble
  type    = string
}

variable "aws_ec2_type_node" {         # ec2 instance type for nodes
  default = "t2.medium"                # t2.medium offers 18 ip addresses, t2.small offers 12 ips 
  type    = string
}

variable "aws_eks_clustername" {       # EKS Cluster name
  default = "DemoEKSCluster"
  type    = string
}

variable "aws_nodes_desired" {         # Desired number of nodes
  default = 2
  type    = number
}

variable "aws_nodes_max" {             # Max number of nodes
  default = 6
  type    = number
}

variable "aws_nodes_min" {             # Desired number of nodes
  default = 1
  type    = number
}
