-- Satélite calculado: aquí SÍ aplicamos reglas de negocio. El raw vault
-- queda intacto y esto se puede recalcular entero cuando la regla cambie.

select
    hk_alumno,
    hd_alumno,
    load_date,
    email,
    nombre || ' ' || apellido                       as nombre_completo,
    lower(split_part(email, '@', 2))                as dominio_email,
    case
        when lower(split_part(email, '@', 2)) = 'ejemplo.eus' then 'interno'
        else 'externo'
    end                                             as tipo_correo,
    record_source
from {{ ref('sat_alumno') }}
