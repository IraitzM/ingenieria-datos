-- Productos: la variante unida a su plantilla.
--
-- Aquí se resuelven de golpe las dos rarezas del modelo físico de Odoo que se
-- explican en el apéndice:
--
--   * `product_product` (la variante) no tiene nombre ni precio. Hay que ir a
--     `product_template` a buscarlos.
--   * `product_template.name` es JSON, con una entrada por idioma. Nos
--     quedamos con `en_US`, que es el idioma de los datos de demostración.
--
-- El coste de venta (`standard_price`) no aparece por ningún lado porque no es
-- una columna: Odoo lo guarda en `ir_property`, ya que depende de la compañía.
-- Cualquier margen que se quiera calcular tendrá que ir a buscarlo allí.

WITH plantillas AS (
    SELECT
        id                                        AS template_id,
        json_extract_string(name, '$.en_US')      AS product_name,
        type                                      AS product_type,
        categ_id                                  AS category_id,
        list_price
    FROM {{ source('raw', 'raw_product_templates') }}
)

SELECT
    v.id                  AS product_id,
    v.product_tmpl_id     AS template_id,
    p.product_name,
    p.product_type,
    p.category_id,
    p.list_price,
    v.default_code        AS product_code,
    v.barcode,
    v.weight,
    v.volume,
    v.active,
    v.create_date,
    v.write_date
FROM {{ source('raw', 'raw_products') }} v
LEFT JOIN plantillas p
    ON v.product_tmpl_id = p.template_id
WHERE v.id IS NOT NULL
