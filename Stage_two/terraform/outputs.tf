output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.yolo_server.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.yolo_server.public_dns
}

output "key_pair_private_key_path" {
  description = "Path to the private key used for SSH access"
  value       = "~/.ssh/id_rsa"
}
