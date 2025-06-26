#!/bin/bash

# Script para diagnosticar problemas de build do TypeScript
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

log "Iniciando diagnóstico de build"

# 1. Navegar para o diretório do projeto
cd $PROJECT_DIR

# 2. Verificar se TypeScript está instalado
log "Verificando TypeScript..."
if ! command -v npx &> /dev/null; then
    error "npx não está disponível"
    exit 1
fi

# 3. Verificar se tsc está disponível
log "Verificando tsc..."
if ! npx tsc --version &> /dev/null; then
    error "TypeScript não está instalado"
    log "Instalando TypeScript..."
    npm install typescript
fi

# 4. Verificar arquivo tsconfig.json
log "Verificando tsconfig.json..."
if [ ! -f "tsconfig.json" ]; then
    error "tsconfig.json não encontrado"
    exit 1
fi

echo "Conteúdo do tsconfig.json:"
cat tsconfig.json
echo ""

# 5. Verificar arquivos TypeScript
log "Verificando arquivos TypeScript..."
echo "Arquivos em src/:"
find src/ -name "*.ts" | head -10

# 6. Verificar se server-clean.ts existe
log "Verificando server-clean.ts..."
if [ ! -f "src/server-clean.ts" ]; then
    error "src/server-clean.ts não encontrado"
    echo "Arquivos em src/:"
    ls -la src/
    exit 1
fi

# 7. Tentar compilação com verbose
log "Tentando compilação TypeScript com verbose..."
echo "Executando: npx tsc --listFiles"
npx tsc --listFiles 2>&1 || {
    error "Compilação falhou. Tentando com mais detalhes..."
    echo "Executando: npx tsc --diagnostics"
    npx tsc --diagnostics 2>&1 || true
}

# 8. Verificar se build foi criado
log "Verificando se build foi criado..."
if [ -d "build" ]; then
    echo "Conteúdo do diretório build/:"
    find build/ -type f | head -20
else
    error "Diretório build/ não foi criado"
fi

# 9. Tentar compilação manual
log "Tentando compilação manual..."
echo "Criando diretório build/src/..."
mkdir -p build/src/

echo "Compilando apenas server-clean.ts..."
npx tsc src/server-clean.ts --outDir build/src/ --target ES2022 --module CommonJS 2>&1 || {
    error "Compilação manual falhou"
    echo "Erros de compilação:"
    npx tsc src/server-clean.ts --outDir build/src/ --target ES2022 --module CommonJS
}

# 10. Verificar resultado
log "Verificando resultado..."
if [ -f "build/src/server-clean.js" ]; then
    log "✅ Arquivo build/src/server-clean.js criado com sucesso!"
    echo "Tamanho do arquivo:"
    ls -lh build/src/server-clean.js
else
    error "❌ Arquivo ainda não foi criado"
    echo "Conteúdo de build/src/:"
    ls -la build/src/ 2>/dev/null || echo "Diretório vazio ou não existe"
fi

# 11. Informações finais
echo ""
log "=== DIAGNÓSTICO CONCLUÍDO ==="
info "Verifique os erros acima para identificar o problema"
echo ""

log "Diagnóstico concluído!" 