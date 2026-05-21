output "vm_public_ip" {
  description = "Public IP address of the Nextcloud VM"
  value       = azurerm_public_ip.nextcloud.ip_address
}

output "vm_fqdn" {
  description = "Fully qualified domain name of the Nextcloud VM"
  value       = azurerm_public_ip.nextcloud.fqdn
}

output "nextcloud_url" {
  description = "URL to access Nextcloud (HTTPS)"
  value       = "https://${azurerm_public_ip.nextcloud.fqdn}"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.nextcloud.ip_address}"
}
