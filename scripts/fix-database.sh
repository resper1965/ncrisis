#!/bin/bash

# Script para corrigir problemas de banco de dados
# Autor: n.crisis
# Data: $(date)

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERRO] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[AVISO] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Diretório do projeto
PROJECT_DIR="/opt/ncrisis"

log "Iniciando correção do banco de dados"

# 1. Navegar para o diretório do projeto
cd $PROJECT_DIR

# 2. Verificar se .env existe
if [ ! -f ".env" ]; then
    error "Arquivo .env não encontrado"
    log "Copiando .env.example..."
    cp env.example .env
    warn "Configure as variáveis de banco de dados no arquivo .env"
    exit 1
fi

# 3. Verificar se DATABASE_URL está configurada
if ! grep -q "DATABASE_URL" .env; then
    error "DATABASE_URL não encontrada no .env"
    warn "Configure DATABASE_URL no arquivo .env"
    exit 1
fi

# 4. Gerar cliente Prisma
log "Gerando cliente Prisma..."
npx prisma generate

# 5. Verificar status das migrações
log "Verificando status das migrações..."
npx prisma migrate status

# 6. Executar migrações pendentes
log "Executando migrações..."
npx prisma migrate deploy

# 7. Verificar se as tabelas foram criadas
log "Verificando tabelas..."
npx prisma db pull

# 8. Parar aplicação PM2
log "Parando aplicação PM2..."
pm2 stop ncrisis-backend 2>/dev/null || true

# 9. Iniciar aplicação novamente
log "Iniciando aplicação PM2..."
pm2 start build/src/server-clean.js --name ncrisis-backend

# 10. Verificar status
log "Verificando status da aplicação..."
sleep 5
pm2 status

# 11. Verificar logs
log "Verificando logs..."
pm2 logs ncrisis-backend --lines 10

# 12. Testar conectividade
log "Testando conectividade..."
sleep 3
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health | grep -q "200"; then
    log "✅ Aplicação está respondendo corretamente!"
else
    warn "❌ Aplicação pode não estar respondendo"
    log "Verificando logs de erro..."
    pm2 logs ncrisis-backend --lines 20
fi

# 13. Salvar configuração PM2
pm2 save

log "✅ Correção do banco de dados concluída!" 