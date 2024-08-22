# Public IP for the Standard Load Balancer in VNet 1
resource "azurerm_public_ip" "vnet1_lb_ip" {
  name                = "vnet1-lb-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                = "Standard"
}

# Standard Load Balancer for VNet 1
resource "azurerm_lb" "vnet1_lb" {
  name                = "vnet1-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "VNET1VMLBFrontend"
    public_ip_address_id = azurerm_public_ip.vnet1_lb_ip.id
    gateway_load_balancer_frontend_ip_configuration_id = azurerm_lb.gwlb.frontend_ip_configuration[0].id
  }
}

resource "azurerm_lb_nat_rule" "nat" {
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.vnet1_lb.id
  name                           = "RDPAccess"
  protocol                       = "Tcp"
  frontend_port_start            = 6969
  frontend_port_end              = 6969
  backend_port                   = 3389
  frontend_ip_configuration_name = "VNET1VMLBFrontend"
  backend_address_pool_id       = azurerm_lb_backend_address_pool.vnet1_lb_pool.id
}

# Backend Address Pool for Standard LB in VNet 1
resource "azurerm_lb_backend_address_pool" "vnet1_lb_pool" {
  loadbalancer_id = azurerm_lb.vnet1_lb.id
  name            = "vnet1-lb-backend-pool"
}

# Load Balancer Rule for VNet 1 LB (port 80 for IIS)
resource "azurerm_lb_rule" "vnet1_lb_rule" {
  loadbalancer_id                = azurerm_lb.vnet1_lb.id
  name                           = "VNet1VMLBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "VNET1VMLBFrontend"
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.vnet1_lb_pool.id]
  probe_id                       = azurerm_lb_probe.vnet1_lb_probe.id
}

# Load Balancer Probe for VNet 1 LB
resource "azurerm_lb_probe" "vnet1_lb_probe" {
  loadbalancer_id     = azurerm_lb.vnet1_lb.id
  name                = "VNet1VMProbe"
  protocol            = "Tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Network Interface Backend Association for VNet 1 VM
resource "azurerm_network_interface_backend_address_pool_association" "vnet1_lb_assoc" {
  network_interface_id    = azurerm_network_interface.workload_nic1.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.vnet1_lb_pool.id
}

# Gateway Load Balancer in the Hub VNet
resource "azurerm_lb" "gwlb" {
  name                = "gwlb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Gateway"

  frontend_ip_configuration {
    name      = "gwlb-frontend"
    subnet_id = azurerm_subnet.gwlb_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address = "10.0.2.4"
  }
}

resource "azurerm_lb_backend_address_pool" "nva_pool" {
  loadbalancer_id = azurerm_lb.gwlb.id
  name            = "NVAPool"

  tunnel_interface {
    identifier = 800 
    type       = "Internal" 
    protocol   = "VXLAN"
    port       = 10800 
  }

  tunnel_interface {
    identifier = 801  
    type       = "External"  
    protocol   = "VXLAN"
    port       = 10801 
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nva_nic1_assoc" {
  network_interface_id    = azurerm_network_interface.nva_nic1.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.nva_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nva_nic2_assoc" {
  network_interface_id    = azurerm_network_interface.nva_nic2.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.nva_pool.id
}

resource "azurerm_lb_probe" "nva_health_probe" {
  loadbalancer_id     = azurerm_lb.gwlb.id
  name                = "NVAProbe"
  protocol            = "Tcp"
  # request_path        = "/"
  port                = 22
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "nva_lb_rule" {
  loadbalancer_id                = azurerm_lb.gwlb.id
  name                           = "LBRuleSendToNVAs"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "gwlb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nva_pool.id]
  probe_id                       = azurerm_lb_probe.nva_health_probe.id
}

