FROM python:3.11-slim
# Caminho recomendo pela doc do docker para imagens linux/python
WORKDIR /usr/src/app

# Instalar dependências do Flask
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar arquivos e diretórios irmãos do Dockerfile
COPY . .

#Variaveis do finado start-backend.py
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