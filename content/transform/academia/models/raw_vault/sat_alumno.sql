-- El satélite guarda los atributos y su historia. Solo añade una versión
-- cuando el hashdiff difiere del de la versión vigente de esa clave.

with origen as (

    select
        hk_alumno,
        hd_alumno,
        nombre,
        apellido,
        email,
        load_date,
        record_source
    from {{ ref('stg_alumnos') }}

)

{% if is_incremental() %}
, vigente as (

    select hk_alumno, hd_alumno
    from (
        select
            hk_alumno,
            hd_alumno,
            row_number() over (partition by hk_alumno order by load_date desc) as version
        from {{ this }}
    )
    where version = 1

)
{% endif %}

select origen.*
from origen
{% if is_incremental() %}
left join vigente on vigente.hk_alumno = origen.hk_alumno
where vigente.hk_alumno is null
   or vigente.hd_alumno <> origen.hd_alumno
{% endif %}
