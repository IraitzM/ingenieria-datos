-- Contactos de Odoo, normalizados para el vault.
--
-- En Odoo todo contacto vive en la misma tabla: clientes, proveedores,
-- empleados y direcciones de envío. La tentación es filtrar aquí por
-- `customer_rank > 0` para quedarse solo con los clientes, y es justo lo que
-- no hay que hacer, por dos razones.
--
-- La primera es de integridad: si staging descarta claves que luego aparecen
-- referenciadas en un pedido, el enlace apunta a un hub donde esa clave no
-- está y el vault queda roto. Un filtro de negocio no puede decidir qué
-- claves existen.
--
-- La segunda es que ese contador miente. Odoo lo incrementa desde el flujo de
-- la interfaz, no desde la base de datos, así que los datos de demostración
-- (cargados como fixtures XML) lo dejan a cero incluso para quien tiene
-- pedidos confirmados. El rango se conserva como atributo, que es su sitio.

SELECT
    id                AS customer_id,
    name              AS customer_name,
    is_company,
    customer_rank,
    supplier_rank,
    email,
    phone,
    street,
    city,
    zip,
    country_id,
    state_id,
    active,
    create_date,
    write_date
FROM {{ source('raw', 'raw_customers') }}
WHERE id IS NOT NULL
