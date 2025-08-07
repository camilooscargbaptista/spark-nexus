FROM node:18-alpine

WORKDIR /app

# Copiar arquivos de dependências
COPY package*.json ./

# Instalar dependências
RUN npm install --production

# Copiar código
COPY . .

# Expor porta
EXPOSE 4001

# Comando para iniciar
CMD ["node", "src/index.js"]
