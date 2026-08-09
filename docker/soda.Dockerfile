# Imagen de Soda, la vigilancia de calidad.
#
# Tiene imagen propia y no comparte la de utilidades, y el motivo es exactamente
# el que este ejercicio avisa de vigilar con dbt y su adaptador:
# `soda-core-duckdb` declara `duckdb<1.1.0`, de modo que instalarlo junto a dbt
# **degradaría duckdb de 1.1.3 a 1.0.0** sin decir nada. El motor que escribe el
# almacén no puede cambiar de versión porque hayamos añadido una herramienta de
# comprobación.
#
# Separarlas cuesta una imagen más y una capa de red menos que la alternativa,
# que es descubrir a los tres meses que el almacén se escribe con un duckdb
# distinto del que se pensaba.
#
# Que puedan convivir con versiones distintas no es casualidad ni suerte: el
# formato de almacenamiento de DuckDB es estable dentro de la serie 1.x, así
# que un fichero escrito por 1.1.3 se lee sin problema desde 1.0.0. Conviene
# comprobarlo al subir cualquiera de las dos:
#
#   docker run --rm -v ./warehouse:/data datalake-soda \
#     python -c "import duckdb; duckdb.connect('/data/warehouse.duckdb', read_only=True)"
FROM python:3.11-slim

# `pytz` no lo pide Soda sino el cliente de DuckDB, y solo cuando se toca una
# columna `TIMESTAMP WITH TIME ZONE`. Aquí pasa en el primer control de
# frescura, y el error que da no menciona ni la zona horaria ni la columna: se
# ve un "cannot rollback - no transaction is active" con la traza de Soda por
# encima y el motivo real ("Required module 'pytz' failed to import") tres
# líneas más abajo.
RUN pip install --no-cache-dir \
      "soda-core-duckdb==3.5.6" \
      "pytz==2025.2"

# Soda escribe su estado y sus ficheros temporales en el directorio del usuario.
ENV HOME=/tmp

WORKDIR /project
