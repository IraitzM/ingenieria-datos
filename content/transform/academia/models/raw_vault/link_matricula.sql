-- Un enlace registra que una relación existió. Tampoco se actualiza:
-- si la matrícula desaparece del origen, el enlace permanece y es el
-- satélite quien informa del estado.

with relaciones as (

    select
        hk_matricula,
        hk_alumno,
        hk_asignatura,
        min(load_date)      as load_date,
        min(record_source)  as record_source
    from {{ ref('stg_matriculas') }}
    group by hk_matricula, hk_alumno, hk_asignatura

)

select * from relaciones
{{ solo_nuevas_claves('hk_matricula') }}
