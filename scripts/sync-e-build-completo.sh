#!/bin/bash

# Aborta o script se qualquer comando falhar
set -e

# Navega para o diretório da aplicação
cd /opt/ncrisis

echo ">>> VERIFICANDO ALTERAÇÕES LOCAIS..."
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "❌ ERRO: Existem alterações não commitadas. Resolva antes de continuar."
  exit 1
fi
echo "✅ Repositório limpo."

echo -e "\n>>> SINCRONIZANDO COM O GITHUB..."
git pull || { echo "❌ ERRO: Falha no git pull."; exit 1; }
echo "✅ Sincronizado com sucesso."

echo -e "\n>>> INSTALANDO DEPENDÊNCIAS DO BACKEND..."
npm install
echo "✅ Dependências do backend instaladas."

# O build do backend é feito pelo Dockerfile, então não é necessário aqui.

echo -e "\n>>> INSTALANDO E BUILDANDO FRONTEND..."
cd frontend
npm install
npm run build
cd ..
echo "✅ Frontend pronto."

echo -e "\n>>> REINICIANDO AMBIENTE DOCKER..."
docker compose down
docker compose up -d --build --force-recreate
echo "✅ Containers Docker recriados e no ar."

echo -e "\n\n--- DIAGNÓSTICO FINAL ---"
echo -e "\n✅ COMMIT ATUAL:"
git log -1 --pretty=format:"%h - %s (%cr)"

echo -e "\n✅ CONTAINERS ATIVOS:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n✅ LOGS DO BACKEND (últimas 20 linhas):"
# Adiciona uma pequena pausa para o container estabilizar
sleep 10
docker compose logs --tail=20 app

echo -e "\n✅ TESTE DE SAÚDE DO BACKEND (localhost:8000/health):"
curl -f http://localhost:8000/health || echo -e "\n❌ AVISO: Backend não respondeu ao teste de saúde."

echo -e "\n\n🚀 PROCESSO CONCLUÍDO!" 