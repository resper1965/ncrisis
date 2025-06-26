#!/bin/bash

# Script para diagnosticar e corrigir erros do PM2
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

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   error "Este script deve ser executado como root"
   exit 1
fi

# Diretório do projeto
PROJECT_DIR="/opt/ncrisis"

log "Iniciando diagnóstico e correção do PM2"

# 1. Navegar para o diretório do projeto
cd $PROJECT_DIR

# 2. Parar aplicação se estiver rodando (antes de verificar logs)
log "Parando aplicação PM2..."
pm2 stop ncrisis-backend 2>/dev/null || true
pm2 delete ncrisis-backend 2>/dev/null || true

# 3. Verificar logs do PM2 (após parar)
log "Verificando logs do PM2..."
if [ -f "/root/.pm2/logs/ncrisis-backend-error.log" ]; then
    echo "=== ÚLTIMOS LOGS DE ERRO ==="
    tail -20 /root/.pm2/logs/ncrisis-backend-error.log
    echo ""
fi

# 4. Verificar se o arquivo existe
log "Verificando arquivo da aplicação..."
if [ ! -f "build/src/server-clean.js" ]; then
    error "Arquivo build/src/server-clean.js não encontrado"
    log "Fazendo build da aplicação..."
    npm run build
fi

# 5. Verificar variáveis de ambiente
log "Verificando arquivo .env..."
if [ ! -f ".env" ]; then
    error "Arquivo .env não encontrado"
    log "Copiando .env.example..."
    cp env.example .env
    warn "Configure as variáveis de ambiente no arquivo .env"
fi

# 6. Verificar dependências
log "Verificando dependências..."
if [ ! -d "node_modules" ]; then
    log "Instalando dependências..."
    npm install
fi

# 7. Fazer build
log "Fazendo build da aplicação..."
npm run build

# 8. Verificar se o build foi bem-sucedido
if [ ! -f "build/src/server-clean.js" ]; then
    error "Build falhou - arquivo build/src/server-clean.js não foi criado"
    exit 1
fi

# 9. Iniciar aplicação
log "Iniciando aplicação PM2..."
pm2 start build/src/server-clean.js --name ncrisis-backend

# 10. Verificar status
log "Verificando status da aplicação..."
sleep 3
pm2 status

# 11. Verificar logs novamente
log "Verificando logs após reinicialização..."
pm2 logs ncrisis-backend --lines 10

# 12. Salvar configuração PM2
log "Salvando configuração PM2..."
pm2 save

# 13. Verificar se está rodando na porta correta
log "Verificando se está rodando na porta 3000..."
if netstat -tlnp | grep ":3000 " > /dev/null; then
    log "✅ Aplicação está rodando na porta 3000"
else
    warn "❌ Aplicação não está rodando na porta 3000"
fi

# 14. Teste de conectividade
log "Testando conectividade..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|404\|500"; then
    log "✅ Aplicação responde na porta 3000"
else
    warn "❌ Aplicação não responde na porta 3000"
fi

# 15. Informações finais
echo ""
log "=== DIAGNÓSTICO CONCLUÍDO ==="
info "Aplicação PM2 reiniciada"
info "Logs disponíveis: pm2 logs ncrisis-backend"
info "Status: pm2 status"
echo ""

# 16. Comandos úteis
log "Comandos úteis:"
echo "  Ver logs: pm2 logs ncrisis-backend"
echo "  Ver status: pm2 status"
echo "  Reiniciar: pm2 restart ncrisis-backend"
echo "  Parar: pm2 stop ncrisis-backend"
echo "  Iniciar: pm2 start ncrisis-backend"
echo ""

log "Diagnóstico e correção concluídos!" 