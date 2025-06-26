#!/bin/bash

# Script para configurar SSL com Let's Encrypt
# Execute: wget -O setup-ssl.sh https://raw.githubusercontent.com/resper1965/ncrisis/main/scripts/setup-ssl.sh && chmod +x setup-ssl.sh && ./setup-ssl.sh

set -e

echo "🔒 Configurando SSL com Let's Encrypt..."

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   error "Este script deve ser executado como root"
   exit 1
fi

# 1. Instalar Certbot
log "📦 Instalando Certbot..."
apt update
apt install -y certbot python3-certbot-nginx

# 2. Verificar se os domínios estão apontando para o servidor
log "🔍 Verificando DNS..."
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "Verifique se os seguintes registros DNS estão configurados:"
echo "• ncrisis.e-ness.com.br -> $SERVER_IP"
echo "• auto.e-ness.com.br -> $SERVER_IP"
echo ""
read -p "Os domínios estão configurados corretamente? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Configure os registros DNS primeiro e execute o script novamente"
    exit 1
fi

# 3. Obter certificados SSL
log "🔐 Obtendo certificados SSL..."

# Certificado para ncrisis.e-ness.com.br
log "Obtendo certificado para ncrisis.e-ness.com.br..."
certbot --nginx -d ncrisis.e-ness.com.br --non-interactive --agree-tos --email admin@e-ness.com.br

# Certificado para auto.e-ness.com.br
log "Obtendo certificado para auto.e-ness.com.br..."
certbot --nginx -d auto.e-ness.com.br --non-interactive --agree-tos --email admin@e-ness.com.br

# 4. Configurar renovação automática
log "🔄 Configurando renovação automática..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# 5. Testar renovação
log "🧪 Testando renovação..."
certbot renew --dry-run

# 6. Verificar configuração Nginx
log "🔧 Verificando configuração Nginx..."
nginx -t

# 7. Reiniciar Nginx
log "🔄 Reiniciando Nginx..."
systemctl restart nginx

# 8. Configurar firewall para HTTPS
log "🔥 Configurando firewall..."
ufw allow 443

# 9. Final
log "🎉 SSL configurado com sucesso!"
echo ""
echo -e "${GREEN}📋 URLs HTTPS:${NC}"
echo -e "• n.crisis: https://ncrisis.e-ness.com.br"
echo -e "• n8n: https://auto.e-ness.com.br"
echo ""
echo -e "${GREEN}🔐 Credenciais n8n:${NC}"
echo -e "• Usuário: admin"
echo -e "• Senha: admin123"
echo ""
echo -e "${YELLOW}📝 Informações importantes:${NC}"
echo -e "• Certificados renovam automaticamente"
echo -e "• Logs de renovação: /var/log/letsencrypt/"
echo -e "• Certificados: /etc/letsencrypt/live/"
echo ""
echo -e "${BLUE}🔧 Comandos úteis:${NC}"
echo -e "• Verificar certificados: certbot certificates"
echo -e "• Renovar manualmente: certbot renew"
echo -e "• Status Nginx: systemctl status nginx"