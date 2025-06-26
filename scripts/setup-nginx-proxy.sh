#!/bin/bash

# Script para configurar Nginx como proxy reverso para ncrisis.e-ness.com.br
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

# Variáveis
DOMAIN="ncrisis.e-ness.com.br"
APP_PORT="3000"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
SITE_CONFIG="$NGINX_AVAILABLE/$DOMAIN"

log "Iniciando configuração do Nginx para $DOMAIN"

# 1. Verificar se Nginx está instalado
if ! command -v nginx &> /dev/null; then
    error "Nginx não está instalado. Instalando..."
    apt update
    apt install -y nginx
fi

# 2. Criar diretórios se não existirem
log "Criando diretórios do Nginx..."
mkdir -p $NGINX_AVAILABLE
mkdir -p $NGINX_ENABLED

# 3. Criar configuração do site
log "Criando configuração do Nginx para $DOMAIN..."

cat > $SITE_CONFIG << EOF
# Configuração do Nginx para $DOMAIN
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Logs
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;
    
    # Configurações de segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Configurações de proxy
    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Configurações para arquivos estáticos (se necessário)
    location /static/ {
        alias /opt/ncrisis/public/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Configurações de gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
}

# Redirecionamento de www para non-www (opcional)
server {
    listen 80;
    server_name www.$DOMAIN;
    return 301 http://\$host\$request_uri;
}
EOF

# 4. Verificar se a configuração foi criada
if [ ! -f "$SITE_CONFIG" ]; then
    error "Falha ao criar arquivo de configuração"
    exit 1
fi

log "Configuração criada em $SITE_CONFIG"

# 5. Remover configuração padrão se existir
if [ -f "$NGINX_ENABLED/default" ]; then
    log "Removendo configuração padrão do Nginx..."
    rm -f "$NGINX_ENABLED/default"
fi

# 6. Criar symlink
log "Criando symlink para habilitar o site..."
ln -sf "$SITE_CONFIG" "$NGINX_ENABLED/ncrisis"

# 7. Verificar configuração do Nginx
log "Testando configuração do Nginx..."
if nginx -t; then
    log "Configuração do Nginx está válida"
else
    error "Configuração do Nginx inválida. Verifique os logs."
    exit 1
fi

# 8. Recarregar Nginx
log "Recarregando Nginx..."
systemctl reload nginx

# 9. Verificar status
if systemctl is-active --quiet nginx; then
    log "Nginx está rodando"
else
    error "Nginx não está rodando. Iniciando..."
    systemctl start nginx
fi

# 10. Configurar firewall (se ufw estiver disponível)
if command -v ufw &> /dev/null; then
    log "Configurando firewall..."
    ufw allow 'Nginx Full'
    ufw allow 80/tcp
    ufw allow 443/tcp
fi

# 11. Verificar se a aplicação está rodando
log "Verificando se a aplicação está rodando na porta $APP_PORT..."
if netstat -tlnp | grep ":$APP_PORT " > /dev/null; then
    log "Aplicação está rodando na porta $APP_PORT"
else
    warn "Aplicação não está rodando na porta $APP_PORT"
    warn "Certifique-se de que a aplicação está iniciada antes de testar o proxy"
fi

# 12. Teste de conectividade
log "Testando conectividade..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost/health | grep -q "200"; then
    log "Proxy está funcionando corretamente"
else
    warn "Proxy pode não estar funcionando. Verifique se a aplicação está rodando."
fi

# 13. Informações finais
echo ""
log "=== CONFIGURAÇÃO CONCLUÍDA ==="
info "Domínio: $DOMAIN"
info "Porta da aplicação: $APP_PORT"
info "Configuração: $SITE_CONFIG"
info "Logs: /var/log/nginx/${DOMAIN}_*.log"
echo ""
warn "PRÓXIMOS PASSOS:"
echo "1. Configure o DNS para apontar $DOMAIN para este servidor"
echo "2. Configure SSL/HTTPS com Let's Encrypt:"
echo "   certbot --nginx -d $DOMAIN"
echo "3. Teste o acesso: http://$DOMAIN"
echo "4. Monitore os logs: tail -f /var/log/nginx/${DOMAIN}_error.log"
echo ""

# 14. Comandos úteis
log "Comandos úteis:"
echo "  Status do Nginx: systemctl status nginx"
echo "  Logs do Nginx: tail -f /var/log/nginx/${DOMAIN}_error.log"
echo "  Testar configuração: nginx -t"
echo "  Recarregar Nginx: systemctl reload nginx"
echo "  Verificar porta: netstat -tlnp | grep :$APP_PORT"
echo ""

log "Configuração do Nginx concluída com sucesso!" 