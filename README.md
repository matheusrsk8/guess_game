

# Jogo de Adivinhação com Flask

Este é um simples jogo de adivinhação desenvolvido utilizando o framework Flask. O jogador deve adivinhar uma senha criada aleatoriamente, e o sistema fornecerá feedback sobre o número de letras corretas e suas respectivas posições.

## Características do Container

- Reinício de Containers (1)
- Balanceamento de Carga no Proxy Reverso (2)
- Volumes Separados para o Banco de Dados (3)
- Facilidade de Atualização (4)

  
## Requisitos

- Docker

## Build

1. Clone o repositório:

   ```bash
   git clone https://github.com/matheusrsk8/guess_game.git #fork de fams/guess_game
   cd guess-game
   ```

2. Execute o container com compose

   ```bash
   docker compose up --build
   ```

## Acesse a aplicação

1. Abra o navegador

   ```bash
   localhost:3000
   ```

## Design

### ./Dockerfile (backend)

Utiliza uma imagem linux Python com a tag 3.11-slim, para garantir uma imagem mais leve. 
Aqui o COPY do requirements também foi criado visando otimizar futuros builds utilizando cache (se houver mudança apenas neste arquivo o build aconterá apartir dali) (característica 4)
    
```
FROM python:3.11-slim
# Caminho recomendo pela doc do docker para imagens linux/python
WORKDIR /usr/src/app

# Instalar dependências do Flask
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar arquivos e diretórios irmãos do Dockerfile
COPY . .

#Variaveis do finado 'start-backend.py'
ENV FLASK_APP run.py
ENV FLASK_DB_TYPE postgres
ENV FLASK_DB_USER postgres
ENV FLASK_DB_NAME postgres
ENV FLASK_DB_PASSWORD secretpass
ENV FLASK_DB_HOST db
ENV FLASK_DB_PORT 5432

#Expor porta do flask
EXPOSE 5000

#Inicar o container com esses comandos
ENTRYPOINT ["flask", "run",  "--host=0.0.0.0", "--port=5000"]
```

### ./frontend/Dockerfile (frontend)

Utilizando multi stages a primeira fase é responsável por executar o frontend do jogo de adivinhação, a segunda fase com ngnix é resposável por servir o frontend e uma tag slim é o suficiente para servir arquivos estáticos, o arquivo `default.conf` é copiado para a path conf.d do container. Os arquivos estáticos gerados na primeira fase é copiados para o container.
    
```
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
```

### ./frontend/default.conf (ngnix)

Este arquivo configura o proxy reverso e garante o balanceamento de carga com replicas do backend. (característica 2)

```
upstream backend {
  server backend:5000; 
}

server {
  listen 80;
  
  location / {
    root /usr/share/nginx/html;
    index index.html index.htm;
    try_files $uri $uri/ /index.html;
  }

  location /api {  
    proxy_pass http://backend/;
    proxy_http_version 1.1;  
    proxy_set_header Upgrade $http_upgrade; 
    proxy_set_header Connection "upgrade";  
    proxy_set_header Host $host; 
    proxy_set_header X-Real-IP $remote_addr;  
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  
    proxy_set_header X-Forwarded-Proto $scheme;  
  }
}
```

### ./docker-compose.yml

Neste compose temos:
 
3 serviços

- db: container banco de dados postgres, com volume para persistência dos dados (característica 3) e retry e restart (característica 1)
- backend: container backend com restart (característica 3) e replica para balanceamento de carga (característica 2)
- frontend: container frontend com restart  (característica 3).

1 volume

- db_data: para persistir os dados

2 networks 

- network-backend: rede bridge para atender o backend e fazer comunicação entre containers
- network-frontend: rede bridge para atender o frontend e fazer comunicação entre containers

```yml
version: '3.9'
 
services:
  db:
    image: postgres
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d postgres"]
      interval: 5s
      retries: 5
      start_period: 20s
    expose:
      - 5432
    environment:
      - POSTGRES_PASSWORD=secretpass
    networks:
      - network-backend
    volumes:
      - db_data:/var/lib/postgresql/data
 
  backend:
    build: .
    deploy:
      replicas: 3
    restart: always
    environment:
      - FLASK_DB_HOST db
    expose:
      - 5000
    networks:
      - network-backend
      - network-frontend
    depends_on:
      db:
        condition: service_healthy
 
  frontend:
    build:
      context: frontend
    restart: always
    ports:
      - 3000:80
    networks:
      - network-frontend
      - network-backend
 
networks:
  network-backend:
  network-frontend:
 
volumes:
  db_data:
```