#!/bin/bash

# ================================================
# Script de Instalação de Dependências
# Validador de Email Avançado - Spark Nexus
# ================================================

echo "================================================"
echo "🚀 SPARK NEXUS - Email Validator Setup"
echo "================================================"
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar se está no diretório correto
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ Erro: package.json não encontrado!${NC}"
    echo "Certifique-se de estar no diretório client-dashboard/"
    exit 1
fi

# Verificar se é o projeto correto
if ! grep -q "sparknexus-client-dashboard" package.json; then
    echo -e "${YELLOW}⚠️  Aviso: Este pode não ser o projeto correto${NC}"
    read -p "Deseja continuar? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${BLUE}📦 Instalando dependências para o Validador de Email...${NC}"
echo ""

# Backup do package.json
echo -e "${YELLOW}📋 Criando backup do package.json...${NC}"
cp package.json package.json.backup-$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✅ Backup criado${NC}"
echo ""

# Instalar dependências essenciais
echo -e "${BLUE}1️⃣ Instalando validador RFC 5322...${NC}"
npm install email-validator@^2.0.4
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ email-validator instalado${NC}"
else
    echo -e "${RED}❌ Erro ao instalar email-validator${NC}"
fi
echo ""

echo -e "${BLUE}2️⃣ Instalando suporte para domínios internacionais...${NC}"
npm install punycode@^2.3.1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ punycode instalado${NC}"
else
    echo -e "${RED}❌ Erro ao instalar punycode${NC}"
fi
echo ""

echo -e "${BLUE}3️⃣ Instalando analisador de TLD...${NC}"
npm install tldts@^6.1.0
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ tldts instalado${NC}"
else
    echo -e "${RED}❌ Erro ao instalar tldts${NC}"
fi
echo ""

echo -e "${BLUE}4️⃣ Instalando base de domínios descartáveis...${NC}"
npm install disposable-email-domains@^2.0.0
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ disposable-email-domains instalado${NC}"
else
    echo -e "${RED}❌ Erro ao instalar disposable-email-domains${NC}"
fi
echo ""

# Opcional: Instalar dependências adicionais
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Deseja instalar dependências opcionais?${NC}"
echo "1. dns-socket (DNS lookup mais robusto)"
echo "2. Nenhuma"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "Escolha (1-2): " optional

if [ "$optional" = "1" ]; then
    echo -e "${BLUE}📦 Instalando dns-socket...${NC}"
    npm install dns-socket@^4.2.2
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ dns-socket instalado${NC}"
    else
        echo -e "${RED}❌ Erro ao instalar dns-socket${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Instalação concluída!${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Mostrar resumo
echo -e "${BLUE}📊 Resumo das dependências instaladas:${NC}"
echo ""
if npm list email-validator &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} email-validator - Validação RFC 5322"
fi
if npm list punycode &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} punycode - Suporte a domínios internacionais"
fi
if npm list tldts &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} tldts - Análise de TLD e domínios"
fi
if npm list disposable-email-domains &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} disposable-email-domains - Base de 100k+ domínios"
fi
if npm list dns-socket &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} dns-socket - DNS lookup robusto"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 Próximos passos:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "1. Criar a estrutura de pastas:"
echo "   mkdir -p services/validators"
echo "   mkdir -p services/data"
echo ""
echo "2. Implementar os validadores"
echo "3. Configurar as rotas no server.js"
echo "4. Testar as validações"
echo ""
echo -e "${GREEN}📝 Backup salvo em: package.json.backup-*${NC}"
echo ""

# Perguntar se quer criar estrutura de pastas
read -p "Deseja criar a estrutura de pastas agora? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}📁 Criando estrutura de pastas...${NC}"

    # Criar estrutura de diretórios
    mkdir -p services/validators
    mkdir -p services/data
    mkdir -p services/utils
    mkdir -p services/config
    mkdir -p tests/validators
    mkdir -p tests/fixtures
    mkdir -p scripts

    echo -e "${GREEN}✅ Estrutura criada:${NC}"
    echo "   services/"
    echo "   ├── validators/"
    echo "   ├── data/"
    echo "   ├── utils/"
    echo "   └── config/"
    echo "   tests/"
    echo "   ├── validators/"
    echo "   └── fixtures/"
    echo "   scripts/"
    echo ""
fi

echo -e "${GREEN}✨ Setup completo! Pronto para implementar o validador avançado.${NC}"
echo ""
