provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "yolo_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "yolo-vpc"
  }
}

resource "aws_subnet" "yolo_subnet" {
  vpc_id     = aws_vpc.yolo_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "yolo-subnet"
  }
}
