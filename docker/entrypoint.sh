#!/bin/sh

# ==============================================================================
# SCRIPT DE INICIALIZAÇÃO DA API (ENTRYPOINT)
# ==============================================================================

# 1. Aguardar o MySQL estar pronto para conexões
echo "----------------------------------------------------------------------"
echo "🔍 Aguardando MySQL (db:3306) iniciar..."
echo "----------------------------------------------------------------------"

# Usamos um comando nativo do shell (dev/tcp) para evitar dependência do netcat (nc)
# Isso funciona na maioria dos shells baseados em bash/sh
MAX_RETRIES=60
COUNT=0

while ! (echo > /dev/tcp/db/3306) >/dev/null 2>&1; do
  COUNT=$((COUNT + 1))
  if [ $COUNT -ge $MAX_RETRIES ]; then
    echo "❌ Erro: O banco de dados não ficou pronto a tempo após $MAX_RETRIES segundos."
    exit 1
  fi
  echo "Attempt $COUNT: Banco ainda não disponível..."
  sleep 1
done

echo "✅ MySQL está online e pronto!"

# 2. Sincronizar o Banco de Dados (Prisma)
echo "🚀 Aplicando migrations do Prisma..."
# Usamos o npx prisma generate antes para garantir que o client está atualizado
npx prisma generate
npx prisma migrate deploy

# 3. Executar Seeds (Opcional)
if [ "$RUN_SEED" = "true" ]; then
  echo "🌱 Variável RUN_SEED detectada como true. Rodando seeds..."
  # Adicionado || true para o container não morrer se o seed já tiver sido rodado antes
  npm run seed || echo "⚠️ Seed já executado ou falhou, ignorando..."
else
  echo "ℹ️ Pulando seeds (RUN_SEED não é true)."
fi

# 4. Iniciar o processo principal da aplicação
echo "----------------------------------------------------------------------"
echo "🌟 Iniciando a API NestJS..."
echo "----------------------------------------------------------------------"
exec node dist/main.js