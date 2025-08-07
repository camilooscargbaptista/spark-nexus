FROM node:18-alpine

WORKDIR /app

# Copiar arquivos de dependências
COPY package*.json ./

# Instalar dependências (usando npm install ao invés de npm ci)
RUN npm install --production

# Copiar código fonte
COPY . .

# Expor porta
EXPOSE 3002

# Comando para iniciar
CMD ["node", "src/index.js"]
