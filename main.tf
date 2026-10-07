resource "yandex_vpc_network" "this" {
  name = "cloud-1-network"
}

resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = var.default_zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = var.public_subnet_cidr
}

resource "yandex_compute_instance" "nat" {
  name = "nat-instance"
  zone = var.default_zone

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }

  boot_disk {
    initialize_params {
      image_id = var.nat_image_id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.public.id
    ip_address = var.nat_instance_ip
    nat        = true
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }
}

resource "yandex_compute_instance" "public_vm" {
  name = "public-vm"
  zone = var.default_zone

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }
}


resource "yandex_vpc_subnet" "private" {
  name           = "private"
  zone           = var.default_zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = var.private_subnet_cidr
  route_table_id = yandex_vpc_route_table.private.id
}

resource "yandex_vpc_route_table" "private" {
  name       = "private-route-table"
  network_id = yandex_vpc_network.this.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat.network_interface.0.ip_address
  }
}

resource "yandex_compute_instance" "private_vm" {
  name = "private-vm"
  zone = var.default_zone

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private.id
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}


### cloud-2

# resource "yandex_storage_bucket" "this" {
#   bucket = var.bucket_name
# }

resource "yandex_storage_bucket_grant" "this" {
  bucket = yandex_storage_bucket.this.bucket

  grant {
    uri         = "http://acs.amazonaws.com/groups/global/AllUsers"
    permissions = ["READ"]
    type        = "Group"
  }
}

resource "yandex_storage_object" "image" {
  bucket       = yandex_storage_bucket.this.bucket
  key          = "image.jpg"
  source       = "./terraform.jpg"
  content_type = "image/jpeg"
  acl          = "public-read"
}


resource "yandex_compute_instance_group" "lamp" {
  name               = "lamp-ig"
  folder_id          = var.folder_id
  service_account_id = var.ig_sa_id

  instance_template {
    platform_id = "standard-v1"

    resources {
      cores         = 2
      memory        = 1
      core_fraction = 5
    }

    boot_disk {
      initialize_params {
        image_id = var.lamp_image_id
        size     = 10
        type     = "network-hdd"
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.public.id]
      nat        = true
    }

    metadata = {
      ssh-keys = "${var.ssh_user}:${file(pathexpand(var.ssh_public_key_path))}"
      user-data = <<-EOF
        #cloud-config
        write_files:
          - path: /var/www/html/index.html
            content: |
              <!DOCTYPE html>
              <html>
                <head><title>LAMP VM</title></head>
                <body>
                  <h1>Hello from LAMP instance</h1>
                  <img src="https://storage.yandexcloud.net/${yandex_storage_bucket.this.bucket}/image.jpg" width="400" alt="image">
                </body>
              </html>
        runcmd:
          - systemctl restart apache2
      EOF
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = [var.default_zone]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  health_check {
    interval            = 15
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3

    http_options {
      port = 80
      path = "/"
    }
  }
}

resource "yandex_lb_target_group" "lamp" {
  name      = "lamp-tg"
  folder_id = var.folder_id

  dynamic "target" {
    for_each = yandex_compute_instance_group.lamp.instances
    content {
      subnet_id = yandex_vpc_subnet.public.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "this" {
  name      = "lamp-nlb"
  folder_id = var.folder_id

  listener {
    name        = "http"
    port        = 80
    target_port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.lamp.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
      interval            = 15
      timeout             = 10
      healthy_threshold   = 3
      unhealthy_threshold = 3
    }
  }
}


### cloud-3

resource "yandex_kms_symmetric_key" "bucket" {
  name              = "bucket-key"
  default_algorithm = "AES_128"
  rotation_period   = "8760h"
  description       = "KMS key for Object Storage bucket encryption"
}

resource "yandex_storage_bucket" "this" {
  bucket = var.bucket_name

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.bucket.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

### cloud-4

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-b"
  zone           = var.extra_zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = var.extra_private_subnet_cidr
  route_table_id = yandex_vpc_route_table.private.id
}

resource "yandex_mdb_mysql_cluster" "this" {
  name                = "netology-mysql"
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.this.id
  version             = "8.0"
  deletion_protection = true

  maintenance_window {
    type = "WEEKLY"
    day  = "SAT"
    hour = 3
  }

  backup_window_start {
    hours   = 23
    minutes = 59
  }

  resources {
    resource_preset_id = "b1.medium"
    disk_type_id       = "network-hdd"
    disk_size          = 20
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.private.id
  }

  host {
    zone      = "ru-central1-b"
    subnet_id = yandex_vpc_subnet.private_b.id
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.private.id
  }
}

resource "yandex_mdb_mysql_database" "netology" {
  cluster_id = yandex_mdb_mysql_cluster.this.id
  name       = "netology_db"
}

resource "yandex_mdb_mysql_user" "app" {
  cluster_id = yandex_mdb_mysql_cluster.this.id
  name       = "netology_db"
  password   = var.mysql_password

  permission {
    database_name = yandex_mdb_mysql_database.netology.name
    roles         = ["ALL"]
  }
}