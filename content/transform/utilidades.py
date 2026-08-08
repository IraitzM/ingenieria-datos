"""Reconstruye la capa de aterrizaje del ejemplo de la secretaría académica.

Los capítulos de transformación necesitan un staging del que partir. En lugar de
depender de que se haya renderizado antes la parte de ingesta, cada capítulo
regenera aquí el mismo lago que dejaba aquella, de forma que todos son
reproducibles por separado.

Ninguna función deja una conexión abierta: dbt se ejecuta en otro proceso y
dos procesos no pueden escribir a la vez sobre el mismo catálogo.
"""

import os
import shutil
import subprocess
import sys

import duckdb

RAIZ = os.path.dirname(os.path.abspath(__file__))
PROYECTO = os.path.join(RAIZ, "academia")

# Cada capítulo trabaja sobre su propio lago y su propio directorio de salida de
# dbt. Comparten el proyecto (los modelos son los mismos) pero no el estado, de
# forma que renderizar un capítulo no pueda alterar lo que ve otro.
ESPACIO = os.path.join(PROYECTO, "_ejecucion", "libro")
CATALOGO = os.path.join(ESPACIO, "catalogo.sqlite")
DATOS = os.path.join(ESPACIO, "lago")


def usar(nombre):
    """Aísla el estado de este capítulo bajo un nombre propio."""
    global ESPACIO, CATALOGO, DATOS
    ESPACIO = os.path.join(PROYECTO, "_ejecucion", nombre)
    CATALOGO = os.path.join(ESPACIO, "catalogo.sqlite")
    DATOS = os.path.join(ESPACIO, "lago")

# Primera carga: lo que la ingesta dejó en staging el 10 de enero
CARGA_1 = {
    "fecha": "2026-01-10 03:00:00",
    "alumnos": [
        (1, "Iraitz", "Montalbán", "iraitz@ejemplo.eus"),
        (2, "Javier", "Garcia", "javier@ejemplo.eus"),
        (3, "Miguel", "Fernandez", "miguel@ejemplo.eus"),
    ],
    "asignaturas": [(1, "Matemáticas"), (2, "Historia"), (3, "Biología")],
    "cursa": [(1, 2), (2, 3), (3, 3)],
}

# Segunda carga: Iraitz corrige su correo y María se matricula en Biología
CARGA_2 = {
    "fecha": "2026-01-12 03:00:00",
    "alumnos": [
        (1, "Iraitz", "Montalbán", "iraitz.montalban@ejemplo.eus"),
        (2, "Javier", "Garcia", "javier@ejemplo.eus"),
        (3, "Miguel", "Fernandez", "miguel@ejemplo.eus"),
        (4, "María", "Garcia", "maria@ejemplo.eus"),
    ],
    "asignaturas": [(1, "Matemáticas"), (2, "Historia"), (3, "Biología")],
    "cursa": [(1, 2), (2, 3), (3, 3), (4, 3)],
}

# Tercera carga: Nerea se da de alta en secretaría pero todavía no ha elegido
# asignaturas. La usa la parte de explotación para ilustrar por qué la misma
# pregunta admite varias respuestas legítimas.
CARGA_3 = {
    "fecha": "2026-01-13 03:00:00",
    "alumnos": CARGA_2["alumnos"] + [(5, "Nerea", "Aguirre", "nerea@ejemplo.eus")],
    "asignaturas": CARGA_2["asignaturas"],
    "cursa": CARGA_2["cursa"],
}

# Cuarta carga: Nerea acaba eligiendo Matemáticas. Da el único caso positivo
# de la variable objetivo del tablón de la parte de ciencia de datos.
CARGA_4 = {
    "fecha": "2026-01-15 03:00:00",
    "alumnos": CARGA_3["alumnos"],
    "asignaturas": CARGA_3["asignaturas"],
    "cursa": CARGA_3["cursa"] + [(5, 1)],
}


def _conectar():
    con = duckdb.connect()
    con.sql("INSTALL ducklake; LOAD ducklake;")
    con.sql(f"ATTACH 'ducklake:sqlite:{CATALOGO}' AS lago (DATA_PATH '{DATOS}')")
    con.sql("USE lago")
    return con


def crear_lago():
    """Deja el lago con la primera carga de staging, sin conexiones abiertas."""
    shutil.rmtree(ESPACIO, ignore_errors=True)
    os.makedirs(ESPACIO, exist_ok=True)

    con = _conectar()
    con.sql("CREATE SCHEMA staging")
    con.sql("""
        CREATE TABLE staging.alumnos (
            id_alumno INTEGER, nombre VARCHAR, apellido VARCHAR, email VARCHAR,
            _origen VARCHAR, _cargado_en TIMESTAMP)
    """)
    con.sql("""
        CREATE TABLE staging.asignaturas (
            id_asignatura INTEGER, nombre VARCHAR,
            _origen VARCHAR, _cargado_en TIMESTAMP)
    """)
    con.sql("""
        CREATE TABLE staging.cursa (
            id_alumno INTEGER, id_asignatura INTEGER,
            _origen VARCHAR, _cargado_en TIMESTAMP)
    """)
    _volcar(con, CARGA_1)
    con.close()


def cargar(carga):
    """Simula una ejecución de la ingesta: staging refleja el estado del origen."""
    con = _conectar()
    _volcar(con, carga)
    con.close()


def _volcar(con, carga):
    fecha = carga["fecha"]
    for tabla in ("alumnos", "asignaturas", "cursa"):
        con.sql(f"DELETE FROM staging.{tabla}")
    con.executemany(
        "INSERT INTO staging.alumnos VALUES (?, ?, ?, ?, 'secretaria', ?)",
        [(*fila, fecha) for fila in carga["alumnos"]],
    )
    con.executemany(
        "INSERT INTO staging.asignaturas VALUES (?, ?, 'secretaria', ?)",
        [(*fila, fecha) for fila in carga["asignaturas"]],
    )
    con.executemany(
        "INSERT INTO staging.cursa VALUES (?, ?, 'secretaria', ?)",
        [(*fila, fecha) for fila in carga["cursa"]],
    )


def consultar(sql):
    """Lanza una consulta contra el lago y devuelve el resultado, sin dejar rastro."""
    con = _conectar()
    try:
        return con.sql(sql).df()
    finally:
        con.close()


def dbt(*argumentos):
    """Ejecuta dbt sobre el proyecto de ejemplo y devuelve su salida."""
    # dbt se busca junto al intérprete que está renderizando el libro, para no
    # depender de que el entorno virtual esté activado en el PATH.
    ejecutable = os.path.join(os.path.dirname(sys.executable), "dbt")
    entorno = dict(os.environ, LAGO_CATALOGO=CATALOGO, DBT_PROFILES_DIR=PROYECTO)
    resultado = subprocess.run(
        [
            ejecutable,
            "--no-use-colors",
            *argumentos,
            "--project-dir", PROYECTO,
            "--target-path", os.path.join(ESPACIO, "target"),
            "--log-path", os.path.join(ESPACIO, "logs"),
        ],
        capture_output=True,
        text=True,
        env=entorno,
        cwd=PROYECTO,
    )
    return resultado.stdout


MODELOS = ("OK created", "Completed", "ERROR", "Done. PASS=")
TESTS = ("PASS ", "FAIL ", "Done. PASS=", "Completed", "ERROR")


def resumen(salida, patrones=MODELOS):
    """Filtra el ruido de dbt y deja las líneas que interesan en el libro."""
    return "\n".join(
        linea.split("  ", 1)[-1].strip()
        for linea in salida.splitlines()
        if any(marca in linea for marca in patrones)
    )
