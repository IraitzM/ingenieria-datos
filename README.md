# Ingeniería de datos

Repositorio de ingeniería de datos en Español. Contiene dos cosas distintas que se pueden usar por separado:

| Componente | Qué es | Por dónde empezar |
|---|---|---|
| **El libro** | Un libro en Quarto sobre ingeniería de datos, con ejemplos ejecutables capítulo a capítulo | [`index.qmd`](index.qmd) o el [sitio publicado](https://iraitzm.github.io/ingenieria-datos/) |
| **El ejercicio de proyecto** | Un lago de datos completo que se levanta con Docker (Odoo, dlt, DuckDB, dbt y Rill) | [`content/appendices/datalake.qmd`](content/appendices/datalake.qmd) |

El libro usa como hilo conductor una secretaría académica inventada, pensada para que cada capítulo pueda enseñar una cosa sin que estorben las demás. El ejercicio propone lo contrario: partir de un sistema real y llegar hasta el panel. No comparten datos ni puertos, así que se pueden tener los dos a la vez en la misma máquina.

## El libro

El contenido vive en [`content/`](content/) y el índice de capítulos está en [`_quarto.yml`](_quarto.yml). Cinco partes y cinco apéndices:

| Parte | Directorio | De qué va |
|---|---|---|
| Modelado de datos | [`content/modelado/`](content/modelado/) | Formas normales, desnormalización, modelado analítico |
| Sistemas gestores de datos | [`content/sistemas/`](content/sistemas/) | RDBMS transaccional, SQL, bases analíticas, arquitecturas, formatos abiertos |
| Ingesta de datos | [`content/load/`](content/load/) | Patrones de carga, herramientas, capa de staging |
| Transformación de datos | [`content/transform/`](content/transform/) | Data warehousing, raw vault, business vault |
| Explotación | [`content/explotacion/`](content/explotacion/) | Capa semántica, BI, ciencia de datos, MLOps |
| Apéndices | [`content/appendices/`](content/appendices/) | Metadatado, calidad, Rill, el ejercicio del lago de datos |

### Renderizarlo en local

```bash
uv sync
QUARTO_PYTHON=$PWD/.venv/bin/python quarto preview
```

La variable `QUARTO_PYTHON` no es opcional si hay pyenv por medio: sin ella Quarto coge otro intérprete y los bloques de código fallan. El resultado se deja en `_book/` (que no se versiona).

Varios capítulos levantan servicios propios con Docker mientras se ejecutan (Evidence en el 3000, OpenMetadata en el 8585, Rill en el 9009). Están documentados en el capítulo correspondiente.

### Publicación

[`.github/workflows/publish.yml`](.github/workflows/publish.yml) renderiza y publica en la rama `gh-pages` con cada `push` a `main`. Ojo con las dependencias: **el CI instala desde `requirements.txt`**, no desde `pyproject.toml`. Al añadir un paquete hay que actualizar los dos ficheros:

```bash
uv add <paquete>
uv export --no-hashes -o requirements.txt
```

## El ejercicio de proyecto

Un lago de datos de principio a fin, con [Odoo](https://www.odoo.com/) (un ERP de código abierto con datos de demostración) como origen. La gracia está en que su base de datos no está diseñada para que la analicemos. Todo el recorrido, con sus decisiones de diseño y sus ejercicios, está contado en [`content/appendices/datalake.qmd`](content/appendices/datalake.qmd).

```
Odoo/PostgreSQL --> dlt --> DuckDB (raw) --> dbt --> vault --> dbt --> oro --> Rill
                                                       `--> dbt docs (linaje)
```

| Pieza | Papel | Dónde queda |
|---|---|---|
| Odoo 16 y PostgreSQL 15 | Sistema origen con datos de demostración | `http://localhost:8069` (admin/admin) |
| dlt | Ingesta de Odoo al almacén | [`pipelines/`](pipelines/) |
| DuckDB | El almacén, las cuatro capas | `warehouse/warehouse.duckdb` |
| dbt | Data Vault y capa de explotación | [`dbt_project/`](dbt_project/) |
| dbt docs | Diccionario de modelos y grafo de linaje | `http://localhost:8081` |
| Rill | Panel de exploración | [`rill_project/`](rill_project/), en `http://localhost:9010` |

Todo se orquesta desde [`docker-compose.yml`](docker-compose.yml). Hacen falta Docker con el complemento `compose`, unos 4 GiB de memoria libre y unos 3 GiB de disco.

```bash
docker compose up -d                          # levanta Odoo con sus datos
docker compose run --rm extract               # carga la capa bronce en DuckDB
docker compose run --rm transform             # construye el vault y la capa oro
docker compose --profile bi up -d rill        # abre el panel en el 9010
```

Los dos pasos centrales pueden lanzarse de una vez con `docker compose run --rm pipeline`. Para publicar el linaje: `docker compose run --rm transform dbt docs generate` y después `docker compose --profile docs up -d docs`.

Dos cosas que conviene saber antes de empezar:

* **DuckDB solo admite un escritor.** Con Rill levantado, cualquier orden que escriba (`extract`, `transform` o `pipeline`) falla con un `Conflicting lock is held in PID 0`. Hay que parar el panel antes de recargar (`docker compose stop rill`). Por eso Rill vive tras un perfil de Compose y no arranca con el `up -d` general.
* **Los puertos están corridos a propósito** (PostgreSQL en el 5433, dbt docs en el 8081, Rill en el 9010) para no chocar con los servicios que levantan los capítulos del libro.

Para desmontarlo todo, incluidos los volúmenes:

```bash
docker compose --profile bi --profile docs --profile jobs down -v
rm -rf warehouse/warehouse.duckdb
```

## Estructura del repositorio

```
content/          Capítulos y apéndices del libro (.qmd)
assets/           Imágenes del libro
_quarto.yml       Índice de capítulos y configuración del sitio
index.qmd         Prólogo

docker-compose.yml  Ejercicio del lago de datos
docker/             Imagen de utilidades (dlt + dbt) del ejercicio
pipelines/          Ingesta de Odoo con dlt
dbt_project/        Staging, Data Vault y capa de explotación
rill_project/       Panel sobre la capa oro
warehouse/          Fichero DuckDB generado (no se versiona)

pyproject.toml    Dependencias del libro (gestionadas con uv)
requirements.txt  Las mismas, exportadas para el CI
```

## Licencia

El repositorio tiene dos licencias, una para cada tipo de material:

| Qué | Licencia | Fichero |
|---|---|---|
| El texto del libro, sus imágenes y sus diagramas (`content/`, `assets/`, `index.qmd`) | [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) | [`LICENSE`](LICENSE) |
| El código del ejercicio y de los ejemplos (`pipelines/`, `dbt_project/`, `rill_project/`, `docker/`, `docker-compose.yml`, `*.py`, `*.sql`, `*.yml`) | [MIT](https://opensource.org/licenses/MIT) | [`LICENSE-CODE`](LICENSE-CODE) |

En corto: el texto se puede compartir y adaptar citando la fuente, sin uso comercial y manteniendo la misma licencia. El código se puede llevar a donde haga falta, incluido el trabajo, conservando el aviso de copyright.

Copyright 2025, Iraitz Montalbán.
