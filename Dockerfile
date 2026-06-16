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

# Dependências do sistema necessárias para postgresql-simple e direct-sqlite
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libsqlite3-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia os arquivos de configuração primeiro (cache de dependências)
COPY cabal.project meu-servant-api.cabal ./
RUN cabal update && cabal build --only-dependencies -j4

# Copia o restante do código e builda
COPY app/ ./app/
RUN cabal build -j4

# Copia o binário para um local fixo
RUN cp $(cabal list-bin meu-servant-api) /app/servidor

# ============================================================
# Estágio 3: Imagem final (leve)
# ============================================================
FROM debian:bookworm-slim

# Dependências de runtime
RUN apt-get update && apt-get install -y \
    libpq5 \
    libsqlite3-0 \
    python3 \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia o binário do backend
COPY --from=backend-builder /app/servidor ./servidor

# Copia os scripts Python
COPY scripts/ ./scripts/

# Copia o frontend buildado para dentro do servidor Haskell servir
COPY --from=frontend-builder /app/client/dist ./dist-newstyle/dist

# Instala dependências Python dos scripts
COPY requirements.txt ./
RUN pip3 install -r requirements.txt --break-system-packages

EXPOSE 8080

CMD ["./servidor"]
