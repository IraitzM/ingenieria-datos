-- Tabla point-in-time: para cada alumno y cada fecha de carga en la que
-- algo cambió, apunta a la versión del satélite vigente en ese momento.
-- Evita que las consultas de negocio tengan que resolver ventanas.

with fechas as (

    select distinct hk_alumno, load_date
    from {{ ref('sat_alumno') }}

)

select
    fechas.hk_alumno,
    fechas.load_date                                as fecha_foto,
    max(sat.load_date)                              as load_date_sat
from fechas
join {{ ref('sat_alumno') }} as sat
  on sat.hk_alumno = fechas.hk_alumno
 and sat.load_date <= fechas.load_date
group by fechas.hk_alumno, fechas.load_date
