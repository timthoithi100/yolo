FROM node:20-alpine AS build

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

ENV NODE_OPTIONS=--openssl-legacy-provider

RUN npm run build

ENV NODE_OPTIONS=

FROM node:20-alpine

WORKDIR /app

RUN npm install -g serve

COPY --from=build /usr/src/app/build .

EXPOSE 3000

CMD ["serve", "-s", "."]