# Sample AKS IaC Deploy (Free Tier + GitHub Actions)

Repositório de Infraestrutura como Código (IaC) para provisionamento de um cluster **Azure Kubernetes Service (AKS) Free Tier** via **Terraform**, com automação de pipeline CI/CD no **GitHub Actions** utilizando autenticação segura via **OIDC (OpenID Connect / Federated Credentials)**.

---

## 🏗️ Arquitetura e Decisões Técnicas

- **AKS Free Tier**: Utiliza `sku_tier = "Free"`, garantindo que não haja custo de gerenciamento do plano de controle (Control Plane).
- **System Node Pool Mínimo**: Configurado com 1 nó sob demanda (`Standard_B2s`), mantendo os pods vitais do cluster (`kube-system`) protegidos e estáveis.
- **Spot User Node Pool (80-90% OFF)**: Node pool secundário configurado com instâncias **Spot** e **Auto-scaling (0 a 3 nós)**. Quando ocioso, o pool pode escalar para 0 nós, zerando o custo das VMs de aplicação.
- **Autenticação OIDC**: O GitHub Actions autentica na Azure sem senhas estáticas ou client secrets expiráveis, usando identidade federada recomendada pela Microsoft.
- **Terraform Remote State**: Armazenado em um Azure Blob Storage com configuração desacoplada para isolar segredos e metadados de infraestrutura.


---

## 📁 Estrutura do Repositório

```text
.
├── .github/
│   └── workflows/
│       ├── terraform-ci.yml       # Lint, Validação e Plan em Pull Requests
│       └── terraform-cd.yml       # Apply na branch main e dispatch manual (apply/plan/destroy)
├── terraform/
│   ├── providers.tf               # Provider AzureRM e backend azurerm
│   ├── main.tf                    # Resource Group e AKS Free Tier
│   ├── variables.tf               # Parâmetros customizáveis
│   ├── outputs.tf                 # Informações de conexão (kubeconfig, cluster id, etc.)
│   └── terraform.tfvars.example   # Exemplo de valores para testes
├── .gitignore                     # Ignora .terraform, arquivos de estado local e segredos
└── README.md                      # Instruções de uso e configuração
```

---

## 🚀 Guia de Configuração Passo a Passo

### 1. Pré-requisitos
- Conta ativa na [Microsoft Azure](https://portal.azure.com/).
- [Azure CLI](https://learn.microsoft.com/pt-br/cli/azure/install-azure-cli) instalado localmente.
- Permissão de Administrador ou Proprietário na Subscription da Azure para criar App Registration e conceder permissões.

---

### 2. Criar o Storage Account para o Backend do Terraform (Executar via Azure CLI)

Execute os comandos abaixo no seu terminal para criar o Resource Group e a conta de armazenamento que guardará o estado (`terraform.tfstate`):

```bash
# Definir variáveis
LOCATION="eastus"
TF_STATE_RG="rg-terraform-state"
TF_STATE_SA="tfstatesampleaks$RANDOM"
TF_STATE_CONTAINER="tfstate"

# Fazer login na Azure
az login

# Criar o Resource Group para o estado do Terraform
az group create --name $TF_STATE_RG --location $LOCATION

# Criar o Storage Account
az storage account create \
  --name $TF_STATE_SA \
  --resource-group $TF_STATE_RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --allow-blob-public-access false

# Criar o Container de Blobs
az storage container create \
  --name $TF_STATE_CONTAINER \
  --account-name $TF_STATE_SA \
  --auth-mode login

echo "Storage Account criado: $TF_STATE_SA"
```

> [!NOTE]
> Anote os valores de `$TF_STATE_RG`, `$TF_STATE_SA` e `$TF_STATE_CONTAINER` para preencher as variáveis do GitHub.

---

### 3. Configurar a Autenticação OIDC no Azure AD para o GitHub Actions

Substitua `SEU_USUARIO_OU_ORG` e `sample-aks-iac-deploy` pelos dados do seu repositório no GitHub:

```bash
# Definir variáveis do repositório
GITHUB_ORG="SEU_USUARIO_OU_ORG"
GITHUB_REPO="sample-aks-iac-deploy"
APP_NAME="github-actions-sample-aks"

# Obter IDs da Subscription e do Tenant
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# 1. Criar o Azure AD Application
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)

# 2. Criar o Service Principal
az ad sp create --id $APP_ID

# 3. Conceder permissão de Contributor na Subscription
az role assignment create \
  --role "Contributor" \
  --assignee $APP_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# 4. Criar a credencial federada (OIDC) para a branch 'main'
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
    \"description\": \"Deploy via branch main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

# 5. Criar a credencial federada (OIDC) para Pull Requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-pull-request\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request\",
    \"description\": \"Validação via Pull Requests\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

echo "Configuração OIDC concluída!"
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
```

---

### 4. Configurar Secrets e Variables no GitHub

No seu repositório GitHub, acesse **Settings** > **Secrets and variables** > **Actions**:

#### 🔒 Repository Secrets (`Secrets`):
- `AZURE_CLIENT_ID`: Valor impresso acima (`APP_ID`).
- `AZURE_TENANT_ID`: Valor impresso acima (`TENANT_ID`).
- `AZURE_SUBSCRIPTION_ID`: Valor impresso acima (`SUBSCRIPTION_ID`).

#### 🌐 Repository Variables (`Variables`) (ou Secrets, caso prefira):
- `BACKEND_RESOURCE_GROUP_NAME`: Nome do RG do backend (ex: `rg-terraform-state`).
- `BACKEND_STORAGE_ACCOUNT_NAME`: Nome do Storage Account do backend (ex: `tfstatesampleaks...`).
- `BACKEND_CONTAINER_NAME`: Nome do container de blob (ex: `tfstate`).

---

## 🔄 Como Funcionam as Pipelines

### 1. Pipeline de CI (`terraform-ci.yml`)
- **Gatilho**: Disparada automaticamente ao abrir ou atualizar um **Pull Request** para a branch `main`.
- **Ações**:
  - Verifica formatação (`terraform fmt -check`).
  - Inicializa o Terraform com o backend remoto da Azure.
  - Valida as sintaxes e dependências (`terraform validate`).
  - Gera o plano de execução (`terraform plan`) e adiciona o resumo no resumo da execução do job.

### 2. Pipeline de CD (`terraform-cd.yml`)
- **Gatilho**:
  - Automático ao realizar **push ou merge** na branch `main`.
  - Manual através de **workflow_dispatch** na aba Actions do GitHub.
- **Ações**:
  - Por padrão executa `terraform apply -auto-approve`.
  - No disparo manual (`workflow_dispatch`), permite selecionar:
    - `apply`: Aplica as mudanças.
    - `plan`: Apenas visualiza o plano de execução.
    - `destroy`: Destrói todos os recursos provisionados pelo Terraform (útil para economizar custos após finalizar testes).

---

## 💻 Conectar ao Cluster AKS após o Deploy

Assim que a pipeline aplicar a infraestrutura com sucesso, obtenha o kubeconfig executando o comando informado no output:

```bash
# Substitua o nome do Resource Group e do Cluster caso tenha customizado
az aks get-credentials --resource-group sampleaks-dev-rg --name sampleaks-dev-aks --overwrite-existing

# Verificar os nós do cluster
kubectl get nodes
```

---

## 🎯 Como Agendar Workloads nos Nós Spot (Kubernetes Manifest)

Como os nós Spot possuem a restrição automática (*taint*) `kubernetes.azure.com/scalesetpriority=spot:NoSchedule`, suas aplicações precisam conter a respectiva tolerância (*toleration*) para serem executadas neles.

Exemplo de `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-spot
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-spot
  template:
    metadata:
      labels:
        app: nginx-spot
    spec:
      # Obriga ou prefere rodar no pool spot
      nodeSelector:
        nodepool: spot
      # Tolera o taint de nós Spot
      tolerations:
      - key: "kubernetes.azure.com/scalesetpriority"
        operator: "Equal"
        value: "spot"
        effect: "NoSchedule"
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
```

---

## 💰 Observações sobre Custos e Dicas de Economia

1. **Control Plane**: O SKU `Free` isenta custos de gerenciamento de cluster da Azure.
2. **System Pool**: 1 VM `Standard_B2s` sob demanda (~$0.04/hora) apenas para manter o controle básico do cluster.
3. **Spot Pool**: Redução de até 80-90% nos nós de aplicação, com escalonamento a zero nós quando ocioso.
4. **Pausar o Cluster quando não estiver usando (`az aks stop`)**:
   Em ambientes de desenvolvimento ou laboratório, você pode pausar o cluster para **zerar o custo de computação**:
   ```bash
   # Pausar cluster (VMs são desalocadas, custo de computação vai a R$ 0)
   az aks stop --name sampleaks-dev-aks --resource-group sampleaks-dev-rg

   # Retomar o cluster quando voltar a testar
   az aks start --name sampleaks-dev-aks --resource-group sampleaks-dev-rg
   ```
5. **Destruir via Pipeline**: Utilize o disparo manual com `destroy` no workflow `terraform-cd.yml` quando não precisar mais da infraestrutura.


