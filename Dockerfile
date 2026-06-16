# ============================================================
# Estágio 1: Build do Frontend (React + Vite)
# ============================================================
FROM node:20-slim AS frontend-builder

WORKDIR /app/client

COPY client/package*.json ./
RUN npm install

COPY client/ ./
RUN npm run build

# ============================================================
# Estágio 2: Build do Backend (Haskell + Cabal)
# ============================================================
FROM haskell:9.12.4 AS backend-builder

RUN apt-get update && apt-get install -y \
    libpq-dev \
    libsqlite3-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY cabal.project meu-servant-api.cabal ./
RUN cabal update && cabal build --only-dependencies -j4

COPY app/ ./app/
RUN cabal build -j4

RUN cp $(cabal list-bin meu-servant-api) /app/servidor

# ============================================================
# Estágio 3: Imagem final (leve)
# ============================================================
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libpq5 \
    libsqlite3-0 \
    python3 \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=backend-builder /app/servidor ./servidor
COPY scripts/ ./scripts/
COPY requirements.txt ./
RUN pip3 install -r requirements.txt --break-system-packages

# Frontend buildado vai para a pasta "dist" onde o Main.hs espera
COPY --from=frontend-builder /app/client/dist ./dist

EXPOSE 8080

CMD ["./servidor"]
