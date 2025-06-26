#!/bin/bash

# Script para resolver problema de porta e configurar porta 3000
# Autor: n.crisis

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[AVISO] $1${NC}"
}

# Diretório do projeto
PROJECT_DIR="/opt/ncrisis"

log "Iniciando correção de porta"
cd $PROJECT_DIR

# Parar aplicação PM2
log "Parando aplicação PM2..."
pm2 stop ncrisis-backend 2>/dev/null || true

# Matar processo na porta 5000
log "Matando processo na porta 5000..."
fuser -k 5000/tcp 2>/dev/null || true

# Configurar porta 3000
log "Configurando porta 3000..."
if grep -q "PORT=5000" .env; then
    sed -i 's/PORT=5000/PORT=3000/g' .env
elif ! grep -q "PORT=" .env; then
    echo "PORT=3000" >> .env
fi

# Iniciar aplicação
log "Iniciando aplicação PM2..."
pm2 start build/src/server-clean.js --name ncrisis-backend

# Verificar status
sleep 5
pm2 status
pm2 logs ncrisis-backend --lines 10

log "✅ Correção de porta concluída!"
