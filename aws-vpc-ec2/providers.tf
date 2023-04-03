terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  
  # Uncomment this backend block to use a S3 bucket for the terraform.tfstate file
  # Otherwise, a local file will be used
  #backend "s3" {
  #  bucket          = "ponderosa-aws-ec2-tfstate"    # your s3 buckect
  #  key             = "state/terraform.tfstate"
  #  region          = "us-east-1"                        # edit region (variables not allowed here)
  #  encrypt         = true
  #  dynamodb_table  = "ponderosa-aws-ec2-tf_lockid"  # your dynamo db table
  #} 

}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["~/.aws/credentials"]      # your credentials file
}


