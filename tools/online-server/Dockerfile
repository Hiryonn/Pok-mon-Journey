# Serveur en ligne Pokémon Journey — docker build -t pj-online . && docker run -d -p 7777:7777 -v pj-data:/data --restart unless-stopped pj-online
FROM node:22-alpine
WORKDIR /app
COPY server.js ./
ENV PJ_DATA=/data PJ_PORT=7777
VOLUME /data
EXPOSE 7777
USER node
CMD ["node", "server.js"]
