FROM node:20-bookworm-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-bookworm-slim AS runtime

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ffmpeg python3 python3-pip curl ca-certificates bash unzip \
  && pip3 install --no-cache-dir --break-system-packages yt-dlp \
  && curl -fsSL https://opencode.ai/install | bash \
  && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.opencode/bin:${PATH}"

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package.json ./

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV NODE_ENV=production
EXPOSE 4096

ENTRYPOINT ["/entrypoint.sh"]
