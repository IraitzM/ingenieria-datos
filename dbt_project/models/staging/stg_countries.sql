-- Países.
--
-- `name` vuelve a ser JSON por idioma, igual que en la plantilla de producto,
-- así que hay que extraer `en_US`. La columna que de verdad importa es `code`,
-- el ISO de dos letras: es la clave estable con la que este catálogo se cruza
-- con cualquier otro sistema, mientras que el identificador numérico solo vale
-- dentro de esta instalación de Odoo.

SELECT
    id                                    AS country_id,
    code                                  AS country_code,
    json_extract_string(name, '$.en_US')  AS country_name,
    create_date,
    write_date
FROM {{ source('raw', 'raw_countries') }}
WHERE id IS NOT NULL
