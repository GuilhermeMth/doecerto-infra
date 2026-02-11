variable "resource_group_name" {
  description = "Nome do Grupo de Recursos na Azure"
  default     = "rg-doecerto-prod"
}

variable "location" {
  description = "Região da Azure onde os recursos serão criados"
  default     = "eastus2" 
}

variable "vm_name" {
  description = "Nome da Máquina Virtual"
  default     = "vm-doecerto-api"
}

variable "vm_size" {
  description = "Tamanho/Família da VM (SKU)"
  default     = "Standard_D2s_v3" 
}

variable "dns_label" {
  description = "Prefixo único para o DNS da Azure. O link final será: seu-nome.eastus2.cloudapp.azure.com"
  default     = "doecerto" # ALTRE para algo único (ex: seu-nome-doecerto)
}

variable "admin_username" {
  description = "Usuário administrador para acesso SSH"
  default     = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "Conteúdo da chave pública SSH"
}