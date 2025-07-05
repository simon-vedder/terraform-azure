terraform {
  required_version = ">= 1.0.0"
}

provider "null" {}

variable "vm_ip" {
  default     = "1.2.3.4"
  description = "IP address of the Azure VM"
}

# Generate config.js from template
resource "local_file" "config_js" {
  filename = "${path.module}/content/config.js"
  content = templatefile("${path.module}/config.js.tpl", {
    # examples to fill variables values within config files
    vm_ip = var.vm_ip 
  })
}

# Zip the entire content folder
data "archive_file" "zip_webclient" {
  type        = "zip"
  source_dir  = "./content"
  output_path = "./content.zip"
  depends_on  = [local_file.config_js]
}
