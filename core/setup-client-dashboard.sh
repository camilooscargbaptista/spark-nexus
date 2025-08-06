#!/bin/bash

# Script de Setup do Client Dashboard para Spark Nexus - VERSÃO CORRIGIDA
# Execute este script na pasta spark-nexus/core

echo "🚀 Iniciando setup do Client Dashboard..."
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para verificar comandos
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 não está instalado${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $1 está instalado${NC}"
        return 0
    fi
}

# Função para verificar sucesso
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1 concluído com sucesso${NC}"
    else
        echo -e "${RED}❌ Erro em: $1${NC}"
        echo -e "${YELLOW}Tentando alternativa...${NC}"
        return 1
    fi
}

# Verificar pré-requisitos
echo -e "${BLUE}📋 Verificando pré-requisitos...${NC}"
echo ""

check_command node || exit 1
check_command npm || exit 1

# Verificar Angular CLI
if ! check_command ng; then
    echo -e "${YELLOW}📦 Instalando Angular CLI globalmente...${NC}"
    npm install -g @angular/cli@latest
    check_success "Instalação do Angular CLI"
fi

# Verificar versão do Node
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo -e "${RED}❌ Node.js versão 18+ é necessária (você tem v$NODE_VERSION)${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Node.js v$NODE_VERSION${NC}"
fi

echo ""
echo -e "${BLUE}🏗️  Preparando ambiente...${NC}"
echo ""

# Verificar se estamos na pasta correta
CURRENT_DIR=$(basename "$PWD")
if [ "$CURRENT_DIR" != "core" ]; then
    echo -e "${YELLOW}📁 Navegando para a pasta core...${NC}"
    if [ -d "core" ]; then
        cd core
    else
        echo -e "${RED}❌ Pasta 'core' não encontrada. Certifique-se de estar em spark-nexus${NC}"
        exit 1
    fi
fi

# Limpar projeto antigo
if [ -d "client-dashboard" ]; then
    echo -e "${YELLOW}🗑️  Removendo projeto antigo...${NC}"
    rm -rf client-dashboard
    echo -e "${GREEN}✅ Projeto antigo removido${NC}"
fi

echo ""
echo -e "${BLUE}📦 Criando novo projeto Angular...${NC}"
echo -e "${YELLOW}Isso pode levar alguns minutos...${NC}"
echo ""

# Criar projeto Angular com todas as flags necessárias para evitar prompts
ng new client-dashboard \
    --routing=true \
    --style=scss \
    --skip-git=true \
    --package-manager=npm \
    --ssr=false \
    --standalone=false \
    --strict=false

# Verificar se o projeto foi criado
if [ ! -d "client-dashboard" ]; then
    echo -e "${RED}❌ Falha ao criar o projeto${NC}"
    echo -e "${YELLOW}Tentando método alternativo...${NC}"
    
    # Método alternativo usando npx
    npx -p @angular/cli@latest ng new client-dashboard \
        --routing=true \
        --style=scss \
        --skip-git=true \
        --ssr=false \
        --standalone=false
fi

# Verificar novamente
if [ ! -d "client-dashboard" ]; then
    echo -e "${RED}❌ Não foi possível criar o projeto${NC}"
    exit 1
fi

# Entrar no projeto
cd client-dashboard
echo -e "${GREEN}✅ Projeto Angular criado com sucesso${NC}"
echo ""

# Configurar porta no angular.json
echo -e "${BLUE}⚙️  Configurando porta 4201...${NC}"

# Usar node para modificar o angular.json
node -e "
const fs = require('fs');
const path = 'angular.json';
const config = JSON.parse(fs.readFileSync(path, 'utf8'));

// Adicionar configuração de serve
if (config.projects && config.projects['client-dashboard']) {
    if (!config.projects['client-dashboard'].architect.serve.options) {
        config.projects['client-dashboard'].architect.serve.options = {};
    }
    config.projects['client-dashboard'].architect.serve.options.port = 4201;
    config.projects['client-dashboard'].architect.serve.options.host = '0.0.0.0';
    
    fs.writeFileSync(path, JSON.stringify(config, null, 2));
    console.log('✅ Porta configurada para 4201');
} else {
    console.error('❌ Estrutura do angular.json não reconhecida');
}
"

echo ""
echo -e "${BLUE}🎨 Instalando Angular Material...${NC}"

# Instalar Angular Material de forma não-interativa
npm install @angular/material @angular/cdk @angular/animations --save

# Adicionar tema ao styles.scss
echo '@import "@angular/material/prebuilt-themes/indigo-pink.css";' >> src/styles.scss
echo '@import url("https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500&display=swap");' >> src/styles.scss
echo '@import url("https://fonts.googleapis.com/icon?family=Material+Icons");' >> src/styles.scss

echo -e "${GREEN}✅ Angular Material instalado${NC}"

echo ""
echo -e "${BLUE}📦 Instalando dependências adicionais...${NC}"

# Instalar outras dependências
npm install chart.js ng2-charts --save
check_success "Instalação de chart.js e ng2-charts"

# Criar estrutura básica de pastas
echo ""
echo -e "${BLUE}📁 Criando estrutura de pastas...${NC}"

mkdir -p src/app/core/components
mkdir -p src/app/core/services
mkdir -p src/app/core/guards
mkdir -p src/app/core/interceptors
mkdir -p src/app/features
mkdir -p src/app/shared/components
mkdir -p src/app/shared/services
mkdir -p src/environments

echo -e "${GREEN}✅ Estrutura de pastas criada${NC}"

# Criar arquivos de ambiente
echo ""
echo -e "${BLUE}🌍 Criando arquivos de ambiente...${NC}"

cat > src/environments/environment.ts << 'EOF'
export const environment = {
  production: false,
  apiUrl: 'http://localhost:3001',
  wsUrl: 'ws://localhost:3001'
};
EOF

cat > src/environments/environment.prod.ts << 'EOF'
export const environment = {
  production: true,
  apiUrl: 'https://api.sparknexus.com',
  wsUrl: 'wss://api.sparknexus.com'
};
EOF

echo -e "${GREEN}✅ Arquivos de ambiente criados${NC}"

# Atualizar package.json com scripts úteis
echo ""
echo -e "${BLUE}📝 Atualizando scripts do package.json...${NC}"

npm pkg set scripts.start="ng serve --port 4201 --host 0.0.0.0"
npm pkg set scripts.start:local="ng serve --port 4201"
npm pkg set scripts.build:prod="ng build --configuration production"
npm pkg set scripts.build:dev="ng build --configuration development"
npm pkg set scripts.test="ng test"
npm pkg set scripts.lint="ng lint"

echo -e "${GREEN}✅ Scripts atualizados${NC}"

# Criar um componente de teste
echo ""
echo -e "${BLUE}🧪 Criando componente de teste...${NC}"

# Criar um app.component básico atualizado
cat > src/app/app.component.html << 'EOF'
<div style="text-align: center; padding: 50px; font-family: Arial, sans-serif;">
  <h1 style="color: #4f46e5;">🚀 Spark Nexus - Client Dashboard</h1>
  <p style="color: #64748b; font-size: 18px;">Setup concluído com sucesso!</p>
  <div style="margin-top: 30px; padding: 20px; background: #f1f5f9; border-radius: 8px;">
    <p style="margin: 10px 0;">✅ Angular instalado</p>
    <p style="margin: 10px 0;">✅ Angular Material configurado</p>
    <p style="margin: 10px 0;">✅ Chart.js pronto</p>
    <p style="margin: 10px 0;">✅ Porta 4201 configurada</p>
  </div>
  <div style="margin-top: 30px;">
    <p style="color: #94a3b8;">Próximo passo: Implementar os componentes</p>
  </div>
</div>
<router-outlet></router-outlet>
EOF

echo -e "${GREEN}✅ Componente de teste criado${NC}"

# Resumo final
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 SETUP COMPLETO COM SUCESSO! 🎉${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}📋 Resumo da instalação:${NC}"
echo "  ✅ Angular Project criado"
echo "  ✅ Angular Material instalado"
echo "  ✅ Chart.js e ng2-charts instalados"
echo "  ✅ Porta configurada para 4201"
echo "  ✅ Estrutura de pastas criada"
echo "  ✅ Ambientes configurados"
echo ""
echo -e "${YELLOW}🚀 Para iniciar o servidor de desenvolvimento:${NC}"
echo ""
echo "  cd client-dashboard"
echo "  npm start"
echo ""
echo -e "${BLUE}🌐 Acesse em:${NC} http://localhost:4201"
echo ""
echo -e "${GREEN}Happy coding! 💻${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"