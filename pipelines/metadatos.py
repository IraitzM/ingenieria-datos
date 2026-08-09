#!/usr/bin/env python3
"""Consolidación de metadatos de calidad en el propio almacén.

Este paso no comprueba nada. Recoge lo que ya comprobaron otros y lo deja donde
se pueda consultar, que es el hueco que ninguna de las tres herramientas cubre
por su cuenta:

  * dbt sabe si sus pruebas pasaron, y lo deja en `run_results.json`.
  * dbt sabe cuándo se cargó cada fuente, y lo deja en `sources.json`.
  * Soda sabe si el dato se parece a lo que esperábamos, y lo deja en su
    propio JSON.

Tres ficheros, tres formatos y ninguno consultable con SQL. Y sobre todo: **el
sitio de documentación de dbt no enseña ninguno de los tres**. Su `index.html`
solo carga `manifest.json` y `catalog.json`, de modo que allí se ve que existe
una prueba y que se declaró una frescura, nunca si están en verde. Es un
catálogo de definiciones, no de estado.

Por eso el estado acaba aquí, en un esquema `meta` dentro del mismo DuckDB.
Quien quiera saber si puede fiarse de una tabla lanza una consulta, no abre una
interfaz ni busca un correo.

La columna `escaneado_en` está en todas las tablas y no es decorativa: sin ella
no se distingue "esto está bien" de "esto estaba bien hace tres semanas y nadie
ha vuelto a mirar", que es una diferencia que importa bastante.
"""

import json
import os
from datetime import datetime, timezone

import duckdb

DUCKDB_PATH = os.environ.get("DUCKDB_PATH", "warehouse/warehouse.duckdb")
DBT_TARGET_DIR = os.environ.get("DBT_TARGET_DIR", "dbt_project/target")
SODA_RESULTS = os.environ.get("SODA_RESULTS", "warehouse/soda_results.json")

# Capa que se vigila. Es la que consumen el panel y el agente, así que es donde
# un problema deja de ser interno y pasa a llegarle a alguien.
CAPA_VIGILADA = "main"


def leer_json(ruta: str) -> dict | None:
    """Devuelve el artefacto, o None si no está.

    Que falte un fichero es una situación normal y no un error: alguien puede
    ejecutar la consolidación sin haber pasado Soda todavía. Lo que no sería
    normal es fingir que sí se ejecutó, así que cada tabla registra su propia
    procedencia y el resumen dice qué faltó.
    """
    if not os.path.exists(ruta):
        return None
    with open(ruta, encoding="utf-8") as f:
        return json.load(f)


def inventario(manifest: dict) -> list[dict]:
    """Los activos del almacén: los modelos y también las fuentes.

    Incluir las fuentes no es un adorno. Son los únicos activos que tienen
    frescura, y son la primera línea del almacén: si `raw_orders` deja de
    llegar, todo lo que hay debajo sigue en verde durante días porque el
    problema no está en las transformaciones.
    """
    filas = []
    for nodo in manifest["nodes"].values():
        if nodo["resource_type"] != "model":
            continue
        filas.append(
            {
                "activo": nodo["name"],
                "capa": nodo["fqn"][1],
                "esquema": nodo["schema"],
                "materializacion": nodo["config"]["materialized"],
                # Esta es la descripción que se escribió una vez en los YAML y
                # que ya alimentaba dbt docs, los comentarios de DuckDB y el
                # contexto del agente. Aquí es el cuarto consumidor.
                "descripcion": (nodo.get("description") or "").strip(),
            }
        )

    for fuente in manifest.get("sources", {}).values():
        filas.append(
            {
                "activo": fuente["name"],
                "capa": "fuente",
                "esquema": fuente["schema"],
                "materializacion": "fuente",
                "descripcion": (fuente.get("description") or "").strip(),
            }
        )
    return filas


def activo_de_la_prueba(nodo: dict) -> str:
    """A qué activo vigila una prueba.

    Tiene más miga de la que parece. `attached_node` solo lo rellenan las
    pruebas declaradas sobre un modelo; las declaradas sobre una **fuente** lo
    dejan vacío, y en este proyecto son veinte de las ciento setenta y nueve.
    Sin resolverlas, esas veinte quedan colgando de un activo que no existe y
    las fuentes aparecen como si nadie las comprobara.

    Las pruebas singulares de `tests/` son otro caso y no tienen arreglo por
    esta vía: `satelite_grano_unico` comprueba cuatro satélites a la vez, así
    que atribuirla a uno sería mentir y repetirla en los cuatro contaría de más.
    Se quedan como "(varios)" y se cuentan aparte.
    """
    adjunto = nodo.get("attached_node")
    if adjunto:
        return adjunto.split(".")[-1]

    dependencias = (nodo.get("depends_on") or {}).get("nodes") or []
    fuentes = [d for d in dependencias if d.startswith("source.")]
    if len(fuentes) == 1:
        return fuentes[0].split(".")[-1]
    if len(dependencias) == 1:
        return dependencias[0].split(".")[-1]
    return "(varios)"


def frescura(sources: dict) -> list[dict]:
    """Resultado de `dbt source freshness`, una fila por fuente.

    Mide una cosa muy concreta: cuánto hace que la tabla de origen no recibe
    datos nuevos, comparando el `loaded_at_field` con el momento del escaneo.
    No dice si el dato es correcto, dice si sigue llegando, y es de las
    comprobaciones que más incidentes reales detecta.
    """
    filas = []
    for r in sources["results"]:
        # "source.data_vault_odoo.raw.raw_orders" -> ("raw", "raw_orders")
        partes = r["unique_id"].split(".")
        criterio = r.get("criteria") or {}
        aviso = (criterio.get("warn_after") or {}).get("count")
        error = (criterio.get("error_after") or {}).get("count")
        filas.append(
            {
                "fuente": partes[-2],
                "tabla": partes[-1],
                "estado": r["status"],
                "ultima_carga": momento(r.get("max_loaded_at")),
                "medido_en": momento(r.get("snapshotted_at")),
                "antiguedad_horas": round((r.get("max_loaded_at_time_ago_in_s") or 0) / 3600, 3),
                "avisa_tras_horas": aviso,
                "falla_tras_horas": error,
            }
        )
    return filas


def controles_dbt(manifest: dict, run_results: dict) -> list[dict]:
    """Las pruebas de dbt, normalizadas al formato común."""
    filas = []
    for resultado in run_results["results"]:
        if not resultado["unique_id"].startswith("test."):
            continue
        nodo = manifest["nodes"].get(resultado["unique_id"], {})
        filas.append(
            {
                "herramienta": "dbt",
                "activo": activo_de_la_prueba(nodo),
                "columna": nodo.get("column_name") or "",
                "control": (nodo.get("test_metadata") or {}).get("name", "propio"),
                "nombre": nodo.get("name", ""),
                "estado": resultado["status"],
                # dbt cuenta filas incumplidoras; Soda da el valor de la
                # métrica. No son lo mismo y por eso la columna se llama
                # `valor` y no `fallos`.
                "valor": float(resultado.get("failures") or 0),
                # Un invariante corta la carga. Es la diferencia de fondo con
                # lo que vigila Soda, y conviene que se vea en la tabla.
                "corta_la_carga": resultado["status"] == "fail",
            }
        )
    return filas


def controles_soda(soda: dict) -> list[dict]:
    """Los controles de Soda, normalizados al mismo formato."""
    filas = []
    for check in soda.get("checks", []):
        diag = check.get("diagnostics") or {}
        valor = diag.get("value")
        filas.append(
            {
                "herramienta": "soda",
                "activo": check.get("table") or "",
                "columna": check.get("column") or "",
                "control": check.get("type") or "",
                "nombre": check.get("name") or check.get("definition", "").strip()[:80],
                "estado": check.get("outcome") or "",
                "valor": float(valor) if isinstance(valor, (int, float)) else 0.0,
                # Aquí está la diferencia que da sentido a tener las dos
                # herramientas: un aviso de Soda no para nada.
                "corta_la_carga": check.get("outcome") == "fail",
            }
        )
    return filas


def perfil(con: duckdb.DuckDBPyConnection) -> list[dict]:
    """Foto del volumen de cada tabla publicada.

    Es lo que Soda no puede comparar por sí solo: su núcleo no guarda historia,
    así que un control del tipo "el volumen ha cambiado más de un 25 %" necesita
    Soda Cloud. Guardando esta foto en cada ejecución, la serie queda en el
    almacén y esa comparación se puede escribir en SQL corriente.
    """
    # Las vistas `calidad_*` se quedan fuera. Son el puente que se publica en
    # `main` para que Rill pueda leer los metadatos, no activos de negocio, y
    # perfilarlas sería medir el termómetro en lugar de la temperatura. Sin este
    # filtro el perfil crece de siete a diez filas en la segunda ejecución, que
    # es justo cuando el histórico deja de poder compararse consigo mismo.
    tablas = [
        f[0]
        for f in con.execute(
            "SELECT table_name FROM information_schema.tables "
            "WHERE table_schema = ? AND table_name NOT LIKE 'calidad\\_%' ESCAPE '\\' "
            "ORDER BY 1",
            [CAPA_VIGILADA],
        ).fetchall()
    ]
    filas = []
    for tabla in tablas:
        n = con.execute(f'SELECT count(*) FROM {CAPA_VIGILADA}."{tabla}"').fetchone()[0]
        filas.append({"activo": tabla, "filas": n})
    return filas


# El esquema de cada tabla, escrito a mano.
#
# Dejar que DuckDB lo dedujera del JSON sería más corto y traería el problema de
# siempre: el tipo de una columna acabaría dependiendo de los datos que trajo la
# última ejecución. Si un día ninguna prueba falla, `valor` se deduce entero; al
# siguiente, con un porcentaje, se deduce decimal, y el panel que leía esa
# columna se rompe sin que nadie haya tocado nada.
TABLAS = {
    "activos": [
        ("activo", "VARCHAR"),
        ("capa", "VARCHAR"),
        ("esquema", "VARCHAR"),
        ("materializacion", "VARCHAR"),
        ("descripcion", "VARCHAR"),
    ],
    "controles": [
        ("herramienta", "VARCHAR"),
        ("activo", "VARCHAR"),
        ("columna", "VARCHAR"),
        ("control", "VARCHAR"),
        ("nombre", "VARCHAR"),
        ("estado", "VARCHAR"),
        ("valor", "DOUBLE"),
        ("corta_la_carga", "BOOLEAN"),
    ],
    "frescura": [
        ("fuente", "VARCHAR"),
        ("tabla", "VARCHAR"),
        ("estado", "VARCHAR"),
        ("ultima_carga", "TIMESTAMPTZ"),
        ("medido_en", "TIMESTAMPTZ"),
        ("antiguedad_horas", "DOUBLE"),
        ("avisa_tras_horas", "BIGINT"),
        ("falla_tras_horas", "BIGINT"),
    ],
    "perfil": [
        ("activo", "VARCHAR"),
        ("filas", "BIGINT"),
    ],
}


def escribir(con: duckdb.DuckDBPyConnection, tabla: str, filas: list[dict], sello: datetime) -> int:
    """Crea o reemplaza una tabla de `meta` con el esquema declarado arriba.

    `CREATE OR REPLACE` y no `INSERT`: estas tablas son la foto de la última
    ejecución. La serie histórica se acumula aparte, en `meta.perfil_historico`,
    porque hacer crecer sin límite algo que se consulta constantemente es la
    forma más fácil de que el panel se vuelva lento.
    """
    columnas = TABLAS[tabla]
    ddl = ", ".join(f'"{nombre}" {tipo}' for nombre, tipo in columnas)
    con.execute(f"CREATE OR REPLACE TABLE meta.{tabla} ({ddl}, escaneado_en TIMESTAMPTZ)")

    if not filas:
        return 0

    marcadores = ", ".join("?" * (len(columnas) + 1))
    con.executemany(
        f"INSERT INTO meta.{tabla} VALUES ({marcadores})",
        [[fila.get(nombre) for nombre, _ in columnas] + [sello] for fila in filas],
    )
    return len(filas)


def momento(valor: str | None) -> datetime | None:
    """Convierte la marca ISO de los artefactos en un instante de verdad.

    dbt las escribe como texto ISO 8601 con zona. Insertarlas tal cual dejaría
    columnas de texto con las que no se puede restar, y calcular la antigüedad
    de un dato es precisamente lo que se va a querer hacer con ellas.
    """
    if not valor:
        return None
    return datetime.fromisoformat(valor)


def main() -> None:
    manifest = leer_json(os.path.join(DBT_TARGET_DIR, "manifest.json"))
    run_results = leer_json(os.path.join(DBT_TARGET_DIR, "run_results.json"))
    sources = leer_json(os.path.join(DBT_TARGET_DIR, "sources.json"))
    soda = leer_json(SODA_RESULTS)

    if manifest is None:
        raise SystemExit(
            f"No hay manifest.json en {DBT_TARGET_DIR}. "
            "Hay que ejecutar 'dbt build' antes que esto."
        )

    sello = datetime.now(timezone.utc)
    con = duckdb.connect(DUCKDB_PATH)
    con.execute("CREATE SCHEMA IF NOT EXISTS meta")

    n_activos = escribir(con, "activos", inventario(manifest), sello)

    controles = controles_dbt(manifest, run_results) if run_results else []
    if soda:
        controles += controles_soda(soda)
    n_controles = escribir(con, "controles", controles, sello)

    n_frescura = escribir(con, "frescura", frescura(sources), sello) if sources else 0
    n_perfil = escribir(con, "perfil", perfil(con), sello)

    # La serie histórica del perfil, que es lo que permite responder a "¿esto
    # ha cambiado mucho desde ayer?". Se acumula en lugar de reemplazarse.
    con.execute(
        "CREATE TABLE IF NOT EXISTS meta.perfil_historico "
        "AS SELECT * FROM meta.perfil WHERE false"
    )
    con.execute("INSERT INTO meta.perfil_historico SELECT * FROM meta.perfil")

    # El veredicto por activo, como vista y no como tabla: se calcula de lo
    # anterior y no tiene sentido que envejezca por su cuenta.
    #
    # La categoría que importa es la tercera. Una tabla que no falla ningún
    # control porque no tiene ninguno no es una tabla sana, es una tabla de la
    # que no sabemos nada, y las dos cosas no pueden parecerse en el informe.
    con.execute(
        """
        CREATE OR REPLACE VIEW meta.veredicto AS
        SELECT
            a.activo,
            a.capa,
            a.materializacion,
            count(c.nombre)                                   AS controles,
            count(c.nombre) FILTER (c.herramienta = 'dbt')    AS controles_dbt,
            count(c.nombre) FILTER (c.herramienta = 'soda')   AS controles_soda,
            count(c.nombre) FILTER (c.estado = 'fail')        AS fallos,
            count(c.nombre) FILTER (c.estado = 'warn')        AS avisos,
            CASE
                WHEN count(c.nombre) = 0 THEN 'sin vigilancia'
                WHEN count(c.nombre) FILTER (c.estado = 'fail') > 0 THEN 'con fallos'
                WHEN count(c.nombre) FILTER (c.estado = 'warn') > 0 THEN 'con avisos'
                ELSE 'apto'
            END                                               AS veredicto,
            max(a.escaneado_en)                               AS escaneado_en
        FROM meta.activos a
        LEFT JOIN meta.controles c ON c.activo = a.activo
        GROUP BY a.activo, a.capa, a.materializacion
        """
    )

    # Puente hacia el panel.
    #
    # Rill solo sabe direccionar tablas del esquema por defecto de la base de
    # datos que adjunta, que es la misma limitación que obligó a materializar
    # la capa oro en `main`. Las tablas de metadatos se quedan en `meta`, que es
    # su sitio, y lo que se publica en `main` son tres vistas.
    #
    # La de controles se enriquece con la capa del activo, porque "¿qué está
    # sin vigilar?" casi siempre se pregunta por capas y esa columna no está en
    # los artefactos de ninguna de las dos herramientas.
    con.execute(
        """
        CREATE OR REPLACE VIEW main.calidad_controles AS
        SELECT c.*, coalesce(a.capa, '(varios activos)') AS capa
        FROM meta.controles c
        LEFT JOIN meta.activos a ON a.activo = c.activo
        """
    )
    con.execute("CREATE OR REPLACE VIEW main.calidad_activos AS SELECT * FROM meta.veredicto")
    con.execute("CREATE OR REPLACE VIEW main.calidad_frescura AS SELECT * FROM meta.frescura")

    print("Metadatos consolidados en el esquema `meta`:")
    print(f"  meta.activos:    {n_activos}")
    print(f"  meta.controles:  {n_controles}")
    print(f"  meta.frescura:   {n_frescura}" + ("" if sources else "  (sin dbt source freshness)"))
    print(f"  meta.perfil:     {n_perfil}")
    sueltos = con.execute(
        "SELECT count(*) FROM meta.controles WHERE activo = '(varios)'"
    ).fetchone()[0]
    if sueltos:
        print(f"\n  {sueltos} controles vigilan más de un activo a la vez")
        print("  (las pruebas singulares de tests/) y no entran en el veredicto por activo.")

    if soda is None:
        print(f"\n  AVISO: no se encontró {SODA_RESULTS}.")
        print("  El veredicto se ha calculado solo con las pruebas de dbt, que")
        print("  no vigilan proporciones ni frescura del dato de negocio.")

    print("\nVeredicto de la capa publicada:")
    for estado, cuantos in con.execute(
        "SELECT veredicto, count(*) FROM meta.veredicto "
        "WHERE capa = 'analytics' GROUP BY 1 ORDER BY 1"
    ).fetchall():
        print(f"  {estado}: {cuantos}")

    con.close()


if __name__ == "__main__":
    main()
