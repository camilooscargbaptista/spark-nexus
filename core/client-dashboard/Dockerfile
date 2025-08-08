FROM node:18-alpine

WORKDIR /app

# Copiar package.json
COPY package*.json ./

# Instalar dependências
RUN npm install

# Copiar código
COPY . .

# Criar diretório de uploads
RUN mkdir -p uploads

EXPOSE 4201

CMD ["node", "server.js"]
