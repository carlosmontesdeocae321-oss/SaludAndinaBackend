FROM node:18-alpine

# Create app directory and set working dir to backend folder
WORKDIR /usr/src/app/clinica_backend

# Install app dependencies (using package-lock if present)
COPY clinica_backend/package*.json ./
RUN npm ci --only=production

# Copy backend source
COPY clinica_backend/ ./

ENV NODE_ENV=production
EXPOSE 3000

CMD ["npm", "start"]
