# Nuxt.js用のDockerfile
FROM node:20-alpine AS builder

WORKDIR /app

# package.jsonとpackage-lock.jsonをコピー
COPY package*.json ./

# 依存関係のインストール
RUN npm ci

# アプリケーションコードをコピー
COPY . .

# Nuxt.jsアプリケーションをビルド
RUN npm run build

# 本番用イメージ
FROM node:20-alpine

WORKDIR /app

# ビルドしたアプリケーションをコピー
COPY --from=builder /app/.output ./

# ポート3000を公開
EXPOSE 3000

# アプリケーションの起動
ENV HOST=0.0.0.0
ENV PORT=3000

CMD ["node", "server/index.mjs"]

