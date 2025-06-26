#!/bin/bash

# Script para criar e executar migrações do Prisma
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

log "Iniciando criação de migrações"

# 1. Navegar para o diretório do projeto
cd $PROJECT_DIR

# 2. Parar aplicação PM2
log "Parando aplicação PM2..."
pm2 stop ncrisis-backend 2>/dev/null || true

# 3. Verificar se schema.prisma existe
if [ ! -f "prisma/schema.prisma" ]; then
    error "prisma/schema.prisma não encontrado"
    exit 1
fi

# 4. Gerar cliente Prisma
log "Gerando cliente Prisma..."
npx prisma generate

# 5. Criar migração inicial
log "Criando migração inicial..."
npx prisma migrate dev --name init

# 6. Verificar se migração foi criada
if [ ! -d "prisma/migrations" ]; then
    error "Diretório prisma/migrations não foi criado"
    exit 1
fi

# 7. Executar migrações
log "Executando migrações..."
npx prisma migrate deploy

# 8. Verificar tabelas criadas
log "Verificando tabelas criadas..."
npx prisma db pull

# 9. Mostrar status das migrações
log "Status das migrações:"
npx prisma migrate status

# 10. Iniciar aplicação
log "Iniciando aplicação PM2..."
pm2 start build/src/server-clean.js --name ncrisis-backend

# 11. Verificar status
log "Verificando status da aplicação..."
sleep 5
pm2 status

# 12. Verificar logs
log "Verificando logs..."
pm2 logs ncrisis-backend --lines 10

# 13. Testar conectividade
log "Testando conectividade..."
sleep 3
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health | grep -q "200"; then
    log "✅ Aplicação está respondendo corretamente!"
else
    warn "❌ Aplicação pode não estar respondendo"
    log "Verificando logs de erro..."
    pm2 logs ncrisis-backend --lines 20
fi

# 14. Salvar configuração PM2
pm2 save

log "✅ Criação de migrações concluída!" 