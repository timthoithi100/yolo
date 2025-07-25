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

resource "aws_internet_gateway" "yolo_igw" {
  vpc_id = aws_vpc.yolo_vpc.id
  tags = {
    Name = "yolo-igw"
  }
}

resource "aws_route_table" "yolo_route_table" {
  vpc_id = aws_vpc.yolo_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.yolo_igw.id
  }
  tags = {
    Name = "yolo-route-table"
  }
}

resource "aws_route_table_association" "yolo_rta" {
  subnet_id      = aws_subnet.yolo_subnet.id
  route_table_id = aws_route_table.yolo_route_table.id
}

resource "aws_security_group" "yolo_sg" {
  name        = "yolo-sg"
  description = "Allow SSH, HTTP, and custom ports for YOLO app"
  vpc_id      = aws_vpc.yolo_vpc.id
