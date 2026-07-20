# Build a static Harpy node binary, then ship it on bare Alpine.
# Used by docker-compose.testnet.yml for the staging testnet (MIC-74).
FROM crystallang/crystal:1.20-alpine AS build
WORKDIR /app
COPY shard.yml shard.lock ./
RUN shards install --production
COPY src ./src
RUN shards build harpy --release --static --no-debug

FROM alpine:3.21
RUN apk add --no-cache curl && adduser -D -H harpy
WORKDIR /app
COPY --from=build /app/bin/harpy /usr/local/bin/harpy
COPY public ./public
USER harpy
# HTTP API / P2P gossip
EXPOSE 3000 9333
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -fsS http://127.0.0.1:3000/health || exit 1
CMD ["harpy"]
