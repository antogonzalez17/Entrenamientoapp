-- PASO 2 (después del Merge, cuando Netlify ya haya publicado la app nueva).
-- Recoge lo que se haya asignado en los minutos de transición y quita a los
-- deportistas el acceso al bloque antiguo donde estaban los datos de todos.
-- Los datos antiguos NO se borran: quedan como copia de seguridad que solo
-- puede ver el entrenador.

begin;

-- 1) Copia lo que se haya creado con la app antigua durante la transición
insert into public.athlete_items (id, coach_id, athlete_id, kind, data)
select e->>'id', d.coach_id, (e->>'athleteId')::uuid,
       case d.key when 'assignments' then 'session' else 'questionnaire' end,
       e
from public.app_data d
cross join lateral jsonb_array_elements(d.value::jsonb) e
where d.key in ('assignments', 'questionnaire-assignments')
  and jsonb_typeof(d.value::jsonb) = 'array'
  and e->>'id' is not null
  and (e->>'athleteId') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
on conflict (id) do nothing;

-- 2) Los deportistas ya no pueden escribir en el bloque antiguo
drop policy if exists "El deportista actualiza sesiones y cuestionarios" on public.app_data;
drop policy if exists "El deportista guarda sesiones y cuestionarios" on public.app_data;

-- 3) Los deportistas solo pueden leer la biblioteca de su entrenador
--    (ejercicios y plantillas), no lo asignado a sus compañeros
drop policy if exists "Leer datos de tu equipo" on public.app_data;
create policy "Leer datos de tu equipo" on public.app_data
  for select using (
    coach_id = auth.uid()
    or (
      key in ('exercises', 'session-templates', 'questionnaire-templates')
      and coach_id in (select p.coach_id from public.profiles p where p.id = auth.uid())
    )
  );

commit;
