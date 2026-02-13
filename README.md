# DoeCerto - Infraestrutura

> Documentação completa em um único arquivo

## 📋 Índice

- [O Que Foi Feito](#o-que-foi-feito)
- [Arquitetura](#arquitetura)
- [Iniciar](#iniciar)
- [Comandos Essenciais](#comandos-essenciais)
- [Problemas Comuns](#problemas-comuns)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Segurança](#segurança)
- [Dados e Persistência](#dados-e-persistência)
- [Monitorar](#monitorar)
- [Atualizar](#atualizar)

---

## O Que Foi Feito

Infraestrutura completa da aplicação DoeCerto em **Docker Compose** com 6 serviços:

```
✅ MySQL 8        - Banco de dados (porta 3306)
✅ Redis 7        - Cache em memória (porta 6379)
✅ API Node.js    - Backend (porta 3501)
✅ Frontend Web   - Aplicação web (porta 3535)
✅ Caddy          - Proxy reverso com SSL (portas 80/443)
✅ Watchtower     - Auto-update de imagens
```

**Acesso:**
- Frontend: https://doecerto.eastus2.cloudapp.azure.com
- API: https://doecerto.eastus2.cloudapp.azure.com/api
- Health: https://doecerto.eastus2.cloudapp.azure.com/api/health

**Ambiente:** Azure Cloud (eastus2)

---

## Arquitetura

### Diagrama

```
┌──────────────────────────────────────┐
│         INTERNET HTTPS               │
│  doecerto.eastus2.cloudapp.azure.com │
└─────────────────┬────────────────────┘
                  │
            ┌─────▼─────┐
            │   CADDY   │
            │ Proxy SSL │
            └──┬───┬──┬─┘
               │   │  │
         /api/ │   │  \────────────┐
               │   │               │
           ┌───▼┐ ┌┴────────┐      │
           │API │ │ /apk/*  │      │
           │:3501 │       │      │
           └───┬─┘ │       │      │
               │   │       │      │
          ┌────┴───┘       │      │
          │                │      │
      ┌───▼──┐ ┌──────┐    │      │
      │MySQL │ │Redis │    │      │
      └──────┘ └──────┘    │      │
                           │      │
                    ┌──────▼──┐
                    │Frontend  │
                    │  :3535   │
                    └──────────┘

Watchtower monitora tudo (verifica a cada 30s)
```

### Como Funciona

1. Usuário acessa `https://doecerto.eastus2.cloudapp.azure.com`
2. Caddy recebe a requisição HTTPS
3. Se `/api/*` → roteia para API:3501
4. Se `/apk/*` → roteia para API:3501
5. Se `/*` → roteia para Frontend:3535
6. API conecta ao MySQL e Redis quando precisa
7. Watchtower verifica novas versões das imagens a cada 30s

---

## Iniciar

### Passo 1: Preparar .env

```bash
# Copiar template
cp .env.example .env

# Editar com seus valores
nano .env
```

**Valores que PRECISAM mudar:**
```
DB_PASSWORD=senha123              # Gerar: openssl rand -hex 16
JWT_SECRET=3b8e2f9c5a7d4e8f1a2c  # Gerar: openssl rand -hex 16
BACKEND_URL=https://seu-dominio.com/api
FRONTEND_URL=https://seu-dominio.com
```

### Passo 2: Iniciar Tudo

```bash
docker-compose up -d
```

Isso vai:
1. Iniciar MySQL (aguarda 30s)
2. Iniciar Redis
3. Iniciar API (aguarda MySQL estar saudável)
4. Iniciar Frontend (aguarda API)
5. Iniciar Caddy (aguarda Frontend e API)
6. Iniciar Watchtower

### Passo 3: Verificar Status

```bash
docker-compose ps
```

Esperado (todos "Up"):
```
doecerto-mysql      Up 2 minutes (healthy)
doecerto-redis      Up 2 minutes
doecerto-api        Up 1 minute
doecerto-frontend   Up 1 minute
doecerto-caddy      Up 1 minute
doecerto-watchtower Up 1 minute
```

### Passo 4: Acessar

```
https://doecerto.eastus2.cloudapp.azure.com
```

Se der erro, veja [Problemas Comuns](#problemas-comuns)

---

## Comandos Essenciais

### Ver Status
```bash
# Verificar se tudo está rodando
docker-compose ps

# Ver logs de um serviço
docker-compose logs api -f           # API
docker-compose logs mysql --tail=50  # MySQL
docker-compose logs caddy -f         # Caddy
```

### Reiniciar
```bash
# Reiniciar um serviço específico
docker-compose restart api
docker-compose restart mysql
docker-compose restart caddy

# Reiniciar tudo
docker-compose restart
```

### Parar e Iniciar
```bash
# Parar tudo (dados persistem)
docker-compose down

# Iniciar novamente
docker-compose up -d
```

### Conectar Interativamente
```bash
# Acessar MySQL
docker-compose exec mysql mysql -u root -p${DB_PASSWORD} doecerto

# Acessar Redis
docker-compose exec redis redis-cli

# Executar comando na API
docker-compose exec api npm run migrate
```

---

## Problemas Comuns

### "API não responde" / HTTP 502

```bash
# Verificar se está rodando
docker-compose ps api

# Ver o erro
docker-compose logs api -f

# Reiniciar
docker-compose restart api

# Aguardar e testar
sleep 5
curl https://doecerto.eastus2.cloudapp.azure.com/api/health
```

### "Certificado inválido" / SSL error

```bash
# Caddy renova automaticamente, reinicie para forçar
docker-compose restart caddy

# Ver logs para diagnosticar
docker-compose logs caddy | grep certificate
```

### "MySQL não conecta" / erro P1012

```bash
# Verificar se está saudável
docker-compose exec mysql mysqladmin ping -u root -p${DB_PASSWORD}

# Ver logs
docker-compose logs mysql

# Reiniciar
docker-compose restart mysql
```

### "Ninguém consegue acessar"

Checklist:

```bash
# 1. Containers rodando?
docker-compose ps

# 2. DNS aponta corretamente?
nslookup doecerto.eastus2.cloudapp.azure.com

# 3. Firewall permite 80 e 443?
sudo ufw status

# 4. API respondendo localmente?
docker-compose exec caddy curl http://api:3501/health

# 5. Frontend respondendo localmente?
docker-compose exec caddy curl http://frontend:3535/
```

### "Redis cheia" / OOM error

```bash
# Ver memória usada
docker-compose exec redis redis-cli INFO memory

# Aumentar maxmemory em docker-compose.yml
# Na seção redis, mude:
# command: redis-server --maxmemory 1gb --maxmemory-policy allkeys-lru

# Reiniciar
docker-compose restart redis
```

---

## Variáveis de Ambiente

### URLs
```env
BACKEND_URL=https://doecerto.eastus2.cloudapp.azure.com/api
FRONTEND_URL=https://doecerto.eastus2.cloudapp.azure.com
APP_URL=https://doecerto.eastus2.cloudapp.azure.com/api
```

### MySQL
```env
DB_HOST=mysql              # Nome do container
DB_PORT=3306              # Porta padrão
DB_USER=root              # Usuário
DB_PASSWORD=senha123      # ⚠️ MUDAR EM PRODUÇÃO
DB_NAME=doecerto          # Nome do banco
DATABASE_URL="mysql://root:senha123@mysql:3306/doecerto"
MYSQL_ROOT_PASSWORD=senha123
MYSQL_DATABASE=doecerto
```

### Redis
```env
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_URL="redis://redis:6379"
```

### JWT (Segurança)
```env
JWT_SECRET=3b8e2f9c5a7d4e8f1a2c6b9d0f4a1e3c  # ⚠️ GERAR NOVO
JWT_ALGORITHM=HS256
```

### Aplicação
```env
PORT=3501
NODE_ENV=production
RUN_SEED=true
```

### Gerar Senhas Seguras
```bash
# JWT_SECRET (32 caracteres aleatórios)
openssl rand -hex 16

# DB_PASSWORD (outro aleatório)
openssl rand -hex 16
```

---

## Segurança

### ✅ O Que Está Configurado

- **SSL/TLS**: Caddy gerencia automaticamente com Let's Encrypt
- **Isolamento**: Containers em rede privada Docker
- **Persistência**: Dados em volumes, não dentro do container
- **Health Checks**: MySQL verifica se está vivo a cada 10s
- **Restart Automático**: Se um serviço cai, reinicia automaticamente
- **Credenciais**: Senhas em .env (não no código)

### ⚠️ O Que PRECISA Fazer

1. **Mudar senhas padrão**
   ```bash
   DB_PASSWORD=senha123          # Mudar para algo seguro
   JWT_SECRET=3b8e2f9c5a7d...   # Gerar novo com openssl
   ```

2. **Configurar firewall do servidor**
   ```bash
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS
   sudo ufw enable
   ```

3. **Manter .env seguro**
   ```bash
   # Já está em .gitignore (não será commitado)
   # Mas faça backup em lugar seguro
   ```

4. **Fazer backups regularmente**
   ```bash
   # Backup MySQL
   docker-compose exec -T mysql mysqldump \
     -u root -p${DB_PASSWORD} \
     --all-databases > backup_$(date +%Y%m%d).sql
   ```

---

## Dados e Persistência

### Volumes Docker

Tudo é salvo em volumes (não dentro do container):

```
mysql_data/         ← Banco de dados MySQL
redis_data/         ← Dados Redis
uploads_profiles/   ← Fotos de usuários
uploads_payments/   ← Comprovantes de pagamento
api_logs/          ← Logs da aplicação
caddy_data/        ← Certificados SSL
caddy_config/      ← Configurações Caddy
```

### Se Parar o Container

```bash
# Dados NÃO são perdidos
docker-compose down
```

### Se Deletar o Volume

```bash
# ⚠️ PERDA TOTAL DE DADOS
docker-compose down -v
```

### Backup Manual

```bash
# Banco de dados
docker-compose exec -T mysql mysqldump \
  -u root -p${DB_PASSWORD} \
  --all-databases > backup_$(date +%Y%m%d_%H%M%S).sql

# Redis
docker run --rm \
  -v doecerto_redis_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/redis_backup.tar.gz /data

# Restaurar MySQL
docker-compose exec -T mysql mysql -u root -p${DB_PASSWORD} \
  < backup_20260212_120000.sql
```

---

## Monitorar

### Status Rápido

```bash
# Verificar saúde da infraestrutura
docker-compose ps

# Se não estiver "Up", verificar erro:
docker-compose logs <container>
```

### Recursos em Uso

```bash
# CPU e RAM dos containers
docker stats

# Espaço em disco
df -h

# Tamanho do banco de dados
docker-compose exec -T mysql mysql -u root -p${DB_PASSWORD} \
  -e "SELECT ROUND(SUM(data_length + index_length)/1024/1024,2) \
      FROM information_schema.TABLES WHERE table_schema='doecerto';"
```

### Logs em Tempo Real

```bash
# Seguir logs da API
docker-compose logs -f api

# Procurar por erros
docker-compose logs api | grep -i "error\|exception"

# Últimas 50 linhas
docker-compose logs api --tail=50
```

### Health Checks

```bash
# MySQL
docker-compose exec mysql mysqladmin ping -u root -p${DB_PASSWORD}
# Resposta esperada: "mysqld is alive"

# Redis
docker-compose exec redis redis-cli ping
# Resposta esperada: "PONG"

# API
curl https://doecerto.eastus2.cloudapp.azure.com/api/health
# Resposta esperada: JSON com status

# Frontend
curl https://doecerto.eastus2.cloudapp.azure.com
# Resposta esperada: HTML da página
```

---

## Atualizar

### Automático (Watchtower)

Watchtower verifica a cada 30 segundos se há novas versões das imagens:

```bash
# Ver logs do Watchtower
docker-compose logs watchtower -f

# Quando encontra versão nova:
# 1. Baixa a imagem
# 2. Para o container antigo
# 3. Inicia o novo
# 4. Remove imagem antiga
```

Nenhuma ação manual necessária!

### Manual (Se Preferir Controlar)

```bash
# 1. Baixar novas imagens
docker-compose pull

# 2. Reiniciar com novas versões
docker-compose up -d

# 3. Verificar que iniciou correto
docker-compose logs api
```

### Reverter para Versão Anterior

```bash
# 1. Ver imagens disponíveis
docker images | grep doecerto

# 2. Editar docker-compose.yml
# Mudar: image: guilhermemth/doecerto-api:latest
# Para:  image: guilhermemth/doecerto-api:v1.1.0

# 3. Reiniciar
docker-compose down
docker-compose up -d

# 4. Verificar
docker-compose logs api | head -20
```

---

## Estrutura do Projeto

```
.env                  ← Variáveis (não versionado - segurança)
.env.example          ← Template de variáveis
docker-compose.yml    ← Configuração (6 serviços)
Caddyfile            ← Proxy reverso (roteamento)
README.md            ← Este arquivo
.gitignore           ← Ignora .env no git
```

---

## O Que Cada Serviço Faz

### MySQL
- **Função**: Banco de dados relacional
- **Imagem**: mysql:8
- **Porta**: 3306 (interna)
- **Persistência**: mysql_data volume
- **Health Check**: Verifica a cada 10s se está vivo
- **Auto-restart**: Sim

### Redis
- **Função**: Cache em memória
- **Imagem**: redis:7
- **Porta**: 6379 (interna)
- **Persistência**: redis_data volume
- **Max Memory**: 512MB com política allkeys-lru
- **Auto-restart**: Sim

### API
- **Função**: Backend Node.js
- **Imagem**: guilhermemth/doecerto-api:latest
- **Porta**: 3501 (interna)
- **Aguarda**: MySQL (healthy) + Redis
- **Volumes**: uploads_profiles, uploads_payments, api_logs
- **Auto-update**: Sim (Watchtower)

### Frontend
- **Função**: Aplicação web
- **Imagem**: guilhermemth/doecerto-front:latest
- **Porta**: 3535 (interna)
- **Aguarda**: API estar pronto
- **Auto-update**: Sim (Watchtower)

### Caddy
- **Função**: Proxy reverso + gerenciador SSL
- **Imagem**: caddy:latest
- **Portas**: 80 (HTTP) e 443 (HTTPS)
- **Configuração**: Caddyfile
- **Certificado**: Let's Encrypt automático
- **Email ACME**: guilhermemfranca06@gmail.com

### Watchtower
- **Função**: Monitor automático de atualizações
- **Imagem**: containrrr/watchtower:latest
- **Intervalo**: Verifica a cada 30 segundos
- **Comportamento**: Baixa, para antigo, inicia novo, deleta antigo
