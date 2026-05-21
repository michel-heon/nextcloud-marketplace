# packer/nextcloud/variables.pkr.hcl
# Variable declarations for the Nextcloud Packer build

# ------------------------------------------------------------
# Azure Authentication
# ------------------------------------------------------------
variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
  sensitive   = true
}

variable "tenant_id" {
  type        = string
  description = "Azure Tenant ID"
  sensitive   = true
}

# ------------------------------------------------------------
# Azure Resources
# ------------------------------------------------------------
variable "build_resource_group" {
  type        = string
  description = "Resource group where the temporary build VM is created"
  default     = "rg-nextcloud-marketplace-build"
}

variable "gallery_resource_group" {
  type        = string
  description = "Resource group containing the Azure Compute Gallery"
}

variable "gallery_name" {
  type        = string
  description = "Name of the Azure Compute Gallery"
}

variable "gallery_image_name" {
  type        = string
  description = "Image definition name in the gallery"
  default     = "nextcloud-marketplace"
}

variable "replication_regions" {
  type        = list(string)
  description = "Regions to replicate the image version to"
  default     = ["canadacentral", "eastus"]
}

variable "location" {
  type        = string
  description = "Primary Azure region for the build"
  default     = "canadacentral"
}

variable "vm_size" {
  type        = string
  description = "VM size for the Packer build VM"
  default     = "Standard_D4s_v3"
}

# ------------------------------------------------------------
# Image versioning
# ------------------------------------------------------------
variable "image_version" {
  type        = string
  description = "Semantic version for the gallery image (e.g. 1.0.0)"
  default     = "0.1.0"
}

variable "environment" {
  type        = string
  description = "Build environment tag (dev / staging / prod)"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# ------------------------------------------------------------
# Software versions
# ------------------------------------------------------------
variable "nc_version" {
  type        = string
  description = "Nextcloud version to install (e.g. 31.0.2)"
  default     = "33.0.3"
}

variable "php_version" {
  type        = string
  description = "PHP major.minor version to install (e.g. 8.3)"
  default     = "8.3"
}

variable "postgresql_version" {
  type        = string
  description = "PostgreSQL major version to install (e.g. 16)"
  default     = "16"
}

# ------------------------------------------------------------
# Blob Storage Cache (ADR-616)
# ------------------------------------------------------------
variable "blob_storage_base_url" {
  type        = string
  description = "Azure Blob Storage base URL for package cache — empty string disables blob cache (blob-first, source-fallback)"
  default     = ""
  sensitive   = false
}
