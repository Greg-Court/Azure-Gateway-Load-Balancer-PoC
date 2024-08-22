resource "azurerm_public_ip" "nva1" {
  name                = "pip-nva1-${var.location_short}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "nva2" {
  name                = "pip-nva2-${var.location_short}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nva_nic1" {
  name                = "nva-nic1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nva_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nva1.id
  }
}

resource "azurerm_network_interface" "nva_nic2" {
  name                = "nva-nic2"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nva_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nva2.id
  }
}

resource "azurerm_linux_virtual_machine" "nva1" {
  name                = "nva1"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2ms"
  admin_username      = "adminuser"

  network_interface_ids = [azurerm_network_interface.nva_nic1.id]

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

  admin_ssh_key {
    username   = var.username
    public_key = file("~/.ssh/id_rsa.pub")
  }
}

resource "azurerm_linux_virtual_machine" "nva2" {
  name                = "nva2"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2ms"
  admin_username      = "adminuser"

  network_interface_ids = [azurerm_network_interface.nva_nic2.id]

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

  admin_ssh_key {
    username   = var.username
    public_key = file("~/.ssh/id_rsa.pub")
  }
}

resource "azurerm_virtual_machine_extension" "nva_setup1" {
  name                 = "nva-setup1"
  virtual_machine_id   = azurerm_linux_virtual_machine.nva1.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
    {
      "script": "${filebase64("nva_setup.sh")}"
    }
SETTINGS
}

resource "azurerm_virtual_machine_extension" "nva_setup2" {
  name                 = "nva-setup2"
  virtual_machine_id   = azurerm_linux_virtual_machine.nva2.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
    {
      "script": "${filebase64("nva_setup.sh")}"
    }
SETTINGS
}

resource "azurerm_network_security_group" "nva_nsg" {
  name                = "nsg-nva-${var.location_short}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = data.ipify_ip.public.ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nva_nic1_nsg" {
  network_interface_id      = azurerm_network_interface.nva_nic1.id
  network_security_group_id = azurerm_network_security_group.nva_nsg.id
}

resource "azurerm_network_interface_security_group_association" "nva_nic2_nsg" {
  network_interface_id      = azurerm_network_interface.nva_nic2.id
  network_security_group_id = azurerm_network_security_group.nva_nsg.id
}
