###cloud vars


variable "cloud_id" {
  type        = string
  default     = "b1ghf04gk3pjrsrgql70"
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  default     = "b1gtv0ajanmlin9k1k48"
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}

variable "default_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}
variable "default_cidr" {
  type        = list(string)
  default     = ["10.0.1.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "public_subnet_cidr" {
  type        = list(string)
  default     = ["192.168.10.0/24"]
  description = "CIDR block for the public subnet"
}

variable "private_subnet_cidr" {
  type        = list(string)
  default     = ["192.168.20.0/24"]
  description = "CIDR block for the private subnet"
}

variable "nat_instance_ip" {
  type        = string
  default     = "192.168.10.254"
  description = "Fixed internal IP address of the NAT instance in the public subnet"
}

variable "nat_image_id" {
  type        = string
  default     = "fd80mrhj8fl2oe87o4e1"
  description = "Image ID for the NAT instance"
}

###ssh vars

variable "ssh_user" {
  type        = string
  default     = "ubuntu"
  description = "Login user injected into instance metadata for SSH access"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/netology-ya-cloud.pub"
  description = "Path to the SSH public key used to access the created instances"
}


### cloud-2

variable "bucket_name" {
  type        = string
  default     = "erant-netology-cloud-2026-10-06"
  description = "Globally unique Object Storage bucket name"
}

variable "ig_sa_id" {
  type        = string
  default     = "ajeqje7qqolspmd29jej"
  description = "Service account ID for the Instance Group"
}

variable "lamp_image_id" {
  type        = string
  default     = "fd827b91d99psvq5fjit"
  description = "LAMP image ID for Instance Group template"
}