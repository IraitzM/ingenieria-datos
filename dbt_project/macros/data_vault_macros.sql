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
