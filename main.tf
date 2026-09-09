resource "aws_instance" "devops-school-level3" {
  ami           = local.ami_id
  instance_type = var.ec2_type
  subnet_id     = local.subnet_id
  key_name      = local.keypair

  vpc_security_group_ids = [local.main_sg_id]

  user_data                   = file("user-data.web.sh")
  user_data_replace_on_change = true

  tags = {
    Name = local.ec2_name
  }
}

output "ec2_public_dns_name" {
value = aws_instance.devops-school-level3.public_dns
}
