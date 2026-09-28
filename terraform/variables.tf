variable "prefix" {
  description = "Prefixo para nomenclatura dos recursos criados"
  type        = string
  default     = "sampleaks"
}

variable "environment" {
  description = "Ambiente de implantação (ex: dev, hml, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Região da Azure para implantação dos recursos"
  type        = string
  default     = "eastus"
}

variable "node_count" {
  description = "Quantidade de nós de trabalho no default node pool"
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "Tamanho da máquina virtual para os nós do AKS (Standard_B2s é econômica e recomendada para testes)"
  type        = string
  default     = "Standard_B2s"
}

variable "kubernetes_version" {
  description = "Versão específica do Kubernetes para o cluster (deixe null para usar a versão padrão do Azure)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags atribuídas aos recursos da Azure"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Project     = "sample-aks-iac-deploy"
  }
}

variable "enable_spot_node_pool" {
  description = "Habilitar node pool secundário com instâncias Spot para redução drástica de custos"
  type        = bool
  default     = true
}

variable "spot_vm_size" {
  description = "Tamanho da máquina virtual para os nós Spot"
  type        = string
  default     = "Standard_B2s"
}

variable "spot_min_count" {
  description = "Quantidade mínima de nós no pool Spot (0 permite escala a zero quando ocioso)"
  type        = number
  default     = 0
}

variable "spot_max_count" {
  description = "Quantidade máxima de nós no pool Spot"
  type        = number
  default     = 3
}


