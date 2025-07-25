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

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol     = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Frontend app port from anywhere"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend app port from anywhere"
    from_port   = 5000
    to_port     = 5000
    protocol     = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MongoDB port from anywhere"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "yolo-sg"
  }
}

resource "aws_key_pair" "yolo_key_pair" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "yolo_server" {
  ami           = "ami-0cef932bcf979d254"
  instance_type = "t2.micro"
  key_name      = "yolo-key"
  vpc_security_group_ids = [aws_security_group.yolo_sg.id]
  subnet_id = aws_subnet.yolo_subnet.id
  associate_public_ip_address = true

  tags = {
    Name = "YoloServer"
  }
}
