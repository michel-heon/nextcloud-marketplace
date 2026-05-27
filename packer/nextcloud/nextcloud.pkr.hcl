packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

# ------------------------------------------------------------
# Source: Azure ARM → Azure Compute Gallery
# ------------------------------------------------------------
source "azure-arm" "nextcloud" {
  # Authentication — Azure CLI (az login)
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id
  tenant_id          = var.tenant_id

  # Temporary build resource group
  build_resource_group_name = var.build_resource_group

  # Source image — Ubuntu 24.04 LTS
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"
  image_version   = "latest"

  os_type = "Linux"

  # Microsoft best practice for Gen2 VM security: explicit Trusted Launch
  # (avoid relying on subscription preview/default behavior)
  security_type       = "TrustedLaunch"
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Build VM size
  vm_size = var.vm_size

  # SSH configuration (Packer creates a temporary key)
  communicator     = "ssh"
  ssh_username     = "packer"
  ssh_timeout      = "20m"

  # Output: Azure Compute Gallery
  shared_image_gallery_destination {
    subscription        = var.subscription_id
    resource_group      = var.gallery_resource_group
    gallery_name        = var.gallery_name
    image_name          = var.gallery_image_name
    image_version       = var.image_version
    replication_regions = var.replication_regions
  }

  # Tags applied to the managed image
  azure_tags = {
    project       = "nextcloud-marketplace"
    environment   = var.environment
    image_version = var.image_version
    managed_by    = "packer"
  }
}

# ------------------------------------------------------------
# Build: Provisioning steps
# ------------------------------------------------------------
build {
  name    = "nextcloud"
  sources = ["source.azure-arm.nextcloud"]

  # Copy shared library
  provisioner "file" {
    source      = "${path.root}/scripts/lib"
    destination = "/tmp/lib"
  }

  # Copy config files
  provisioner "file" {
    source      = "${path.root}/../../config"
    destination = "/tmp/config"
  }

  # 00 — System preparation
  provisioner "shell" {
    script           = "${path.root}/scripts/00-system-prepare.sh"
    execute_command  = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    expect_disconnect = false
  }

  # 01 — Install NGINX
  provisioner "shell" {
    script           = "${path.root}/scripts/01-install-nginx.sh"
    execute_command  = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
  }

  # 02 — Install PHP-FPM
  provisioner "shell" {
    script           = "${path.root}/scripts/02-install-php.sh"
    execute_command  = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "PHP_VERSION=${var.php_version}",
    ]
  }

  # 03 — Install PostgreSQL
  provisioner "shell" {
    script           = "${path.root}/scripts/03-install-postgresql.sh"
    execute_command  = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "PG_VERSION=${var.postgresql_version}",
    ]
  }

  # 04 — Install Redis
  provisioner "shell" {
    script           = "${path.root}/scripts/04-install-redis.sh"
    execute_command  = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
  }

  # 05 — Install Nextcloud files
  provisioner "shell" {
    script           = "${path.root}/scripts/05-install-nextcloud.sh"
    execute_command  = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "NC_VERSION=${var.nc_version}",
      "BLOB_STORAGE_BASE_URL=${var.blob_storage_base_url}",
    ]
  }

  # 06 — Configure NGINX
  provisioner "shell" {
    script          = "${path.root}/scripts/06-configure-nginx.sh"
    execute_command = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "PHP_VERSION=${var.php_version}",
    ]
  }

  # 07 — Configure PHP-FPM
  provisioner "shell" {
    script          = "${path.root}/scripts/07-configure-php.sh"
    execute_command = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "PHP_VERSION=${var.php_version}",
    ]
  }

  # 08 — Configure PostgreSQL
  provisioner "shell" {
    script          = "${path.root}/scripts/08-configure-postgresql.sh"
    execute_command = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "PG_VERSION=${var.postgresql_version}",
    ]
  }

  # 09 — Configure Redis
  provisioner "shell" {
    script          = "${path.root}/scripts/09-configure-redis.sh"
    execute_command = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
  }

  # 10 — Configure Nextcloud directories and permissions
  provisioner "shell" {
    script          = "${path.root}/scripts/10-configure-nextcloud.sh"
    execute_command = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
  }

  # 11 — Configure security (UFW, fail2ban, unattended-upgrades)
  provisioner "shell" {
    script          = "${path.root}/scripts/11-configure-security.sh"
    execute_command = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
  }

  # 12 — Configure cron and systemd services
  provisioner "shell" {
    script          = "${path.root}/scripts/12-configure-services.sh"
    execute_command = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
  }

  # 99 — Azure sysprep (waagent deprovision)
  provisioner "shell" {
    script          = "${path.root}/scripts/99-sysprep.sh"
    execute_command = "sudo -S env {{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "PHP_VERSION=${var.php_version}",
    ]
  }

  # Write build manifest
  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}
