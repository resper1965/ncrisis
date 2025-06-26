#!/bin/bash

# Script para sincronizar VPS com repositório e configurar Nginx
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

log "Iniciando sincronização do VPS com repositório Git"

# 1. Navegar para o diretório do projeto
cd $PROJECT_DIR

# 2. Verificar se é um repositório Git
if [ ! -d ".git" ]; then
    error "Diretório $PROJECT_DIR não é um repositório Git"
    exit 1
fi

# 3. Salvar mudanças locais se houver
log "Verificando mudanças locais..."
if ! git diff-index --quiet HEAD --; then
    warn "Existem mudanças locais não commitadas"
    log "Fazendo stash das mudanças locais..."
    git stash push -m "Mudanças locais antes do pull - $(date)"
fi

# 4. Fazer pull das mudanças remotas
log "Fazendo pull das mudanças remotas..."
git fetch origin
git reset --hard origin/main

# 5. Verificar se o script do Nginx existe
if [ ! -f "scripts/setup-nginx-proxy.sh" ]; then
    error "Script setup-nginx-proxy.sh não encontrado"
    exit 1
fi

# 6. Tornar o script executável
log "Tornando script executável..."
chmod +x scripts/setup-nginx-proxy.sh

# 7. Executar o script do Nginx
log "Executando configuração do Nginx..."
bash scripts/setup-nginx-proxy.sh

# 8. Verificar se a aplicação está rodando
log "Verificando status da aplicação..."
if pm2 list | grep -q "ncrisis"; then
    log "Aplicação PM2 encontrada"
    pm2 status
else
    warn "Aplicação PM2 não encontrada"
    log "Iniciando aplicação..."
    cd $PROJECT_DIR
    npm run build
    pm2 start dist/server.js --name ncrisis
    pm2 save
fi

# 9. Verificar status final
echo ""
log "=== SINCRONIZAÇÃO CONCLUÍDA ==="
info "Repositório atualizado"
info "Nginx configurado"
info "Aplicação verificada"
echo ""

# 10. Comandos úteis
log "Comandos úteis:"
echo "  Status da aplicação: pm2 status"
echo "  Logs da aplicação: pm2 logs ncrisis"
echo "  Status do Nginx: systemctl status nginx"
echo "  Logs do Nginx: tail -f /var/log/nginx/ncrisis.e-ness.com.br_error.log"
echo "  Testar proxy: curl -I http://localhost"
echo ""

log "Sincronização concluída com sucesso!" 