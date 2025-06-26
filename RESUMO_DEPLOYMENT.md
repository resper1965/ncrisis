# 📋 RESUMO DO DEPLOYMENT - n.crisis

**Data:** 26/06/2025  
**Status:** Aplicação compilada, banco de dados precisa ser inicializado  
**Última ação:** Tentativa de inicializar banco vazio

## 🎯 STATUS ATUAL

### ✅ O que está funcionando:
- ✅ **Compilação TypeScript** - Script `quick-build.sh` funcionando
- ✅ **Aplicação PM2** - Compilada e pronta para rodar
- ✅ **Arquivo JavaScript** - `build/src/server-clean.js` criado
- ✅ **Scripts criados** - Todos os scripts de automação prontos

### ❌ O que precisa ser resolvido:
- ❌ **Banco de dados vazio** - Tabelas não existem
- ❌ **Aplicação não inicia** - Erro de tabela `text_embeddings` não encontrada

## 🚀 PRÓXIMOS PASSOS (AMANHÃ)

### 1. Conectar ao VPS:
```bash
ssh root@SEU_IP_DO_VPS
cd /opt/ncrisis
```

### 2. Verificar status atual:
```bash
# Status do PM2
pm2 status

# Ver logs de erro
pm2 logs ncrisis-backend

# Verificar se arquivo existe
ls -la build/src/server-clean.js
```

### 3. Resolver problema do banco (ESCOLHA UMA OPÇÃO):

#### Opção A: Usar script automático (RECOMENDADO)
```bash
# Fazer pull das últimas correções
git pull origin main

# Executar script de inicialização do banco
sudo bash scripts/init-database.sh
```

#### Opção B: Manual (se script falhar)
```bash
# Parar aplicação
pm2 stop ncrisis-backend

# Verificar DATABASE_URL no .env
cat .env | grep DATABASE_URL

# Se necessário, configurar banco
nano .env

# Resetar banco (CUIDADO: apaga tudo!)
npx prisma migrate reset --force

# Executar migrações
npx prisma migrate deploy

# Iniciar aplicação
pm2 start build/src/server-clean.js --name ncrisis-backend
pm2 save
```

### 4. Testar aplicação:
```bash
# Testar health check
curl -I http://localhost:3000/health

# Ver logs
pm2 logs ncrisis-backend
```

### 5. Configurar Nginx (se necessário):
```bash
# Executar script do Nginx
sudo bash scripts/setup-nginx-proxy.sh

# Verificar status
systemctl status nginx
```

## 📁 SCRIPTS DISPONÍVEIS

| Script | Função |
|--------|--------|
| `scripts/quick-build.sh` | Compilação rápida sem verificações de tipo |
| `scripts/fix-database.sh` | Corrigir problemas de banco existente |
| `scripts/init-database.sh` | **Inicializar banco do zero** (RECOMENDADO) |
| `scripts/setup-nginx-proxy.sh` | Configurar Nginx como proxy |
| `scripts/sync-vps.sh` | Sincronizar VPS com repositório |
| `scripts/debug-build.sh` | Diagnosticar problemas de build |

## 🔧 COMANDOS ÚTEIS

### Verificar status:
```bash
pm2 status                    # Status da aplicação
systemctl status nginx        # Status do Nginx
curl -I http://localhost:3000 # Testar aplicação
```

### Logs:
```bash
pm2 logs ncrisis-backend      # Logs da aplicação
pm2 logs ncrisis-backend --lines 50  # Últimas 50 linhas
tail -f /var/log/nginx/ncrisis.e-ness.com.br_error.log  # Logs do Nginx
```

### Reiniciar:
```bash
pm2 restart ncrisis-backend   # Reiniciar aplicação
systemctl reload nginx        # Recarregar Nginx
```

## 🎯 OBJETIVO FINAL

1. ✅ Aplicação rodando na porta 3000
2. ✅ Banco de dados com todas as tabelas
3. ✅ Nginx configurado como proxy
4. ✅ Acessível via `ncrisis.e-ness.com.br`
5. ✅ SSL/HTTPS configurado (opcional)

## 📞 EM CASO DE PROBLEMAS

### Se banco continuar vazio:
```bash
# Verificar conexão com banco
npx prisma db pull

# Se falhar, verificar DATABASE_URL
cat .env | grep DATABASE_URL

# Testar conexão manual
psql $DATABASE_URL -c "SELECT 1;"
```

### Se aplicação não iniciar:
```bash
# Ver logs detalhados
pm2 logs ncrisis-backend --lines 100

# Verificar se arquivo existe
ls -la build/src/server-clean.js

# Recompilar se necessário
sudo bash scripts/quick-build.sh
```

---

**💡 DICA:** Comece sempre verificando o status atual com `pm2 status` e `pm2 logs ncrisis-backend` para entender onde parou. 