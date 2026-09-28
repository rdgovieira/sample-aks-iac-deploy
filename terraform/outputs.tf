output "resource_group_name" {
  description = "Nome do Resource Group criado"
  value       = azurerm_resource_group.rg.name
}

output "aks_cluster_name" {
  description = "Nome do cluster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "ID do cluster AKS na Azure"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_principal_id" {
  description = "Principal ID da identidade gerenciada do AKS"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "kubeconfig_command" {
  description = "Comando Azure CLI para baixar as credenciais e configurar o kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}

output "spot_node_pool_id" {
  description = "ID do Spot Node Pool (se habilitado)"
  value       = var.enable_spot_node_pool ? azurerm_kubernetes_cluster_node_pool.spot[0].id : null
}


