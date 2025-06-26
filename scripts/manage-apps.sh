#!/bin/bash

# Script de Gerenciamento: n.crisis + n8n
# Execute: ./scripts/manage-apps.sh

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️ $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ️ $1${NC}"
}

show_menu() {
    echo ""
    echo -e "${BLUE}🔧 Gerenciador n.crisis + n8n${NC}"
    echo "=================================="
    echo "1. Status das aplicações"
    echo "2. Iniciar todas as aplicações"
    echo "3. Parar todas as aplicações"
    echo "4. Reiniciar todas as aplicações"
    echo "5. Logs n.crisis"
    echo "6. Logs n8n"
    echo "7. Status do banco de dados"
    echo "8. Status do Redis"
    echo "9. Status do Nginx"
    echo "10. Backup do banco"
    echo "11. Configurar SSL"
    echo "12. Atualizar aplicações"
    echo "0. Sair"
    echo "=================================="
}

check_ncrisis() {
    if pm2 list | grep -q "ncrisis"; then
        echo -e "${GREEN}✅ n.crisis: Rodando${NC}"
    else
        echo -e "${RED}❌ n.crisis: Parado${NC}"
    fi
}

check_n8n() {
    if docker ps | grep -q "n8n"; then
        echo -e "${GREEN}✅ n8n: Rodando${NC}"
    else
        echo -e "${RED}❌ n8n: Parado${NC}"
    fi
}

check_database() {
    if sudo -u postgres psql -c "SELECT 1;" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL: Conectado${NC}"
    else
        echo -e "${RED}❌ PostgreSQL: Erro${NC}"
    fi
}

check_redis() {
    if systemctl is-active --quiet redis-server; then
        echo -e "${GREEN}✅ Redis: Rodando${NC}"
    else
        echo -e "${RED}❌ Redis: Parado${NC}"
    fi
}

check_nginx() {
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✅ Nginx: Rodando${NC}"
    else
        echo -e "${RED}❌ Nginx: Parado${NC}"
    fi
}

status_all() {
    echo ""
    info "Status das Aplicações:"
    echo "======================"
    check_ncrisis
    check_n8n
    echo ""
    info "Status dos Serviços:"
    echo "===================="
    check_database
    check_redis
    check_nginx
    echo ""
    info "URLs de Acesso:"
    echo "==============="
    echo -e "• n.crisis: http://ncrisis.e-ness.com.br"
    echo -e "• n8n: http://auto.e-ness.com.br"
    echo -e "• Health: http://ncrisis.e-ness.com.br/health"
}

start_all() {
    log "Iniciando todas as aplicações..."
    
    # Iniciar n.crisis
    cd /opt/ncrisis
    pm2 start build/src/server-clean.js --name "ncrisis" 2>/dev/null || pm2 restart ncrisis
    
    # Iniciar n8n
    cd /opt/n8n
    docker-compose up -d
    
    # Verificar status
    sleep 3
    status_all
}

stop_all() {
    log "Parando todas as aplicações..."
    
    # Parar n.crisis
    pm2 stop ncrisis 2>/dev/null || true
    
    # Parar n8n
    cd /opt/n8n
    docker-compose down
    
    log "Aplicações paradas"
}

restart_all() {
    log "Reiniciando todas as aplicações..."
    stop_all
    sleep 2
    start_all
}

show_logs() {
    echo ""
    echo -e "${BLUE}📋 Logs n.crisis (últimas 20 linhas):${NC}"
    echo "=========================================="
    pm2 logs ncrisis --lines 20 --nostream 2>/dev/null || echo "n.crisis não está rodando"
    echo ""
}

show_n8n_logs() {
    echo ""
    echo -e "${BLUE}📋 Logs n8n (últimas 20 linhas):${NC}"
    echo "======================================"
    docker logs n8n --tail 20 2>/dev/null || echo "n8n não está rodando"
    echo ""
}

backup_database() {
    log "Fazendo backup do banco de dados..."
    
    BACKUP_DIR="/opt/backups"
    mkdir -p $BACKUP_DIR
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    # Backup n.crisis
    sudo -u postgres pg_dump ncrisis > "$BACKUP_DIR/ncrisis_$TIMESTAMP.sql"
    
    # Backup n8n
    sudo -u postgres pg_dump n8n > "$BACKUP_DIR/n8n_$TIMESTAMP.sql"
    
    log "Backup concluído em $BACKUP_DIR/"
    ls -la "$BACKUP_DIR/"*.sql | tail -2
}

setup_ssl() {
    log "Configurando SSL..."
    
    if [ -f "/opt/ncrisis/scripts/setup-ssl.sh" ]; then
        cd /opt/ncrisis
        ./scripts/setup-ssl.sh
    else
        error "Script de SSL não encontrado"
        info "Execute: wget -O setup-ssl.sh https://raw.githubusercontent.com/resper1965/ncrisis/main/scripts/setup-ssl.sh"
    fi
}

update_apps() {
    log "Atualizando aplicações..."
    
    # Atualizar n.crisis
    cd /opt/ncrisis
    git pull origin main
    npm install
    npm run build
    pm2 restart ncrisis
    
    # Atualizar n8n
    cd /opt/n8n
    docker-compose pull
    docker-compose up -d
    
    log "Aplicações atualizadas"
}

# Menu principal
while true; do
    show_menu
    read -p "Escolha uma opção: " choice
    
    case $choice in
        1)
            status_all
            ;;
        2)
            start_all
            ;;
        3)
            stop_all
            ;;
        4)
            restart_all
            ;;
        5)
            show_logs
            ;;
        6)
            show_n8n_logs
            ;;
        7)
            check_database
            ;;
        8)
            check_redis
            ;;
        9)
            check_nginx
            ;;
        10)
            backup_database
            ;;
        11)
            setup_ssl
            ;;
        12)
            update_apps
            ;;
        0)
            log "Saindo..."
            exit 0
            ;;
        *)
            error "Opção inválida"
            ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done 