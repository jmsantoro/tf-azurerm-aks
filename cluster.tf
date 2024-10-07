# Generate random resource group name
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

resource "random_pet" "azurerm_kubernetes_cluster_name" {
  prefix = "cluster"
}

resource "random_pet" "azurerm_kubernetes_cluster_dns_prefix" {
  prefix = "dns"
}

resource "azurerm_kubernetes_cluster" "k8s" {
  location            = azurerm_resource_group.rg.location
  name                = random_pet.azurerm_kubernetes_cluster_name.id
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = random_pet.azurerm_kubernetes_cluster_dns_prefix.id

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                = "agentpool"
    vm_size             = "Standard_B2s"
    enable_auto_scaling = true
    min_count           = var.node_count
    max_count           = var.max_node_count
    type                = "VirtualMachineScaleSets"
    node_count          = var.node_count
    vnet_subnet_id      = azurerm_subnet.name.id
  }
  linux_profile {
    admin_username = var.username

    ssh_key {
      key_data = azapi_resource_action.ssh_public_key_gen.output.publicKey
    }
  }
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
    service_cidr      = "10.0.4.0/24"
    dns_service_ip    = "10.0.4.10"
  }
}

resource "azurerm_role_assignment" "clusterClusterNetworkContributor" {
  principal_id         = azurerm_kubernetes_cluster.k8s.identity[0].principal_id
  scope                = azurerm_virtual_network.aks_vnet.id
  role_definition_name = "Network Contributor"
}

resource "azurerm_role_assignment" "clusterClusterSubnetNetworkContributor" {
  principal_id         = azurerm_kubernetes_cluster.k8s.identity[0].principal_id
  scope                = azurerm_subnet.name.id
  role_definition_name = "Network Contributor"
}
