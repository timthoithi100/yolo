FROM node:20-alpine AS build

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

FROM node:20-alpine

WORKDIR /app

COPY --from=build /usr/src/app .

EXPOSE 5000

CMD ["node", "server.js"]