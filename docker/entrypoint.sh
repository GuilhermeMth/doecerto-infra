#!/bin/sh

# ==============================================================================
# SCRIPT DE INICIALIZAÇÃO DA API (ENTRYPOINT)
# Este script aguarda o banco de dados e executa tarefas de manutenção.
# ==============================================================================

# 1. Aguardar o MySQL estar pronto para conexões
# Usamos o nome do serviço 'db' definido no docker-compose.yml
echo "----------------------------------------------------------------------"
echo "🔍 Aguardando MySQL (db:3306) iniciar..."
echo "----------------------------------------------------------------------"

# O loop nc (netcat) verifica se a porta 3306 está aceitando conexões
while ! nc -z db 3306; do
  sleep 1
done

echo "✅ MySQL está online e pronto!"

# 2. Sincronizar o Banco de Dados (Prisma)
# 'migrate deploy' aplica as migrations sem resetar o banco (ideal para prod)
echo "🚀 Aplicando migrations do Prisma..."
npx prisma migrate deploy

# 3. Executar Seeds (Opcional)
# Verifica a variável de ambiente que definimos no .env
if [ "$RUN_SEED" = "true" ]; then
  echo "🌱 Variável RUN_SEED detectada como true. Rodando seeds..."
  # Ajuste 'npm run seed' conforme o comando definido no seu package.json
  npm run seed
else
  echo "ℹ️ Pulando seeds (RUN_SEED não é true)."
fi

# 4. Iniciar o processo principal da aplicação
# O comando 'exec' garante que o Node.js assuma o PID 1 (importante para sinais de parada)
echo "----------------------------------------------------------------------"
echo "🌟 Iniciando a API NestJS..."
echo "----------------------------------------------------------------------"
exec node dist/main.js