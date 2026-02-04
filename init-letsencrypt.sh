#!/bin/bash

# Script para inicializar certificados Let's Encrypt

domains=(doecerto.ddns.net)
email="seu-email@example.com" # Substitua pelo seu email
staging=0 # Defina como 1 para testar (certificados staging)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "### Iniciando configuração do Let's Encrypt ..."

# Verifica se o nginx está rodando
if [ ! "$(docker compose ps -q nginx)" ]; then
  echo -e "${RED}Erro: Container nginx não está rodando${NC}"
  echo "Execute: docker compose up -d nginx"
  exit 1
fi

# Cria diretório temporário para configuração
echo "### Criando configuração temporária do nginx ..."

# Para o nginx temporariamente para alterar configuração
docker compose stop nginx

# Cria configuração temporária sem SSL
cat > nginx-temp.conf << 'EOF'
server {
    listen 80;
    server_name doecerto.ddns.net;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

# Backup da configuração original
cp nginx.conf nginx.conf.backup

# Usa configuração temporária
cp nginx-temp.conf nginx.conf

# Reinicia nginx com configuração temporária
docker compose up -d nginx

echo "### Solicitando certificado Let's Encrypt ..."

# Adiciona opção --staging se necessário
staging_arg=""
if [ $staging != "0" ]; then 
  staging_arg="--staging"
fi

# Solicita certificado
docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email $email \
  --agree-tos \
  --no-eff-email \
  $staging_arg \
  -d ${domains[0]}

# Restaura configuração original
mv nginx.conf.backup nginx.conf

# Remove configuração temporária
rm nginx-temp.conf

# Reinicia nginx com SSL
echo "### Reiniciando nginx com SSL ..."
docker compose up -d nginx

echo -e "${GREEN}### Pronto! Certificado configurado${NC}"
echo "Acesse: https://doecerto.ddns.net"
echo ""
echo "O certificado será renovado automaticamente a cada 12 horas"
