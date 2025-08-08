FROM node:18-alpine

WORKDIR /app

# Copiar package files
COPY package*.json ./

# Instalar dependências
RUN npm install

# Copiar código
COPY . .

# Criar diretórios necessários
RUN mkdir -p uploads services/routes services/data

# Expor porta
EXPOSE 4201

# Comando para iniciar
CMD ["node", "server.js"]
