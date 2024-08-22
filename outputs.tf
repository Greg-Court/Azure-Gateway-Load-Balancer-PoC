output "vnet1_lb_public_ip" {
  description = "The public IP address of the VNet 1 load balancer."
  value       = azurerm_public_ip.vnet1_lb_ip.ip_address
}

output "vnet2_vm_public_ip" {
  description = "The public IP address of the VNet 2 VM."
  value       = azurerm_public_ip.workload_vm2_ip.ip_address
}

output "nva1_public_ip" {
  description = "The public IP address of NVA1."
  value       = azurerm_public_ip.nva1.ip_address
}

output "nva2_public_ip" {
  description = "The public IP address of NVA2."
  value       = azurerm_public_ip.nva2.ip_address
}
