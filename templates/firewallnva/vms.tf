#######################################
# Test-VMs for Spoke1 and Spoke2
#######################################

variable "admin_username" {
  description = "Admin username for the test VMs"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Password for the admin user"
  type        = string
  sensitive   = true
}

# Network Interfaces
resource "azurerm_network_interface" "nic_spoke1" {
  name                = "nic-spoke1-testvm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.spoke1_workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic_spoke2" {
  name                = "nic-spoke2-testvm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.spoke2_workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

# NSGs to allow Ping
resource "azurerm_network_security_group" "nsg_spoke1" {
  name                = "nsg-spoke1-testvm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-icmp-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_spoke2" {
  name                = "nsg-spoke2-testvm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-icmp-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG association
resource "azurerm_network_interface_security_group_association" "spoke1" {
  network_interface_id      = azurerm_network_interface.nic_spoke1.id
  network_security_group_id = azurerm_network_security_group.nsg_spoke1.id
}

resource "azurerm_network_interface_security_group_association" "spoke2" {
  network_interface_id      = azurerm_network_interface.nic_spoke2.id
  network_security_group_id = azurerm_network_security_group.nsg_spoke2.id
}

# Test-VM in Spoke1
resource "azurerm_linux_virtual_machine" "vm_spoke1" {
  name                            = "vm-spoke1"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic_spoke1.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Test-VM in Spoke2
resource "azurerm_linux_virtual_machine" "vm_spoke2" {
  name                            = "vm-spoke2"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic_spoke2.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Outputs
output "vm_spoke1_private_ip" {
  value = azurerm_network_interface.nic_spoke1.private_ip_address
}

output "vm_spoke2_private_ip" {
  value = azurerm_network_interface.nic_spoke2.private_ip_address
}