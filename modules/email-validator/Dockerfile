FROM node:18-alpine

WORKDIR /app

# Copiar package.json
COPY package*.json ./

# Instalar dependências
RUN npm install

# Copiar código
COPY . .

# Criar diretórios necessários
RUN mkdir -p uploads reports

# Expor porta
EXPOSE 4001

# Comando para iniciar
CMD ["npm", "start"]
