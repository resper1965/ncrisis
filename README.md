# n.crisis - PII Detection & LGPD Compliance Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/Node.js-20+-green.svg)](https://nodejs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5+-blue.svg)](https://www.typescriptlang.org/)

## Overview

N.Crisis é uma plataforma avançada de detecção de dados pessoais (PII) e conformidade LGPD, construída com tecnologias modernas para oferecer análise em tempo real, busca semântica com IA e relatórios completos de conformidade.

### Principais Recursos

- **Detecção PII Avançada**: 7 tipos de dados brasileiros (CPF, CNPJ, RG, CEP, Email, Telefone, Nome)
- **IA Integrada**: OpenAI GPT-4o para análise contextual e FAISS para busca semântica
- **Interface Moderna**: Dashboard React com WebSocket para atualizações em tempo real
- **Processamento Assíncrono**: BullMQ com Redis para processamento de arquivos ZIP
- **Segurança Robusta**: Proteção contra zip-bomb, validação MIME, scanning de vírus
- **Conformidade LGPD**: Relatórios detalhados e gestão de incidentes

## Instalação Rápida

### Comando Único (Root) - Recomendado
```bash
wget -O install.sh https://raw.githubusercontent.com/resper1965/ncrisis/main/install-vps.sh && chmod +x install.sh && ./install.sh seudominio.com
```

### Se a Aplicação Não Iniciar
```bash
wget -O fix.sh https://raw.githubusercontent.com/resper1965/ncrisis/main/scripts/fix-vps-deployment.sh && chmod +x fix.sh && ./fix.sh
```

### Verificar Status
```bash
wget -O status.sh https://raw.githubusercontent.com/resper1965/ncrisis/main/scripts/vps-quick-status.sh && chmod +x status.sh && ./status.sh
```

## Requisitos

- Ubuntu 22.04 LTS
- Node.js 20+
- PostgreSQL 14+
- Redis 6+
- Nginx
- 2GB RAM mínimo
- 20GB espaço em disco

## Configuração

### Variáveis de Ambiente
```env
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://user:pass@localhost:5432/ncrisis
REDIS_URL=redis://default:pass@localhost:6379
OPENAI_API_KEY=sk-sua_chave_aqui
SENDGRID_API_KEY=SG.sua_chave_aqui
```

### API Keys Necessárias
- **OpenAI**: Para análise contextual e embeddings
- **SendGrid**: Para notificações por email

## Arquitetura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend       │    │   Database      │
│   React + TS    │◄──►│   Express + TS  │◄──►│   PostgreSQL    │
│   WebSocket     │    │   BullMQ        │    │   Redis         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Desenvolvimento

### Início Rápido
```bash
# Clonar repositório
git clone https://github.com/resper1965/ncrisis.git
cd ncrisis

# Instalar dependências
npm install

# Configurar ambiente
cp .env.example .env

# Executar desenvolvimento
npm run dev
```

### Scripts Disponíveis
```bash
npm run dev          # Desenvolvimento
npm run build        # Build produção
npm run test         # Testes
npm run lint         # Linting
npm start           # Iniciar produção
```

Antes de rodar os testes, garanta que o Prisma Client foi gerado:

```bash
npx prisma generate
```


### Gerar Prisma Client offline

Caso sua rede bloqueie acessos a `binaries.prisma.sh`, baixe as engines do Prisma em outra máquina e copie para um diretório (ex.: `prisma-engines`). Defina `PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1` e exporte os caminhos das engines antes de gerar o client:

```bash
export PRISMA_QUERY_ENGINE_BINARY=./prisma-engines/query-engine
export PRISMA_QUERY_ENGINE_LIBRARY=./prisma-engines/libquery_engine.so
export PRISMA_SCHEMA_ENGINE_BINARY=./prisma-engines/schema-engine
export PRISMA_FMT_BINARY=./prisma-engines/prisma-fmt
export PRISMA_INTROSPECTION_ENGINE_BINARY=./prisma-engines/introspection-engine
PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1 npx prisma generate
```

## Deployment

### Opções de Deploy

1. **VPS/Servidor Próprio** (Recomendado)
   - Script automatizado completo
   - SSL automático
   - 15-20 minutos para produção

2. **Replit Deploy**
   - Um clique para deploy
   - Domínio .replit.app gratuito

3. **Docker** (Próxima versão)
   - Containerização completa
   - Orquestração com compose

### Gerenciamento Pós-Deploy
```bash
cd /opt/ncrisis
./manage.sh status      # Status dos serviços
./manage.sh logs        # Logs em tempo real
./manage.sh restart     # Reiniciar aplicação
./manage.sh backup      # Backup banco
```

## Deploy Manual em VPS Ubuntu (Homologação)

### 1. Instale dependências do sistema
```bash
sudo apt update && sudo apt install -y nodejs npm git build-essential postgresql redis-server
```

### 2. Clone o repositório e instale dependências
```bash
git clone https://github.com/resper1965/ncrisis.git
cd ncrisis
npm install
```

### 3. Configure o banco de dados e variáveis de ambiente
- Crie o banco PostgreSQL e configure o usuário.
- Copie `.env.example` para `.env` e ajuste as variáveis.

### 4. Rode as migrations do banco
```bash
npm run db:migrate
```

### 5. Build do frontend e backend
```bash
npm run build
```

### 6. Inicie em modo produção
```bash
npm start
```

- O backend estará em `http://localhost:5000`.
- O frontend React será servido automaticamente se o build existir em `frontend/dist`.

### 7. (Opcional) Use PM2 ou systemd para manter o serviço ativo

### 8. Logs
```bash
tail -f /caminho/para/ncrisis/logs/*.log
```

## API Endpoints

### Core
- `GET /health` - Health check da aplicação
- `GET /api/queue/status` - Status das filas de processamento

### Upload e Processamento
- `POST /api/v1/archives/upload` - Upload de arquivos ZIP
- `GET /api/v1/reports/detections` - Relatório de detecções

### IA e Busca
- `POST /api/v1/chat` - Chat com IA para análise
- `POST /api/v1/search` - Busca semântica
- `POST /api/v1/embeddings` - Geração de embeddings

### WebSocket Events
- `join-session` - Entrar em sessão de processamento
- `progress-update` - Atualizações de progresso em tempo real

## Estrutura do Projeto

```
ncrisis/
├── src/
│   ├── app.ts                 # Aplicação principal
│   ├── server-clean.ts        # Entry point produção
│   ├── config/                # Configurações
│   ├── services/              # Serviços (PII, IA, etc.)
│   ├── routes/                # Rotas da API
│   ├── utils/                 # Utilitários
│   └── types/                 # Tipos TypeScript
├── frontend/                  # React frontend
├── prisma/                    # Schema e migrations
├── uploads/                   # Arquivos temporários
├── logs/                      # Logs da aplicação
└── scripts/                   # Scripts de deploy
```

## Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## Suporte

- **Documentação**: [Wiki do Projeto](https://github.com/resper1965/ncrisis/wiki)
- **Issues**: [GitHub Issues](https://github.com/resper1965/ncrisis/issues)
- **Discord**: [Comunidade n.crisis](https://discord.gg/ncrisis)

---

**n.crisis** - Protegendo dados, garantindo conformidade. 🛡️