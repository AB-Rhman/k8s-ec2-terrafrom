provider "aws" {
  region     = "us-east-1"
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.53"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }

    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }

  }

}

# CUSTOM VPC
resource "aws_vpc" "kubeadm_demo_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "kubeadm_demo_vpc"
  }

}

# Make subnet

resource "aws_subnet" "kubeadm_demo_subnet" {
  vpc_id                  = aws_vpc.kubeadm_demo_vpc.id
  map_public_ip_on_launch = true
  cidr_block              = "10.0.1.0/24"

  tags = {
    Name : "kubadm_demo_public_subnet"
  }

}

# IGW to get the app connected to the internet ...
resource "aws_internet_gateway" "kubeadm_demo_igw" {
  vpc_id = aws_vpc.kubeadm_demo_vpc.id

  tags = {
    Name = "Kubeadm Demo Internet GW"
  }

}


# Route Table
resource "aws_route_table" "kubeadm_demo_route_table" {
  vpc_id = aws_vpc.kubeadm_demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kubeadm_demo_igw.id
  }

  tags = {
    Name = "kubeadm Demo IGW route table"
  }

}

# associate the route table to the subnet

resource "aws_route_table_association" "kubeadm_demo_route_table_association" {
  subnet_id      = aws_subnet.kubeadm_demo_subnet.id
  route_table_id = aws_route_table.kubeadm_demo_route_table.id
}

#......... CREATE the security groups ........

// 1. common ports (http/https/ssh)
resource "aws_security_group" "kubeadm_demo_sg_common" {
  name = "kubeadm_demo_sg_common"

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0    # allow any port
    to_port     = 0    # allow any port
    protocol    = "-1" # allow any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kubeadm_demo_sg_common"
  }

}


resource "aws_security_group_rule" "allow_http_https_on_worker_node" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.kubeadm_demo_sg_worker_node.id
}

resource "aws_security_group_rule" "allow_http_https_on_control_plan" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.kubeadm_demo_sg_control_plane.id
}

// 2. control plane ports
resource "aws_security_group" "kubeadm_demo_sg_control_plane" {
  name = "kubeadm_demo_sg_control_plane"

  ingress {
    description = "K8S API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "kube-scheduler"
    from_port   = 10259
    to_port     = 10259
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "kube-controller-manager"
    from_port   = 10257
    to_port     = 10259
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ETCD server client API"
    from_port   = 2379
    to_port     = 2380
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0    # allow any port
    to_port     = 0    # allow any port
    protocol    = "-1" # allow any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Control Plane SG"
  }
}

// 3. worker node ports

resource "aws_security_group" "kubeadm_demo_sg_worker_node" {
  name = "kubeadm_demo_sg_worker_node"

  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "kube-proxy"
    from_port   = 10256
    to_port     = 10256
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0    # allow any port
    to_port     = 0    # allow any port
    protocol    = "-1" # allow any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Worker Nodes SG"
  }
}

// 4. flannel UDP Backend PORTS

resource "aws_security_group" "kubeadm_demo_sg_flannel" {
  name = "kubeadm_demo_sg_flannel"

  tags = {
    Name = "kubeadm_demo_sg_flannel"
  }

  ingress {
    description = "UDP backend"
    from_port   = 8285
    to_port     = 8285
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "udp vxlan backend"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# .... Instance related resources

resource "tls_private_key" "kubeadm_demo_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command = "echo '${self.public_key_pem}' > ./publickey.pem ; chmod 600 ./publickey.pem"
  }

}

resource "aws_key_pair" "kubeadm_demo_key" {
  key_name   = var.kubeadm_demo_key_name
  public_key = tls_private_key.kubeadm_demo_private_key.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.kubeadm_demo_private_key.private_key_pem}' > ./private-key.pem ; chmod 600 ./private-key.pem "
  }

}


resource "aws_instance" "kubeadm_demo_control_plane" {
  ami           = var.kubeadm_demo_ami
  instance_type = var.instance_type

  key_name                    = aws_key_pair.kubeadm_demo_key.key_name
  associate_public_ip_address = true
  security_groups = [
    aws_security_group.kubeadm_demo_sg_control_plane.name,
    aws_security_group.kubeadm_demo_sg_flannel.name,
    aws_security_group.kubeadm_demo_sg_common.name,
  ]

  root_block_device {
    volume_size = 14
    volume_type = "gp2"
  }

  tags = {
    Name = "control_plane"
    Role = "Control Plane"
  }

  provisioner "local-exec" {
    command = "mkdir -p ./files ; echo 'master ${self.public_ip}' >> ./files/hosts"
  }

}

resource "aws_instance" "kubeadm_demo_worker_nodes" {
  count                       = var.kubeadm_demo_instance_count
  ami                         = var.kubeadm_demo_ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.kubeadm_demo_key.key_name
  associate_public_ip_address = true

  security_groups = [
    aws_security_group.kubeadm_demo_sg_worker_node.name,
    aws_security_group.kubeadm_demo_sg_flannel.name,
    aws_security_group.kubeadm_demo_sg_common.name,
  ]

  tags = {
    Name = "worker-${count.index}"
    Role = "Worker Node"
  }

  provisioner "local-exec" {
    command = "mkdir -p ./files ; echo 'worker${count.index} ${self.public_ip}' >> ./files/hosts"
  }

}

# ....... ANSIBLE Related Resources

resource "ansible_host" "kubeadm_demo_controlplane_host" {
  depends_on = [aws_instance.kubeadm_demo_control_plane]

  name   = "control_plane"
  groups = ["master"]
  variables = {
    ansible_user             = "ubuntu"
    ansible_host             = aws_instance.kubeadm_demo_control_plane.public_ip
    ansible_private_key_file = "./private-key.pem"
    node_hostname            = "master"
  }

}

resource "ansible_host" "kubadm_demo_worker_nodes_host" {
  depends_on = [
    aws_instance.kubeadm_demo_worker_nodes
  ]
  count  = var.kubeadm_demo_instance_count
  name   = "worker-${count.index}"
  groups = ["workers"]
  variables = {
    node_hostname                = "worker-${count.index}"
    ansible_user                 = "ubuntu"
    ansible_host                 = aws_instance.kubeadm_demo_worker_nodes[count.index].public_ip
    ansible_ssh_private_key_file = "./private-key.pem"
  }

}
