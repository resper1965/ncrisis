#!/bin/bash

# Script de Instalação n.crisis VPS Ubuntu (Multi-App)
# Para VPS com n8n ou outras aplicações
# Execute: wget -O install-multi.sh https://raw.githubusercontent.com/resper1965/ncrisis/main/install-vps-multi.sh && chmod +x install-multi.sh && ./install-multi.sh

set -e

echo "🚀 Instalando n.crisis na VPS Ubuntu (Multi-App Mode)..."

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

# Verificar portas em uso
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 0  # Porta em uso
    else
        return 1  # Porta livre
    fi
}

# 1. Verificar portas existentes
log "🔍 Verificando portas em uso..."
echo "Portas atualmente em uso:"
netstat -tuln | grep -E ':(80|443|5000|5678|5432|6379)' | head -10

# 2. Configurar portas para n.crisis
NC_PORT=5000
if check_port $NC_PORT; then
    warn "Porta $NC_PORT já está em uso"
    read -p "Digite uma porta alternativa para n.crisis (ex: 5001): " NC_PORT
    NC_PORT=${NC_PORT:-5001}
fi

# 3. Atualizar sistema
log "📦 Atualizando sistema..."
apt update && apt upgrade -y

# 4. Instalar dependências
log "🔧 Instalando dependências..."
apt install -y curl wget git build-essential postgresql postgresql-contrib redis-server nginx net-tools

# 5. Instalar Node.js 20
log "📦 Instalando Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 6. Configurar PostgreSQL (namespace separado)
log "🗄️ Configurando PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql -c "CREATE DATABASE ncrisis;" || true
sudo -u postgres psql -c "CREATE USER ncrisis_user WITH PASSWORD 'ncrisis123456';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ncrisis TO ncrisis_user;"
sudo -u postgres psql -c "ALTER USER ncrisis_user CREATEDB;"

# 7. Configurar Redis
log "🔴 Configurando Redis..."
systemctl start redis-server
systemctl enable redis-server

# 8. Clonar repositório
log "📥 Clonando repositório..."
cd /opt
rm -rf ncrisis
git clone https://github.com/resper1965/ncrisis.git
cd ncrisis

# 9. Instalar dependências
log "📦 Instalando dependências do projeto..."
npm install

# 10. Configurar .env com porta personalizada
log "⚙️ Configurando variáveis de ambiente..."
cat > .env << EOF
NODE_ENV=production
PORT=$NC_PORT
DATABASE_URL=postgresql://ncrisis_user:ncrisis123456@localhost:5432/ncrisis
REDIS_URL=redis://localhost:6379
OPENAI_API_KEY=
SENDGRID_API_KEY=
CORS_ORIGINS=http://localhost:3000,http://localhost:$NC_PORT,http://0.0.0.0:3000,http://0.0.0.0:$NC_PORT
UPLOAD_DIR=./uploads
TMP_DIR=./tmp
MAX_FILE_SIZE=104857600
HOST=0.0.0.0
EOF

echo -e "${YELLOW}⚠️ IMPORTANTE: Configure suas chaves da API no arquivo .env${NC}"
echo -e "${YELLOW}   nano .env${NC}"
read -p "Pressione Enter após configurar o .env..."

# 11. Configurar banco
log "🔧 Configurando banco..."
npm run db:generate
npm run db:migrate

# 12. Build
log "🔨 Fazendo build..."
npm run build

# 13. PM2 com namespace
log "📦 Instalando PM2..."
npm install -g pm2

pm2 delete ncrisis 2>/dev/null || true
pm2 start build/src/server-clean.js --name "ncrisis" --namespace "ncrisis"
pm2 startup
pm2 save

# 14. Nginx com subdomain/porta
log "🌐 Configurando Nginx..."
cat > /etc/nginx/sites-available/ncrisis << EOF
server {
    listen 80;
    server_name ncrisis.localhost;
    
    location / {
        proxy_pass http://localhost:$NC_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}

# Configuração alternativa por porta
server {
    listen $NC_PORT;
    server_name _;
    
    location / {
        proxy_pass http://localhost:$NC_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -sf /etc/nginx/sites-available/ncrisis /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
systemctl enable nginx

# 15. Firewall
log "🔥 Configurando firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow $NC_PORT

# 16. Diretórios
log "📁 Criando diretórios..."
mkdir -p uploads tmp logs
chown -R www-data:www-data uploads tmp logs
chmod -R 755 uploads tmp logs

# 17. Testar
log "🧪 Testando aplicação..."
sleep 5

if curl -f http://localhost:$NC_PORT/health > /dev/null 2>&1; then
    log "✅ Aplicação rodando!"
else
    warn "Verifique: pm2 logs ncrisis"
fi

# 18. Final
log "🎉 Instalação concluída!"
echo ""
echo -e "${GREEN}📋 URLs n.crisis:${NC}"
echo -e "• Backend: http://$(hostname -I | awk '{print $1}'):$NC_PORT"
echo -e "• Frontend: http://$(hostname -I | awk '{print $1}'):$NC_PORT"
echo -e "• Health: http://$(hostname -I | awk '{print $1}'):$NC_PORT/health"
echo ""
echo -e "${GREEN}🔧 Comandos:${NC}"
echo -e "• Status: pm2 status"
echo -e "• Logs: pm2 logs ncrisis"
echo -e "• Restart: pm2 restart ncrisis"
echo ""
echo -e "${YELLOW}📝 Notas para Multi-App:${NC}"
echo -e "• n.crisis rodando na porta: $NC_PORT"
echo -e "• n8n padrão: porta 5678"
echo -e "• PostgreSQL: porta 5432 (compartilhado)"
echo -e "• Redis: porta 6379 (compartilhado)"
echo ""
echo -e "${GREEN}🌐 Acesso por subdomain:${NC}"
echo -e "• Adicione ao /etc/hosts: 127.0.0.1 ncrisis.localhost"
echo -e "• Acesse: http://ncrisis.localhost" 