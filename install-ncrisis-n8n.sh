#!/bin/bash

# Script de Instalação Completa: n.crisis + n8n
# Execute: wget -O install-complete.sh https://raw.githubusercontent.com/resper1965/ncrisis/main/install-ncrisis-n8n.sh && chmod +x install-complete.sh && ./install-complete.sh

set -e

echo "🚀 Instalando n.crisis + n8n na VPS Ubuntu..."

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

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
   error "Este script deve ser executado como root"
   exit 1
fi

# 1. Atualizar sistema
log "📦 Atualizando sistema..."
apt update && apt upgrade -y

# 2. Instalar dependências
log "🔧 Instalando dependências..."
apt install -y curl wget git build-essential postgresql postgresql-contrib redis-server nginx net-tools ufw

# 3. Instalar Node.js 20
log "📦 Instalando Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 4. Instalar Docker (para n8n)
log "🐳 Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $USER
systemctl start docker
systemctl enable docker

# 5. Instalar Docker Compose
log "📦 Instalando Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 6. Configurar PostgreSQL
log "🗄️ Configurando PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Criar bancos e usuários
sudo -u postgres psql -c "CREATE DATABASE ncrisis;" || true
sudo -u postgres psql -c "CREATE USER ncrisis_user WITH PASSWORD 'ncrisis123456';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ncrisis TO ncrisis_user;"
sudo -u postgres psql -c "ALTER USER ncrisis_user CREATEDB;"

sudo -u postgres psql -c "CREATE DATABASE n8n;" || true
sudo -u postgres psql -c "CREATE USER n8n_user WITH PASSWORD 'n8n123456';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n_user;"
sudo -u postgres psql -c "ALTER USER n8n_user CREATEDB;"

# 7. Configurar Redis
log "🔴 Configurando Redis..."
systemctl start redis-server
systemctl enable redis-server

# 8. Clonar repositório n.crisis
log "📥 Clonando repositório n.crisis..."
cd /opt
rm -rf ncrisis
git clone https://github.com/resper1965/ncrisis.git
cd ncrisis

# 9. Instalar dependências n.crisis
log "📦 Instalando dependências do n.crisis..."
npm install

# 10. Configurar .env n.crisis
log "⚙️ Configurando variáveis de ambiente n.crisis..."
cat > .env << EOF
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://ncrisis_user:ncrisis123456@localhost:5432/ncrisis
REDIS_URL=redis://localhost:6379
OPENAI_API_KEY=
SENDGRID_API_KEY=
CORS_ORIGINS=http://localhost:3000,http://localhost:5000,http://0.0.0.0:3000,http://0.0.0.0:5000
UPLOAD_DIR=./uploads
TMP_DIR=./tmp
MAX_FILE_SIZE=104857600
HOST=0.0.0.0
EOF

echo -e "${YELLOW}⚠️ IMPORTANTE: Configure suas chaves da API no arquivo .env${NC}"
echo -e "${YELLOW}   nano .env${NC}"
read -p "Pressione Enter após configurar o .env..."

# 11. Configurar banco n.crisis
log "🔧 Configurando banco n.crisis..."
npm run db:generate
npm run db:migrate

# 12. Build n.crisis
log "🔨 Fazendo build n.crisis..."
npm run build

# 13. PM2 para n.crisis
log "📦 Instalando PM2..."
npm install -g pm2

pm2 delete ncrisis 2>/dev/null || true
pm2 start build/src/server-clean.js --name "ncrisis"
pm2 startup
pm2 save

# 14. Instalar n8n via Docker
log "🤖 Instalando n8n..."
mkdir -p /opt/n8n
cd /opt/n8n

# Criar docker-compose para n8n
cat > docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=admin123
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - N8N_USER_MANAGEMENT_DISABLED=false
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_LOG_LEVEL=info
      - N8N_DATABASE_TYPE=postgresdb
      - N8N_DATABASE_POSTGRESDB_HOST=host.docker.internal
      - N8N_DATABASE_POSTGRESDB_PORT=5432
      - N8N_DATABASE_POSTGRESDB_DATABASE=n8n
      - N8N_DATABASE_POSTGRESDB_USER=n8n_user
      - N8N_DATABASE_POSTGRESDB_PASSWORD=n8n123456
      - N8N_REDIS_HOST=host.docker.internal
      - N8N_REDIS_PORT=6379
    volumes:
      - n8n-data:/home/node/.n8n
    extra_hosts:
      - "host.docker.internal:host-gateway"

volumes:
  n8n-data:
EOF

# Iniciar n8n
docker-compose up -d

# 15. Configurar Nginx como proxy reverso
log "🌐 Configurando Nginx..."
cat > /etc/nginx/sites-available/ncrisis-n8n << EOF
# Upstream servers
upstream ncrisis_backend {
    server 127.0.0.1:5000;
    keepalive 32;
}

upstream n8n_backend {
    server 127.0.0.1:5678;
    keepalive 32;
}

# n.crisis server block
server {
    listen 80;
    server_name ncrisis.e-ness.com.br;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' ws: wss:;" always;

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # n.crisis routes
    location / {
        proxy_pass http://ncrisis_backend;
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
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }

    # n.crisis API routes
    location /api/ {
        proxy_pass http://ncrisis_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # WebSocket support
    location /socket.io/ {
        proxy_pass http://ncrisis_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Redirect to HTTPS (uncomment when SSL is configured)
    # return 301 https://\$server_name\$request_uri;
}

# n8n server block
server {
    listen 80;
    server_name auto.e-ness.com.br;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://n8n_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts for n8n
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }

    # Redirect to HTTPS (uncomment when SSL is configured)
    # return 301 https://\$server_name\$request_uri;
}

# SSL Configuration (uncomment and configure when certificates are available)
# server {
#     listen 443 ssl http2;
#     server_name ncrisis.e-ness.com.br;
#     
#     ssl_certificate /etc/letsencrypt/live/ncrisis.e-ness.com.br/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/ncrisis.e-ness.com.br/privkey.pem;
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
#     ssl_prefer_server_ciphers off;
#     ssl_session_cache shared:SSL:10m;
#     ssl_session_timeout 10m;
#     
#     # Same location blocks as HTTP
#     location / {
#         proxy_pass http://ncrisis_backend;
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection 'upgrade';
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#         proxy_cache_bypass \$http_upgrade;
#     }
# }
# 
# server {
#     listen 443 ssl http2;
#     server_name auto.e-ness.com.br;
#     
#     ssl_certificate /etc/letsencrypt/live/auto.e-ness.com.br/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/auto.e-ness.com.br/privkey.pem;
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
#     ssl_prefer_server_ciphers off;
#     ssl_session_cache shared:SSL:10m;
#     ssl_session_timeout 10m;
#     
#     location / {
#         proxy_pass http://n8n_backend;
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection 'upgrade';
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#         proxy_cache_bypass \$http_upgrade;
#     }
# }
EOF

# Ativar configuração
ln -sf /etc/nginx/sites-available/ncrisis-n8n /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx

# 16. Configurar firewall
log "🔥 Configurando firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 5000
ufw allow 5678

# 17. Criar diretórios
log "📁 Criando diretórios..."
cd /opt/ncrisis
mkdir -p uploads tmp logs
chown -R www-data:www-data uploads tmp logs
chmod -R 755 uploads tmp logs

# 18. Testar aplicações
log "🧪 Testando aplicações..."
sleep 10

# Testar n.crisis
if curl -f http://localhost:5000/health > /dev/null 2>&1; then
    log "✅ n.crisis rodando!"
else
    warn "n.crisis não respondeu. Verifique: pm2 logs ncrisis"
fi

# Testar n8n
if curl -f http://localhost:5678 > /dev/null 2>&1; then
    log "✅ n8n rodando!"
else
    warn "n8n não respondeu. Verifique: docker logs n8n"
fi

# 19. Final
log "🎉 Instalação concluída!"
echo ""
echo -e "${GREEN}📋 URLs das Aplicações:${NC}"
echo -e "• n.crisis: http://ncrisis.e-ness.com.br"
echo -e "• n8n: http://auto.e-ness.com.br"
echo -e "• n.crisis Health: http://ncrisis.e-ness.com.br/health"
echo ""
echo -e "${GREEN}🔐 Credenciais n8n:${NC}"
echo -e "• Usuário: admin"
echo -e "• Senha: admin123"
echo ""
echo -e "${GREEN}🔧 Comandos Úteis:${NC}"
echo -e "• Status n.crisis: pm2 status"
echo -e "• Logs n.crisis: pm2 logs ncrisis"
echo -e "• Status n8n: docker ps | grep n8n"
echo -e "• Logs n8n: docker logs n8n"
echo -e "• Restart n.crisis: pm2 restart ncrisis"
echo -e "• Restart n8n: docker restart n8n"
echo ""
echo -e "${YELLOW}📝 Próximos Passos:${NC}"
echo -e "1. Configure suas chaves da API no arquivo .env"
echo -e "2. Configure os registros DNS:"
echo -e "   • ncrisis.e-ness.com.br -> $(hostname -I | awk '{print $1}')"
echo -e "   • auto.e-ness.com.br -> $(hostname -I | awk '{print $1}')"
echo -e "3. Configure SSL: ./scripts/setup-ssl.sh"
echo -e "4. Acesse n8n e altere a senha padrão"
echo -e "5. Configure workflows no n8n para integração com n.crisis"
echo ""
echo -e "${BLUE}🌐 Integração:${NC}"
echo -e "• n8n pode chamar APIs do n.crisis via HTTP"
echo -e "• n.crisis pode disparar workflows do n8n"
echo -e "• Ambos compartilham PostgreSQL e Redis"
echo ""
echo -e "${BLUE}🔒 SSL (Opcional):${NC}"
echo -e "• Execute: wget -O setup-ssl.sh https://raw.githubusercontent.com/resper1965/ncrisis/main/scripts/setup-ssl.sh"
echo -e "• Execute: chmod +x setup-ssl.sh && ./setup-ssl.sh"
echo -e "• URLs HTTPS: https://ncrisis.e-ness.com.br e https://auto.e-ness.com.br" 