# Exibe o IP Público da máquina
output "public_ip" {
  description = "IP Público da VM para acesso direto se necessário"
  value       = azurerm_public_ip.pip.ip_address
}

# Exibe o link do site (FQDN)
output "website_url" {
  description = "URL principal do seu projeto (use esta no Caddy e no .env)"
  value       = "https://${azurerm_public_ip.pip.fqdn}"
}

# Exibe o comando pronto para você colar no terminal e entrar na máquina
output "ssh_command" {
  description = "Comando para acessar a VM via terminal"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.pip.fqdn}"
}

# Exibe o nome do DNS puro para configurar no .env
output "backend_url_variable" {
  description = "Valor exato que deve ir para a variável BACKEND_URL no seu .env"
  value       = azurerm_public_ip.pip.fqdn
}