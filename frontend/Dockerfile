FROM node:23-slim AS build

WORKDIR /app

COPY package*.json .

RUN npm ci

COPY . .

ENV REACT_APP_BACKEND_URL api

RUN npm run build

FROM nginx:1.27.3

COPY default.conf /etc/nginx/conf.d/default.conf

WORKDIR /usr/share/nginx/html

RUN rm -rf ./*

COPY --from=build /app/build .

EXPOSE 80

ENTRYPOINT ["nginx", "-g", "daemon off;"]