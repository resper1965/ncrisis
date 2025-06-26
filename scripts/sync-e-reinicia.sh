#!/bin/bash

cd /opt/ncrisis

echo "Verificando alterações locais não commitadas..."
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "\e[31mERRO: Existem alterações não commitadas no repositório.\e[0m"
  echo "Faça commit, stash ou descarte as alterações antes de sincronizar."
  exit 1
fi

echo "Sincronizando com o GitHub..."
git pull || { echo "\e[31mErro ao executar git pull\e[0m"; exit 1; }

echo "Instalando dependências do backend..."
npm install

echo "Instalando dependências do frontend..."
cd frontend && npm install && npm run build && cd ..

echo "Reiniciando containers Docker..."
docker compose down && docker compose up -d

echo "Sistema sincronizado e ativo!" 