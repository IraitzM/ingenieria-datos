# Imagen de utilidades del ejercicio: dlt para la ingesta y dbt para la
# transformación. Se construye una sola vez y la comparten los dos servicios,
# de forma que ejecutar el pipeline no dependa de que haya red disponible.
FROM python:3.11-slim

# psycopg2-binary y duckdb llegan como rueda precompilada, así que no hace
# falta cadena de compilación.
# Las versiones van fijadas y dbt-core se declara explícitamente. Sin esa
# segunda línea, pip resuelve el core más nuevo que exista y lo empareja con un
# adaptador viejo; esa combinación arranca, avisa de que el plugin está
# desactualizado y luego se cae de forma intermitente a mitad de ejecución.
RUN pip install --no-cache-dir \
      "dlt[duckdb,postgres]==1.6.1" \
      "sqlalchemy==2.0.36" \
      "dbt-core==1.9.4" \
      "dbt-duckdb==1.9.1" \
      "duckdb==1.1.3"

# dlt escribe su estado en ~/.dlt y dbt en ~/.dbt. Los contenedores corren con
# el uid del anfitrión (ver docker-compose.yml) para que los ficheros que
# aparezcan en warehouse/ no queden en manos de root.
ENV HOME=/tmp \
    DBT_PROFILES_DIR=/app/dbt_project

WORKDIR /app
