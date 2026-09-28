resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-${var.environment}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-${var.environment}-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.prefix}-${var.environment}-dns"

  # SKU Free Tier: Sem cobrança de gerenciamento do control plane
  sku_tier           = "Free"
  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name            = "systempool"
    node_count      = var.node_count
    vm_size         = var.vm_size
    os_disk_size_gb = 30
    type            = "VirtualMachineScaleSets"
    tags            = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  tags = var.tags
}

# Node pool secundário utilizando instâncias Spot com auto-scaling (0 a N nós)
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count                 = var.enable_spot_node_pool ? 1 : 0
  name                  = "spotpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.spot_vm_size
  mode                  = "User"
  os_disk_size_gb       = 30

  # Configuração Spot
  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1

  # Auto-scaling (permite escalar para zero quando não houver pods agendados)
  enable_auto_scaling = true
  min_count           = var.spot_min_count
  max_count           = var.spot_max_count

  node_labels = {
    "nodepool"                              = "spot"
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }

  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  tags = var.tags
}
