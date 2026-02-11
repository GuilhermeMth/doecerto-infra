terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Grupo de Recursos
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 2. Rede Virtual e Subrede
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-doecerto"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 3. IP Público com DNS Label para o Caddy (HTTPS Automático)
# 3. IP Público com SKU Standard para evitar erro de cota
resource "azurerm_public_ip" "pip" {
  name                = "pip-doecerto"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"  # <--- MUDANÇA AQUI
  domain_name_label   = var.dns_label
}

# 4. Grupo de Segurança (NSG) - Abrindo Portas 22, 80 e 443
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-doecerto"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 5. Interface de Rede e Associação com NSG
resource "azurerm_network_interface" "nic" {
  name                = "nic-doecerto"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 6. Máquina Virtual (Ubuntu 22.04 LTS)
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size # Standard_D2s_v3 via variables.tf
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
      username   = var.admin_username
      public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # --- AUTOMAÇÃO PÓS-CRIAÇÃO (Instalação do Docker) ---
  # --- AUTOMAÇÃO PÓS-CRIAÇÃO (Instalação do Docker) ---
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    # Evita diálogos interativos durante a instalação
    export DEBIAN_FRONTEND=noninteractive

    # 1. Atualiza e instala dependências básicas
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release netcat-openbsd

    # 2. Configura o repositório oficial do Docker (Método moderno GPG)
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 3. Instala Docker e Docker Compose Plugin
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 4. Habilita e inicia o serviço
    systemctl enable docker
    systemctl start docker

    # 5. Permissões para o usuário (Ajusta o socket para ser acessível imediatamente)
    usermod -aG docker ${var.admin_username}
    chmod 666 /var/run/docker.sock

    echo "Docker instalado com sucesso em $(date)" > /home/${var.admin_username}/install_log.txt
  EOF
  )
}