-- Plantilla de la empresa.
--
-- `hr_employee` es la tabla que más se parece a lo que uno espera de un ERP:
-- una fila por persona y las columnas donde deberían estar. La rareza aquí no
-- es el esquema, es lo que se ha dejado fuera en la ingesta (ver
-- `pipelines/odoo_extract.py`): de las cincuenta y ocho columnas del origen
-- solo entran once, porque el resto son datos personales que el almacén
-- analítico no necesita.
--
-- `user_id` es la única columna que no describe a la persona sino al sistema:
-- es la cuenta de Odoo con la que trabaja, y es la que permite saber qué
-- empleado firmó cada pedido. No todos los empleados tienen cuenta, así que
-- viene a NULL con frecuencia.

SELECT
    id                AS employee_id,
    name              AS employee_name,
    work_email,
    work_phone,
    job_title,
    department_id,
    user_id,
    company_id,
    active,
    create_date,
    write_date
FROM {{ source('raw', 'raw_employees') }}
WHERE id IS NOT NULL
