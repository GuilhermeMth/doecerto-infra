#!/bin/bash

# Script para inicializar certificados Let's Encrypt

set -e

domains=(doecerto.ddns.net)
email="doecertoifpe@gmail.com" # ⚠️ SUBSTITUA PELO SEU EMAIL
staging=0 # Defina como 1 para testar (certificados staging)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "### Iniciando configuração do Let's Encrypt ..."

# Valida email
if [ "$email" = "seu-email@example.com" ]; then
  echo -e "${RED}❌ Erro: Configure seu email no script antes de continuar${NC}"
  exit 1
fi

# Cria volumes necessários se não existirem
echo "### Criando volumes necessários ..."
docker volume create doecerto_certbot_etc 2>/dev/null || true
docker volume create doecerto_certbot_www 2>/dev/null || true

# Para todos os containers
echo "### Parando containers ..."
docker compose down

# Cria configuração temporária do nginx (apenas HTTP para validação)
echo "### Criando configuração temporária do nginx ..."

cat > nginx-temp.conf << 'EOF'
server {
    listen 80;
    server_name doecerto.ddns.net;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 200 'Aguardando certificado SSL...';
        add_header Content-Type text/plain;
    }
}
EOF

# Backup da configuração original
if [ -f nginx.conf ]; then
  cp nginx.conf nginx.conf.backup
  echo "✓ Backup da configuração original criado"
fi

# Usa configuração temporária
cp nginx-temp.conf nginx.conf

# Inicia apenas nginx e certbot
echo "### Iniciando nginx com configuração temporária ..."
docker compose up -d nginx

# Aguarda nginx inicializar
sleep 5

# Verifica se nginx está rodando
if [ ! "$(docker compose ps -q nginx)" ] || [ "$(docker compose ps -q nginx | xargs docker inspect -f '{{.State.Running}}')" != "true" ]; then
  echo -e "${RED}❌ Erro: Nginx não iniciou corretamente${NC}"
  docker compose logs nginx
  exit 1
fi

echo -e "${GREEN}✓ Nginx rodando em modo HTTP${NC}"

# Prepara comando certbot
staging_arg=""
if [ $staging != "0" ]; then 
  staging_arg="--staging"
  echo -e "${YELLOW}⚠️  Modo STAGING ativado - certificado de teste${NC}"
fi

# Solicita certificado
echo "### Solicitando certificado Let's Encrypt ..."
echo "Domínio: ${domains[0]}"
echo "Email: $email"

docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email $email \
  --agree-tos \
  --no-eff-email \
  --force-renewal \
  $staging_arg \
  -d ${domains[0]}

# Verifica se certificado foi criado
if docker compose run --rm certbot certificates | grep -q "${domains[0]}"; then
  echo -e "${GREEN}✓ Certificado obtido com sucesso!${NC}"
else
  echo -e "${RED}❌ Erro ao obter certificado${NC}"
  docker compose logs certbot
  exit 1
fi

# Restaura configuração original (com HTTPS)
echo "### Restaurando configuração com HTTPS ..."
if [ -f nginx.conf.backup ]; then
  mv nginx.conf.backup nginx.conf
fi

# Remove configuração temporária
rm -f nginx-temp.conf

# Reinicia nginx com SSL
echo "### Reiniciando nginx com SSL ..."
docker compose down nginx
docker compose up -d

# Aguarda todos os serviços iniciarem
echo "### Aguardando serviços iniciarem ..."
sleep 10

# Verifica status
if docker compose ps | grep -q "nginx.*Up"; then
  echo -e "${GREEN}✓ Nginx rodando com SSL${NC}"
else
  echo -e "${RED}❌ Erro ao iniciar nginx com SSL${NC}"
  docker compose logs nginx
  exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Configuração concluída com sucesso!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "🌐 Acesse: https://doecerto.ddns.net"
echo "🔒 Certificado SSL ativo"
echo "🔄 Renovação automática configurada (a cada 12 horas)"
echo ""
echo -e "${YELLOW}Dica:${NC} Para verificar o certificado:"
echo "  docker compose run --rm certbot certificates"
echo ""