variable "kubeadm_demo_key_name" {
  type = string
  description = "name of our key pair"
  default = "kubeadm_demo_key"
}

variable "instance_type" {
  type = string
  default = "t2.medium"
}

variable "kubeadm_demo_ami" {
  type = string
  description = "ami id for ubuntu image"
  default = "ami-0a0e5d9c7acc336f1"
}

variable "kubeadm_demo_instance_count" {
  type = number
  description = "the number of worker nodes in the cluster"
  default = 2
}