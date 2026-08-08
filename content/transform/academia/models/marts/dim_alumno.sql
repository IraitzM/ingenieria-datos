-- Capa de consumo: el usuario no debe saber qué es un hashdiff. Aquí se
-- aplana el vault a la versión vigente de cada alumno.

with vigente as (

    select
        hk_alumno,
        nombre_completo,
        email,
        dominio_email,
        tipo_correo,
        load_date,
        row_number() over (partition by hk_alumno order by load_date desc) as version
    from {{ ref('sat_alumno_bv') }}

)

select
    hub.id_alumno               as alumno_id,
    vigente.nombre_completo,
    vigente.email,
    vigente.dominio_email,
    vigente.tipo_correo,
    hub.load_date               as alta_en_almacen,
    vigente.load_date           as ultima_modificacion
from {{ ref('hub_alumno') }} as hub
join vigente on vigente.hk_alumno = hub.hk_alumno
where vigente.version = 1
