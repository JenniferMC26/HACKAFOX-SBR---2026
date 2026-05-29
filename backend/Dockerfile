# ─────────────────────────────────────────────────────────────────────────────
# Paso — Dockerfile
#
# Imagen única para desarrollo:
#   - Node.js 20    → Cloud Functions + scripts de seed
#   - Python 3      → bigquery_seed.py
#   - Firebase CLI  → emulador de Functions + Hosting + deploy
#
# Supabase corre en la nube — no se levanta nada de DB/Storage/Auth localmente.
# El emulador solo expone Functions (5001) y Hosting (5000) + Emulator UI (4000).
# ─────────────────────────────────────────────────────────────────────────────

FROM node:22-slim

# Python + Java (requerido por el Firebase Emulator Suite) + curl.
RUN apt-get update && apt-get install -y \
    curl wget gnupg \
    && wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add - \
    && echo "deb https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo $VERSION_CODENAME) main" \
       >> /etc/apt/sources.list.d/adoptium.list \
    && apt-get update && apt-get install -y temurin-21-jre \
    && rm -rf /var/lib/apt/lists/*

# Firebase CLI global.
RUN npm install -g firebase-tools

# Dependencias de Python para los scripts de seed.
WORKDIR /app

# Instalar dependencias antes de copiar el resto — cachea bien.
COPY package*.json ./
RUN npm install
COPY functions/package*.json ./functions/
RUN cd functions && npm install

# Copiar el resto del proyecto.
COPY . .

# Puertos expuestos:
#   4000  → Emulator UI
#   5000  → Hosting (test console)
#   5001  → Functions
EXPOSE 4000 5000 5001

# `--host 0.0.0.0` se aplica via firebase.json (cada emulador tiene su host).
CMD ["firebase", "emulators:start", \
     "--only", "functions,hosting", \
     "--project", "paso"]
