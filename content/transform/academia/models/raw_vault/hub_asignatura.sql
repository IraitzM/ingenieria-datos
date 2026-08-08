with claves as (

    select
        hk_asignatura,
        id_asignatura,
        min(load_date)      as load_date,
        min(record_source)  as record_source
    from {{ ref('stg_asignaturas') }}
    group by hk_asignatura, id_asignatura

)

select * from claves
{{ solo_nuevas_claves('hk_asignatura') }}
