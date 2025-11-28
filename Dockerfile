FROM node:18-alpine

WORKDIR /usr/src/app/clinica_backend

# Copiar sólo package.json y package-lock.json para aprovechar cache de capas
COPY clinica_backend/package*.json ./

# Usar npm install en lugar de npm ci para evitar fallo por lockfile inconsistente
RUN npm install --production

# Copiar el resto del código
COPY clinica_backend/ ./

EXPOSE 3000

CMD ["npm", "start"]
