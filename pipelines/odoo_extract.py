#!/usr/bin/env python3
"""Ingesta de Odoo a DuckDB (capa bronce).

Lee directamente de la base de datos de Odoo, no de su API, que es lo que
conviene cuando se tiene acceso al servidor: es más rápido y no obliga a
paginar. Cada tabla se deja en el esquema `raw` de DuckDB con el nombre con el
que la conoce el almacén, sin más transformación que el renombrado.

Las columnas van declaradas una a una a propósito. El esquema físico de Odoo no
coincide con el que muestra su interfaz, así que la lista de abajo es el
resultado de mirar `information_schema`, no de suponer.
"""

import os
from datetime import datetime, timezone

import dlt
from dlt.sources.sql_database import sql_table

ODOO_DB_HOST = os.environ.get("ODOO_DB_HOST", "localhost")
ODOO_DB_PORT = os.environ.get("ODOO_DB_PORT", "5432")
ODOO_DB_NAME = os.environ.get("ODOO_DB_NAME", "odoo_demo")
ODOO_DB_USER = os.environ.get("ODOO_DB_USER", "odoo")
ODOO_DB_PASSWORD = os.environ.get("ODOO_DB_PASSWORD", "odoo")
DUCKDB_PATH = os.environ.get("DUCKDB_PATH", "warehouse/warehouse.duckdb")

RECORD_SOURCE = "odoo_erp"

# Tabla de origen -> tabla de destino y columnas que nos llevamos.
#
# Dos avisos que cuestan una tarde si se descubren tarde:
#
#   * `product_product` no tiene ni nombre ni precio. En Odoo son campos de la
#     plantilla (`product_template`), y `standard_price` ni siquiera es una
#     columna: vive en `ir_property` porque depende de la compañía.
#   * `product_template.name` es `jsonb`, porque desde Odoo 16 los campos
#     traducibles se guardan como un diccionario de idiomas.
ODOO_TABLES = {
    "res_partner": {
        "destino": "raw_customers",
        "columnas": [
            "id", "name", "is_company", "customer_rank", "supplier_rank",
            "email", "phone", "street", "city", "zip", "country_id",
            "state_id", "type", "active", "create_date", "write_date",
        ],
    },
    "sale_order": {
        "destino": "raw_orders",
        "columnas": [
            "id", "name", "partner_id", "state", "date_order",
            "amount_total", "amount_tax", "amount_untaxed",
            "create_date", "write_date",
        ],
    },
    "sale_order_line": {
        "destino": "raw_order_lines",
        "columnas": [
            "id", "order_id", "product_id", "name", "product_uom_qty",
            "qty_delivered", "qty_invoiced", "price_unit", "price_subtotal",
            "price_total", "discount", "state", "create_date", "write_date",
        ],
    },
    "product_product": {
        "destino": "raw_products",
        "columnas": [
            "id", "product_tmpl_id", "default_code", "barcode",
            "weight", "volume", "active", "create_date", "write_date",
        ],
    },
    "product_template": {
        "destino": "raw_product_templates",
        "columnas": [
            "id", "name", "type", "categ_id", "list_price", "weight",
            "volume", "default_code", "active", "create_date", "write_date",
        ],
    },
}


def marcar_procedencia(fila: dict) -> dict:
    """Añade las columnas de trazabilidad de la capa bronce.

    dlt ya deja `_dlt_load_id`, que permite reconstruir qué carga trajo cada
    fila. Estas dos son para que el dato se explique solo al mirarlo.
    """
    fila["_source"] = RECORD_SOURCE
    fila["_extracted_at"] = datetime.now(timezone.utc)
    return fila


def construir_recursos(cadena_conexion: str) -> list:
    recursos = []
    for origen, config in ODOO_TABLES.items():
        recurso = sql_table(
            credentials=cadena_conexion,
            table=origen,
            schema="public",
            included_columns=config["columnas"],
        ).with_name(config["destino"])
        recurso.apply_hints(primary_key="id")
        recurso.add_map(marcar_procedencia)
        recursos.append(recurso)
    return recursos


def cadena_conexion() -> str:
    return (
        f"postgresql://{ODOO_DB_USER}:{ODOO_DB_PASSWORD}"
        f"@{ODOO_DB_HOST}:{ODOO_DB_PORT}/{ODOO_DB_NAME}"
    )


def crear_pipeline() -> dlt.Pipeline:
    return dlt.pipeline(
        pipeline_name="odoo_to_duckdb",
        destination=dlt.destinations.duckdb(DUCKDB_PATH),
        # El nombre del dataset es el esquema que verá dbt en sus `source()`.
        dataset_name="raw",
    )


def cargar(pipeline: dlt.Pipeline) -> None:
    """Ejecuta la ingesta y deja constancia de lo cargado."""
    # `replace` deja la capa bronce como un reflejo del origen. Para pasar a
    # incremental bastaría con declarar `write_date` como marca de agua, tal y
    # como se ve en el capítulo de herramientas de ingesta.
    info = pipeline.run(construir_recursos(cadena_conexion()), write_disposition="replace")

    print(info)
    print("\nFilas cargadas por tabla:")
    with pipeline.sql_client() as cliente:
        for config in ODOO_TABLES.values():
            tabla = config["destino"]
            filas = cliente.execute_sql(f"SELECT count(*) FROM {tabla}")[0][0]
            print(f"  raw.{tabla}: {filas}")


def main() -> None:
    cargar(crear_pipeline())


if __name__ == "__main__":
    main()
