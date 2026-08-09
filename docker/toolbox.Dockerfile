# Imagen de utilidades del ejercicio: dlt para la ingesta, dbt para la
# transformación y nao-core para construir el contexto del agente. Se construye
# una sola vez y la comparten los servicios, de forma que ejecutar el pipeline
# no dependa de que haya red disponible.
FROM python:3.11-slim

# psycopg2-binary y duckdb llegan como rueda precompilada, así que no hace
# falta cadena de compilación.
# Las versiones van fijadas y dbt-core se declara explícitamente. Sin esa
# segunda línea, pip resuelve el core más nuevo que exista y lo empareja con un
# adaptador viejo; esa combinación arranca, avisa de que el plugin está
# desactualizado y luego se cae de forma intermitente a mitad de ejecución.
#
# `nao-core` va aquí y no en una imagen aparte porque comprobadamente no toca
# ninguna de las versiones de arriba: instala treinta y cinco paquetes suyos y
# deja dbt, duckdb y dlt donde estaban. Merece la pena verificarlo al subir de
# versión, y la orden es esta:
#
#   docker run --rm --entrypoint pip datalake-toolbox \
#     install --dry-run --report - nao-core
#
# Su versión tiene que ir emparejada con la del contenedor del chat, igual que
# dbt con su adaptador.
#
# El extra `parquet` de dlt está aquí por nao, no por la ingesta: `nao sync`
# lee los resultados del almacén con pyarrow y sin él falla a mitad de sync con
# un "No module named 'pyarrow'" después de haber sincronizado ya el
# repositorio. Se pide por el extra de dlt en lugar de suelto para que la
# versión la resuelva quien ya depende de ella.
#
# `pyarrow-hotfix` es el acompañante que nadie espera tener que declarar. La
# versión de duckdb que usa este proyecto lo importa siempre que convierte un
# resultado a Arrow, aunque el parche solo hiciera falta para pyarrow anterior
# al 14 y aquí haya un 17. Sin él, `nao sync` conecta, encuentra las tablas y
# falla en todas con "No module named 'pyarrow_hotfix'", dejando un contexto
# vacío y un resumen que dice "7 tables synced" en verde.
RUN pip install --no-cache-dir \
      "dlt[duckdb,postgres,parquet]==1.6.1" \
      "sqlalchemy==2.0.36" \
      "dbt-core==1.9.4" \
      "dbt-duckdb==1.9.1" \
      "duckdb==1.1.3" \
      "pyarrow-hotfix==0.7" \
      "nao-core==0.3.3"

# dlt escribe su estado en ~/.dlt y dbt en ~/.dbt. Los contenedores corren con
# el uid del anfitrión (ver docker-compose.yml) para que los ficheros que
# aparezcan en warehouse/ no queden en manos de root.
ENV HOME=/tmp \
    DBT_PROFILES_DIR=/app/dbt_project

WORKDIR /app
