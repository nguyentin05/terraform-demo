terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "my_first_ec2" {
  ami           = "ami-0c55b159cbfafe1f0" # AMI cho Amazon Linux 2 ở us-east-1
  instance_type = "t2.micro"
  tags = {
    Name = "MyFirstEC2"
  }
}