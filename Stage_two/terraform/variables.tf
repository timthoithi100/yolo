variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0cef932bcf979d254"
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "The name of the AWS key pair"
  type        = string
  default     = "yolo-key"
}

variable "public_key_path" {
  description = "The path to the public SSH key file for AWS"
  type        = string
  default     = "/home/tim/.ssh/id_rsa.pub"
}
