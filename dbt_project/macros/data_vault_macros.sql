{#
  Utilidades del Data Vault. Son pocas y a propósito: casi todo el patrón se
  expresa con SQL corriente, y esconderlo tras macros complica más de lo que
  ahorra en un vault de este tamaño.
#}

{#
  Marca temporal de la carga. Se toma de `run_started_at`, de modo que todas
  las tablas construidas en la misma ejecución comparten `load_date` y el vault
  queda consistente.

  El detalle importa: hay que emitir un literal entrecomillado. Declararlo como
  variable en dbt_project.yml (`dv_load_date: '{{ run_started_at }}'`) genera
  SQL inválido, porque la fecha se interpola sin comillas.
#}
{% macro dv_load_date() -%}
    CAST('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}' AS TIMESTAMP)
{%- endmacro %}

{#
  Clave hash a partir de la clave de negocio.

  `concat_ws` con un separador que no aparece en los datos evita el problema
  clásico de la concatenación desnuda: ('ab', 'c') y ('a', 'bc') producirían el
  mismo hash y dos entidades distintas colapsarían en una.
#}
{% macro hash_clave(columnas) -%}
    md5(concat_ws('||',
        {%- for columna in columnas %}
        coalesce(cast({{ columna }} as varchar), '')
        {%- if not loop.last %},{% endif %}
        {%- endfor %}
    ))
{%- endmacro %}

{#
  Hashdiff: huella de los atributos descriptivos de un satélite. Comparando la
  huella nueva con la última almacenada se sabe si algo cambió sin comparar
  columna a columna.
#}
{% macro hashdiff(columnas) -%}
    {{ hash_clave(columnas) }}
{%- endmacro %}

{#
  Filas vigentes de un satélite.

  Los satélites de este proyecto son de solo inserción: no se actualiza ninguna
  fila para cerrarla. La vigencia se deduce al consultar, quedándose con la
  carga más reciente de cada clave. Es la práctica recomendada en Data Vault
  2.0, porque un `UPDATE` sobre el histórico rompe la propiedad que da sentido
  al modelo, que es que nada de lo ya escrito se toca.
#}
{% macro satelite_vigente(relacion, clave) -%}
    SELECT * EXCLUDE (dv_fila)
    FROM (
        SELECT
            *,
            row_number() OVER (PARTITION BY {{ clave }} ORDER BY load_date DESC) AS dv_fila
        FROM {{ relacion }}
    )
    WHERE dv_fila = 1
{%- endmacro %}

{#
  Relación vigente de un enlace, según su clave conductora.

  Los enlaces también son de solo inserción, y eso tiene una consecuencia que
  se pasa por alto con facilidad: cuando una relación cambia (un empleado se
  traslada de departamento, un producto se recategoriza) no se sustituye nada.
  Entra una fila nueva y la anterior sigue ahí. Al consultar el enlace sin más,
  ese empleado sale dos veces y cualquier recuento lo cuenta dos veces.

  La **clave conductora** (driving key) es el extremo del enlace que se mueve:
  el empleado, no el departamento. Quedándose con su carga más reciente se
  obtiene la relación vigente sin haber cerrado ninguna fila, igual que en los
  satélites.

  Lo que esta macro no cubre conviene tenerlo presente: si la relación
  desaparece del origen (el empleado se queda sin departamento), la última fila
  escrita sigue siendo la del departamento antiguo y aquí se dará por vigente.
  Distinguir "sigue igual" de "ya no está" exige un satélite de efectividad del
  enlace, que este proyecto no monta.
#}
{% macro enlace_vigente(relacion, clave_conductora) -%}
    SELECT * EXCLUDE (dv_fila)
    FROM (
        SELECT
            *,
            row_number() OVER (PARTITION BY {{ clave_conductora }} ORDER BY load_date DESC) AS dv_fila
        FROM {{ relacion }}
    )
    WHERE dv_fila = 1
{%- endmacro %}
