-- Un hub guarda la lista de claves de negocio que existen, y nada más.
-- Es insert-only: una clave entra una vez y ya no se toca nunca.

with claves as (

    select
        hk_alumno,
        id_alumno,
        min(load_date)      as load_date,
        min(record_source)  as record_source
    from {{ ref('stg_alumnos') }}
    group by hk_alumno, id_alumno

)

select * from claves
{{ solo_nuevas_claves('hk_alumno') }}
