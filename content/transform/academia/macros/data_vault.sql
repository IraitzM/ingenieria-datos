{# ------------------------------------------------------------------ #}
{# Macros mínimas de Data Vault 2.0                                    #}
{#                                                                     #}
{# Son deliberadamente pocas y cortas: toda la mecánica del vault cabe #}
{# en dos ideas, la clave hash de una clave de negocio y el hashdiff   #}
{# de un conjunto de atributos.                                        #}
{# ------------------------------------------------------------------ #}

{# Normaliza un valor antes de hashearlo. Sin esto, ' 1 ' y '1' serían
   dos entidades distintas y el vault se llenaría de duplicados. #}
{% macro normalizar(columna) -%}
    coalesce(nullif(upper(trim(cast({{ columna }} as varchar))), ''), '@@NULO@@')
{%- endmacro %}

{# Clave hash de negocio. Acepta una o varias columnas, por si la clave
   es compuesta, y las une con un separador que no puede aparecer en los datos. #}
{% macro hash_key(columnas) -%}
    {%- if columnas is string -%}
        {%- set columnas = [columnas] -%}
    {%- endif -%}
    md5(concat_ws('||'
        {%- for columna in columnas -%}
        , {{ normalizar(columna) }}
        {%- endfor -%}
    ))
{%- endmacro %}

{# Huella de los atributos descriptivos de un satélite. Si cambia, el registro
   ha cambiado y toca añadir una versión nueva; si no, no se toca nada. #}
{% macro hashdiff(columnas) -%}
    md5(concat_ws('||'
        {%- for columna in columnas -%}
        , {{ normalizar(columna) }}
        {%- endfor -%}
    ))
{%- endmacro %}

{# Filtro de carga de un hub o un enlace: solo entra lo que no existe ya. #}
{% macro solo_nuevas_claves(clave) -%}
    {%- if is_incremental() %}
    where {{ clave }} not in (select {{ clave }} from {{ this }})
    {%- endif %}
{%- endmacro %}
