output "nat_instance_internal_ip" {
  value       = yandex_compute_instance.nat.network_interface.0.ip_address
  description = "Internal IP address of the NAT instance"
}

output "nat_instance_external_ip" {
  value       = yandex_compute_instance.nat.network_interface.0.nat_ip_address
  description = "External (public) IP address of the NAT instance"
}

output "public_vm_internal_ip" {
  value       = yandex_compute_instance.public_vm.network_interface.0.ip_address
  description = "Internal IP address of the public VM"
}

output "public_vm_external_ip" {
  value       = yandex_compute_instance.public_vm.network_interface.0.nat_ip_address
  description = "External (public) IP address of the public VM"
}

output "private_vm_internal_ip" {
  value       = yandex_compute_instance.private_vm.network_interface.0.ip_address
  description = "Internal IP address of the private VM (reachable only from within the VPC, e.g. via the public VM)"
}
