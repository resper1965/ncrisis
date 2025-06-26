#!/bin/bash

# Script de Instalação n.crisis VPS Ubuntu
# Execute: wget -O install-vps.sh https://raw.githubusercontent.com/resper1965/ncrisis/main/install-vps.sh && chmod +x install-vps.sh && ./install-vps.sh

set -e

echo "🚀 Instalando n.crisis na VPS Ubuntu..."

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

# 1. Atualizar sistema
log "📦 Atualizando sistema..."
apt update && apt upgrade -y

# 2. Instalar dependências
log "🔧 Instalando dependências..."
apt install -y curl wget git build-essential postgresql postgresql-contrib redis-server nginx

# 3. Instalar Node.js 20
log "📦 Instalando Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# 4. Configurar PostgreSQL
log "🗄️ Configurando PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql -c "CREATE DATABASE ncrisis;" || true
sudo -u postgres psql -c "CREATE USER ncrisis_user WITH PASSWORD 'ncrisis123456';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ncrisis TO ncrisis_user;"
sudo -u postgres psql -c "ALTER USER ncrisis_user CREATEDB;"

# 5. Configurar Redis
log "🔴 Configurando Redis..."
systemctl start redis-server
systemctl enable redis-server

# 6. Clonar repositório
log "📥 Clonando repositório..."
cd /opt
rm -rf ncrisis
git clone https://github.com/resper1965/ncrisis.git
cd ncrisis

# 7. Instalar dependências
log "📦 Instalando dependências do projeto..."
npm install

# 8. Configurar .env básico
log "⚙️ Configurando variáveis de ambiente..."
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

# 9. Configurar banco
log "🔧 Configurando banco..."
npm run db:generate
npm run db:migrate

# 10. Build
log "🔨 Fazendo build..."
npm run build

# 11. PM2
log "📦 Instalando PM2..."
npm install -g pm2

pm2 delete ncrisis 2>/dev/null || true
pm2 start build/src/server-clean.js --name "ncrisis"
pm2 startup
pm2 save

# 12. Nginx
log "🌐 Configurando Nginx..."
cat > /etc/nginx/sites-available/ncrisis << EOF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:5000;
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
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx

# 13. Firewall
log "🔥 Configurando firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 5000

# 14. Diretórios
log "📁 Criando diretórios..."
mkdir -p uploads tmp logs
chown -R www-data:www-data uploads tmp logs
chmod -R 755 uploads tmp logs

# 15. Testar
log "🧪 Testando aplicação..."
sleep 5

if curl -f http://localhost:5000/health > /dev/null 2>&1; then
    log "✅ Aplicação rodando!"
else
    echo -e "${YELLOW}⚠️ Verifique: pm2 logs ncrisis${NC}"
fi

# 16. Final
log "🎉 Instalação concluída!"
echo ""
echo -e "${GREEN}📋 URLs:${NC}"
echo -e "• Backend: http://$(hostname -I | awk '{print $1}'):5000"
echo -e "• Frontend: http://$(hostname -I | awk '{print $1}')"
echo -e "• Health: http://$(hostname -I | awk '{print $1}'):5000/health"
echo ""
echo -e "${GREEN}🔧 Comandos:${NC}"
echo -e "• Status: pm2 status"
echo -e "• Logs: pm2 logs ncrisis"
echo -e "• Restart: pm2 restart ncrisis" 