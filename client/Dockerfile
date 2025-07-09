FROM node:20-alpine AS build

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

RUN npm run build

FROM alpine:3.19

WORKDIR /app

RUN apk add --no-cache serve

COPY --from=build /usr/src/app/build .

EXPOSE 3000

CMD ["serve", "-s", "."]