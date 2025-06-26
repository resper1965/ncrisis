#!/bin/bash

# Script para compilação rápida sem verificações de tipo
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

log "Iniciando compilação rápida"

# 1. Navegar para o diretório do projeto
cd $PROJECT_DIR

# 2. Verificar se server-clean.ts existe
if [ ! -f "src/server-clean.ts" ]; then
    error "src/server-clean.ts não encontrado"
    exit 1
fi

# 3. Criar diretório build
log "Criando diretório build..."
mkdir -p build/src/

# 4. Compilar apenas server-clean.ts sem verificações
log "Compilando server-clean.ts..."
npx tsc src/server-clean.ts \
  --outDir build/src/ \
  --target ES2022 \
  --module CommonJS \
  --esModuleInterop \
  --allowSyntheticDefaultImports \
  --skipLibCheck \
  --noEmitOnError false \
  --noImplicitAny false \
  --strict false \
  --noUnusedLocals false \
  --noUnusedParameters false

# 5. Verificar se foi criado
if [ -f "build/src/server-clean.js" ]; then
    log "✅ Arquivo build/src/server-clean.js criado com sucesso!"
    echo "Tamanho do arquivo:"
    ls -lh build/src/server-clean.js
    
    # 6. Testar se o arquivo é válido
    log "Testando arquivo compilado..."
    if node -c build/src/server-clean.js; then
        log "✅ Arquivo JavaScript é válido!"
    else
        error "❌ Arquivo JavaScript tem erros de sintaxe"
        exit 1
    fi
else
    error "❌ Arquivo não foi criado"
    exit 1
fi

# 7. Iniciar PM2
log "Iniciando aplicação PM2..."
pm2 stop ncrisis-backend 2>/dev/null || true
pm2 delete ncrisis-backend 2>/dev/null || true
pm2 start build/src/server-clean.js --name ncrisis-backend

# 8. Verificar status
log "Verificando status..."
sleep 3
pm2 status

# 9. Salvar configuração
pm2 save

log "✅ Compilação e inicialização concluídas com sucesso!" 