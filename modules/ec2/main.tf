data "aws_ami" "aws_linux" {
  most_recent = true
  filter {
    name   = "product-code"
    values = ["8acfvh6bldsr1ojb0oe3n8je5"]
  }
}

# // ------------------------------------------------------------------------------------
# // Create SSH Private Key
# 
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "sshkey-${var.region}"
  public_key = tls_private_key.pk.public_key_openssh
}

# // ------------------------------------------------------------------------------------
# // Store Private Key in AWS Secrets Manager
# 

resource "aws_secretsmanager_secret" "ssh_private_key" {
  name                    = "ssh_private_key-${var.region}"
  recovery_window_in_days = 0 # Allow immediate deletion of secrets manager so name can be re-used
}

resource "aws_secretsmanager_secret_version" "ssh_private_key_version" {
  secret_id     = aws_secretsmanager_secret.ssh_private_key.id
  secret_string = tls_private_key.pk.private_key_pem
}

# // ------------------------------------------------------------------------------------
# // Deploy EC2 Instances
# 

resource "aws_instance" "this" {
  for_each = { for host in var.vmhosts : host.name => host }

  ami                    = data.aws_ami.aws_linux.id
  instance_type          = each.value.instance_type == null ? "t2.small" : each.value.instance_type 
  key_name               = aws_key_pair.kp.key_name
  subnet_id              = var.public_subnet_id[0]
  private_ip             = each.value.private_ip == null ? null : each.value.private_ip
  vpc_security_group_ids = [aws_security_group.instance_sg[each.key].id]
  root_block_device {
    volume_size = 20
  }
  associate_public_ip_address = true

  iam_instance_profile = var.instance_profile

  lifecycle {
    ignore_changes = [associate_public_ip_address]
  }

  user_data = file(each.value["install_script"])
  tags = merge(each.value.tags, { Name = each.value.name }, {})

}

resource "aws_security_group" "instance_sg" {
  for_each = { for host in var.vmhosts : host.name => host }

  name        = "${each.value.name}-sg"
  description = "Security Group for ${each.value.name}"
  vpc_id      = var.vpcId

  dynamic "ingress" {
    for_each = { for port in each.value.ports : port => port }

    content {
      from_port   = ingress.key
      to_port     = ingress.key
      protocol    = "tcp"
      cidr_blocks = each.value.cidrs
      description = "Allow inbound traffic on port ${ingress.key}"
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(each.value.tags, { Name = "${each.value.name}-sg" }, {})
}