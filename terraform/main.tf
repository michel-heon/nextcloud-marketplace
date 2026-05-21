terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

# --- Random passwords generated at deploy time ---
resource "random_password" "nc_admin" {
  length  = 32
  special = true
}

resource "random_password" "db_password" {
  length  = 32
  special = false # avoid quoting issues in psql ALTER ROLE
}

resource "random_password" "redis_password" {
  length  = 32
  special = false
}

# --- Resource group ---
resource "azurerm_resource_group" "nextcloud" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# --- Networking ---
resource "azurerm_virtual_network" "nextcloud" {
  name                = "${var.vm_name}-vnet"
  resource_group_name = azurerm_resource_group.nextcloud.name
  location            = azurerm_resource_group.nextcloud.location
  address_space       = ["10.0.0.0/24"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "nextcloud" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.nextcloud.name
  virtual_network_name = azurerm_virtual_network.nextcloud.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_public_ip" "nextcloud" {
  name                = "${var.vm_name}-pip"
  resource_group_name = azurerm_resource_group.nextcloud.name
  location            = azurerm_resource_group.nextcloud.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.vm_name
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "nextcloud" {
  name                = "${var.vm_name}-nsg"
  resource_group_name = azurerm_resource_group.nextcloud.name
  location            = azurerm_resource_group.nextcloud.location

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_interface" "nextcloud" {
  name                = "${var.vm_name}-nic"
  resource_group_name = azurerm_resource_group.nextcloud.name
  location            = azurerm_resource_group.nextcloud.location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.nextcloud.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nextcloud.id
  }

  tags = local.common_tags
}

resource "azurerm_network_interface_security_group_association" "nextcloud" {
  network_interface_id      = azurerm_network_interface.nextcloud.id
  network_security_group_id = azurerm_network_security_group.nextcloud.id
}

# --- VM ---
# Resolve the Shared Image Gallery image version
data "azurerm_shared_image_version" "nextcloud" {
  name                = var.image_version
  image_name          = var.gallery_image_name
  gallery_name        = var.gallery_name
  resource_group_name = var.gallery_resource_group
}

# Render cloud-init template with per-deployment secrets
locals {
  common_tags = {
    project     = "nextcloud-marketplace"
    environment = var.environment
    managed_by  = "terraform"
  }

  cloud_init_content = templatefile(
    "${path.module}/../cloud-init/cloud-init.yaml",
    {
      hostname          = var.vm_name
      domain            = var.domain
      nc_admin_user     = var.nc_admin_user
      nc_admin_password = random_password.nc_admin.result
      nc_db_password    = random_password.db_password.result
      redis_password    = random_password.redis_password.result
      nc_trusted_domain = azurerm_public_ip.nextcloud.fqdn
      admin_username    = var.admin_username
      admin_ssh_pubkey  = var.admin_ssh_pubkey
    }
  )
}

resource "azurerm_linux_virtual_machine" "nextcloud" {
  name                            = var.vm_name
  resource_group_name             = azurerm_resource_group.nextcloud.name
  location                        = azurerm_resource_group.nextcloud.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.nextcloud.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_pubkey
  }

  # Reference the Packer-built image from the Compute Gallery
  source_image_id = data.azurerm_shared_image_version.nextcloud.id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  # Cloud-init user data (base64-encoded)
  custom_data = base64encode(local.cloud_init_content)

  tags = local.common_tags
}

# --- Managed disk for Nextcloud data (mounted at /var/nextcloud-data) ---
resource "azurerm_managed_disk" "nextcloud_data" {
  name                 = "${var.vm_name}-data-disk"
  resource_group_name  = azurerm_resource_group.nextcloud.name
  location             = azurerm_resource_group.nextcloud.location
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "nextcloud_data" {
  managed_disk_id    = azurerm_managed_disk.nextcloud_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.nextcloud.id
  lun                = 0
  caching            = "ReadWrite"
}
