-- Departamentos.
--
-- El organigrama de Odoo es un árbol: cada departamento puede colgar de otro
-- (`parent_id`) y `complete_name` trae la ruta completa ya calculada, del
-- estilo "Research & Development / R&D USA". Que venga resuelta desde el
-- origen ahorra la consulta recursiva, y conviene quedársela: es lo que se va
-- a enseñar en el panel, porque "R&D USA" a secas no dice de dónde cuelga.
--
-- Ojo con `name`: aquí es `varchar`, mientras que en `crm_team` y en
-- `res_country` el campo del mismo nombre es JSON. La traducibilidad la decide
-- cada modelo de Odoo, no hay una regla que valga para todo el esquema.

SELECT
    id                AS department_id,
    name              AS department_name,
    complete_name     AS department_path,
    parent_id         AS parent_department_id,
    manager_id        AS manager_employee_id,
    company_id,
    active,
    create_date,
    write_date
FROM {{ source('raw', 'raw_departments') }}
WHERE id IS NOT NULL
