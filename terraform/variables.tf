variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  sensitive   = true
}

variable "client_id" {
  description = "Azure service principal client ID"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Azure service principal client secret"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Name of the resource group to create for this deployment"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "canadacentral"
}

variable "vm_name" {
  description = "Virtual machine name (also used as DNS label)"
  type        = string
  default     = "nextcloud"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,63}$", var.vm_name))
    error_message = "vm_name must be lowercase alphanumeric and hyphens, 3–63 chars."
  }
}

variable "vm_size" {
  description = "Azure VM SKU"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "domain" {
  description = "Domain name used to build the VM FQDN (e.g. example.com)"
  type        = string
  default     = "cloudapp.azure.com"
}

variable "admin_username" {
  description = "Linux admin user account name"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_pubkey" {
  description = "SSH public key for the admin user (ed25519 or RSA 4096)"
  type        = string
}

variable "nc_admin_user" {
  description = "Nextcloud admin account username"
  type        = string
  default     = "ncadmin"
}

variable "ssh_source_ip" {
  description = "IP CIDR allowed for SSH access (restrict to your bastion/NAT IP)"
  type        = string
  default     = "*"
}

variable "gallery_resource_group" {
  description = "Resource group hosting the Azure Compute Gallery"
  type        = string
}

variable "gallery_name" {
  description = "Azure Compute Gallery name"
  type        = string
}

variable "gallery_image_name" {
  description = "Gallery image definition name"
  type        = string
  default     = "nextcloud-hub"
}

variable "image_version" {
  description = "Gallery image version to deploy (e.g. 0.1.0)"
  type        = string
  default     = "0.1.0"
}

variable "data_disk_size_gb" {
  description = "Size of the managed data disk for /var/nextcloud-data (GB)"
  type        = number
  default     = 128
}
