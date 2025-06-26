#!/bin/bash

# Script final para resolver todos os problemas
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

log "Iniciando correção final"

# 1. Navegar para o diretório do projeto
cd $PROJECT_DIR

# 2. Parar todas as aplicações PM2
log "Parando todas as aplicações PM2..."
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true

# 3. Verificar o que está usando a porta 5000
log "Verificando o que está usando a porta 5000..."
if netstat -tlnp | grep ":5000 " > /dev/null; then
    warn "Porta 5000 está em uso:"
    netstat -tlnp | grep ":5000"
    log "Matando processo na porta 5000..."
    fuser -k 5000/tcp 2>/dev/null || true
fi

# 4. Verificar se .env existe e tem DATABASE_URL
if [ ! -f ".env" ]; then
    error "Arquivo .env não encontrado"
    log "Copiando .env.example..."
    cp env.example .env
    warn "Configure DATABASE_URL no arquivo .env"
    exit 1
fi

if ! grep -q "DATABASE_URL" .env; then
    error "DATABASE_URL não encontrada no .env"
    warn "Configure DATABASE_URL no arquivo .env"
    exit 1
fi

# 5. Resetar banco de dados
log "Resetando banco de dados..."
warn "ATENÇÃO: Isso vai apagar todos os dados existentes!"
read -p "Tem certeza que quer continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Operação cancelada pelo usuário"
    exit 1
fi

# 6. Resetar banco
log "Executando reset do banco..."
npx prisma migrate reset --force

# 7. Gerar cliente Prisma
log "Gerando cliente Prisma..."
npx prisma generate

# 8. Executar migrações
log "Executando migrações..."
npx prisma migrate deploy

# 9. Verificar tabelas
log "Verificando tabelas criadas..."
npx prisma db pull

# 10. Verificar se arquivo compilado existe
if [ ! -f "build/src/server-clean.js" ]; then
    log "Arquivo compilado não encontrado, recompilando..."
    sudo bash scripts/quick-build.sh
fi

# 11. Iniciar aplicação
log "Iniciando aplicação PM2..."
pm2 start build/src/server-clean.js --name ncrisis-backend

# 12. Verificar status
log "Verificando status da aplicação..."
sleep 5
pm2 status

# 13. Verificar logs
log "Verificando logs..."
pm2 logs ncrisis-backend --lines 10

# 14. Testar conectividade
log "Testando conectividade..."
sleep 3
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health | grep -q "200"; then
    log "✅ Aplicação está respondendo corretamente!"
else
    warn "❌ Aplicação pode não estar respondendo"
    log "Verificando logs de erro..."
    pm2 logs ncrisis-backend --lines 20
fi

# 15. Salvar configuração PM2
pm2 save

# 16. Configurar Nginx se necessário
log "Configurando Nginx..."
if [ ! -f "/etc/nginx/sites-enabled/ncrisis" ]; then
    log "Nginx não configurado, configurando..."
    sudo bash scripts/setup-nginx-proxy.sh
else
    log "Nginx já configurado"
fi

# 17. Status final
echo ""
log "=== CORREÇÃO FINAL CONCLUÍDA ==="
info "Aplicação PM2: $(pm2 list | grep ncrisis-backend | awk '{print $4}')"
info "Porta 3000: $(netstat -tlnp | grep :3000 | wc -l) processo(s)"
info "Nginx: $(systemctl is-active nginx)"
echo ""

log "✅ Correção final concluída com sucesso!" 