#!/usr/bin/env python3
"""Pipeline completo en un solo proceso: ingesta y transformación.

Hace lo mismo que encadenar `docker compose run --rm extract` y
`docker compose run --rm transform`, pero sin orquestador y sin repetir la
configuración de la conexión.

La pieza que lo permite es `dlt.dbt`, el ejecutor de proyectos dbt que trae
dlt. Recibe el *pipeline*, no una cadena de conexión, y de ahí deduce el perfil
de dbt: destino, credenciales y esquema salen de la misma configuración que
acaba de usar la carga. Con eso desaparece la posibilidad de que la ingesta
escriba en un sitio y la transformación lea de otro.

La dependencia entre las dos etapas tampoco hay que declararla en ningún grafo:
si `cargar()` lanza una excepción, la línea siguiente no se ejecuta.
"""

import os
import sys

import dlt

from odoo_extract import cargar, crear_pipeline

# Proyecto dbt
DBT_PROJECT_DIR = os.environ.get("DBT_PROJECT_DIR", "/app/dbt_project")


def transformar(pipeline: dlt.Pipeline) -> list:
    """Ejecuta el proyecto dbt contra el mismo destino que acaba de cargarse."""
    # Sin `venv`, dlt usa el entorno actual, donde la imagen ya trae dbt-duckdb
    # instalado y con la versión fijada. Si se le pasa `dlt.dbt.get_venv(...)`
    # se crea un entorno aparte y se instala dbt en caliente, lo que exige red
    # en cada ejecución.
    transformacion = dlt.dbt.package(pipeline, DBT_PROJECT_DIR)

    # Aquí hay una trampa que conviene conocer. Pese al nombre, `run_all` no
    # ejecuta "todo": hace `dbt deps`, `dbt seed` y `dbt run`, pero NO las
    # pruebas de los modelos. Es el equivalente a `dbt run`, no a `dbt build`.
    #
    # Quedarse solo con esta llamada dejaría el ejercicio sin sus cincuenta y
    # siete comprobaciones, que son las que detectan que un enlace ha quedado
    # colgando. Las pruebas hay que pedirlas aparte.
    modelos = transformacion.run_all()
    pruebas = transformacion.test()

    return list(modelos) + list(pruebas)


def main() -> None:
    pipeline = crear_pipeline()

    print("== Ingesta ==")
    cargar(pipeline)

    print("\n== Transformación ==")
    modelos = transformar(pipeline)

    fallidos = [m for m in modelos if m.status not in ("success", "pass")]

    for modelo in fallidos:
        print(f"  FALLO  {modelo.model_name}: {modelo.message}")

    print(f"\n{len(modelos)} nodos ejecutados, {len(fallidos)} con problemas.")

    # Si algo falla hay que salir con código distinto de cero. Sin esto, un
    # `docker compose run` que ha dejado el vault a medias termina con un cero
    # y quien lo haya lanzado desde un cron no se entera de nada.
    if fallidos:
        sys.exit(1)


if __name__ == "__main__":
    main()
