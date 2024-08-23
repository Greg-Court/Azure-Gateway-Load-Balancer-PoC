resource "azurerm_network_interface" "workload_nic1" {
  name                = "workload-nic1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vnet1_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "workload_vm1" {
  name                = "workload-vm1"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2ms"
  admin_username      = "adminuser"
  admin_password      = var.password

  network_interface_ids = [azurerm_network_interface.workload_nic1.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_public_ip" "workload_vm2_ip" {
  name                = "workload-vm2-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                = "Standard"
}

resource "azurerm_network_interface" "workload_nic2" {
  name                = "workload-nic2"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vnet2_subnet.id 
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.workload_vm2_ip.id
    gateway_load_balancer_frontend_ip_configuration_id = azurerm_lb.gwlb.frontend_ip_configuration[0].id
  }
}

resource "azurerm_windows_virtual_machine" "workload_vm2" {
  name                = "workload-vm2"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2ms"
  admin_username      = "adminuser"
  admin_password      = var.password

  network_interface_ids = [azurerm_network_interface.workload_nic2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

locals {
  vm1_script_base64 = base64encode(templatefile("${path.module}/iis_script_vm1.ps1", {}))
  vm2_script_base64 = base64encode(templatefile("${path.module}/iis_script_vm2.ps1", {}))
}

# VM Extension for VM1 to run the PowerShell script
resource "azurerm_virtual_machine_extension" "workload_vm1_iis" {
  name                 = "workload-vm1-iis"
  virtual_machine_id   = azurerm_windows_virtual_machine.workload_vm1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = <<SETTINGS
  {
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${local.vm1_script_base64}')) | Out-File -filepath vm1_install.ps1\" && powershell -ExecutionPolicy Unrestricted -File vm1_install.ps1"
  }
  SETTINGS
}

# VM Extension for VM2 to run the PowerShell script
resource "azurerm_virtual_machine_extension" "workload_vm2_iis" {
  name                 = "workload-vm2-iis"
  virtual_machine_id   = azurerm_windows_virtual_machine.workload_vm2.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = <<SETTINGS
  {
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${local.vm2_script_base64}')) | Out-File -filepath vm2_install.ps1\" && powershell -ExecutionPolicy Unrestricted -File vm2_install.ps1"
  }
  SETTINGS
}

