{#
  Por defecto dbt concatena el esquema del destino con el del modelo, de forma
  que un modelo con `+schema: vault` sobre el destino `main` acaba en
  `main_vault`. Aquí queremos los esquemas tal cual (`raw`, `staging`, `vault`,
  `analytics`), que es como los nombra el resto del ejercicio.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
