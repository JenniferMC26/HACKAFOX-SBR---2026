# ─────────────────────────────────────────────────────────────────────────────
# Paso — Dockerfile (solo para el runner de seed)
#
# Node 22 slim con las deps de seed pre-instaladas. La test console (HTML+JS)
# la sirve nginx directo desde public/ — ver docker-compose.yml.
# ─────────────────────────────────────────────────────────────────────────────

FROM node:22-slim
WORKDIR /app

# Instalar deps primero (cachea bien si cambias seeds sin tocar package.json).
COPY package*.json ./
RUN npm install

# El resto del proyecto se monta como volumen en runtime (docker-compose).
