-- Tabla de referencia: países.
--
-- Las tablas de referencia son el tercer tipo de tabla del Data Vault y el que
-- menos se explica. No llevan clave hash, no llevan satélite y no son de solo
-- inserción: se reconstruyen enteras en cada carga.
--
-- El criterio para poner algo aquí en lugar de darle un hub es doble: que sea
-- un catálogo estable que no interese historiar, y que solo sirva para
-- decodificar un código. Doscientos cincuenta países cumplen las dos cosas.
-- Darle un hub, un satélite y un enlace a cada cliente costaría tres tablas
-- para responder a "¿cómo se llama el país 233?".
--
-- Lo que se pierde al hacerlo así es el histórico: si un país cambia de
-- nombre, el nombre viejo desaparece del almacén y los informes de hace tres
-- años se redibujan con el nombre nuevo. Para un catálogo de países es
-- asumible; para una tabla de tarifas no lo sería, y ahí la decisión correcta
-- es la contraria.
--
-- La clave de negocio de verdad es el código ISO, no el identificador
-- numérico: el número solo significa algo dentro de esta instalación de Odoo.

{{ config(materialized = 'table', tags = ['data_vault', 'reference']) }}

SELECT
    country_id,
    country_code,
    country_name,
    {{ dv_load_date() }}         AS load_date,
    '{{ var("record_source") }}' AS record_source
FROM {{ ref('stg_countries') }}
