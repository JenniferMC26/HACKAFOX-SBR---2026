# ─────────────────────────────────────────────────────────────────────────────
# Paso — Dockerfile
#
# Imagen única con todo lo necesario para desarrollar y correr el backend:
#   - Node.js 20  → Cloud Functions + scripts de seed
#   - Python 3    → bigquery_seed.py
#   - Firebase CLI → emulador local + deploy
#
# Construir:  docker compose build
# Levantar:   docker compose up
# ─────────────────────────────────────────────────────────────────────────────

FROM node:20-slim

# ── Python 3 + pip (para bigquery_seed.py) ───────────────────────────────────
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    openjdk-17-jre-headless \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Java es requerido por el Firebase Emulator Suite

# ── Firebase CLI (global) ─────────────────────────────────────────────────────
RUN npm install -g firebase-tools

# ── Dependencias de Python para los scripts de seed ──────────────────────────
# Se instalan aquí para no repetirlo cada vez que corre un script
RUN pip3 install --break-system-packages google-cloud-bigquery

# ── Directorio de trabajo ─────────────────────────────────────────────────────
WORKDIR /app

# ── Instalar dependencias de Node ─────────────────────────────────────────────
# Se copian los package.json primero para aprovechar el cache de Docker:
# si no cambian, Docker no reinstala en el siguiente build.
#  - /app/node_modules           → para scripts de seed (firebase-admin, ngeohash)
#  - /app/functions/node_modules → para las Cloud Functions
COPY package*.json ./
RUN npm install
COPY functions/package*.json ./functions/
RUN cd functions && npm install

# ── Copiar el resto del proyecto ──────────────────────────────────────────────
COPY . .

# ── Puertos del Firebase Emulator Suite ──────────────────────────────────────
# 4000  → Emulator UI   (panel visual para ver DB, Storage, Auth, logs)
# 5000  → Hosting       (sirve backend/public — test console)
# 5001  → Functions     (endpoints HTTP de las Cloud Functions)
# 9000  → Realtime DB   (Firebase Realtime Database emulada)
# 9099  → Auth          (Firebase Auth emulado)
# 9199  → Storage       (Firebase Storage emulado)
EXPOSE 4000 5000 5001 9000 9099 9199

# ── Comando por defecto: levantar los emuladores ──────────────────────────────
# `--host 0.0.0.0` es necesario dentro del contenedor para que los puertos sean
# accesibles desde la máquina host (por defecto firebase bindea a 127.0.0.1).
CMD ["firebase", "emulators:start", \
     "--only", "functions,database,storage,auth,hosting", \
     "--project", "paso"]
