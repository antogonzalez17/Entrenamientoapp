-- PASO 1 (antes del Merge). Crea la tabla nueva, sus reglas de acceso
-- y copia ahí lo que ya hay asignado. No borra ni cambia nada de lo antiguo,
-- así que la app actual sigue funcionando igual.

begin;

create table if not exists public.athlete_items (
  id          text primary key,
  coach_id    uuid not null,
  athlete_id  uuid not null,
  kind        text not null check (kind in ('session', 'questionnaire')),
  data        jsonb not null,
  updated_at  timestamptz not null default now()
);
create index if not exists athlete_items_coach_idx   on public.athlete_items (coach_id);
create index if not exists athlete_items_athlete_idx on public.athlete_items (athlete_id);

alter table public.athlete_items enable row level security;
grant select, insert, update, delete on public.athlete_items to authenticated;

-- Entrenador: ve, modifica y borra todo lo de su equipo
create policy "Entrenador ve lo de su equipo" on public.athlete_items
  for select using (coach_id = auth.uid());
create policy "Entrenador modifica lo de su equipo" on public.athlete_items
  for update using (coach_id = auth.uid()) with check (coach_id = auth.uid());
create policy "Entrenador borra lo de su equipo" on public.athlete_items
  for delete using (coach_id = auth.uid());
-- Entrenador: solo puede asignar a deportistas de su propio equipo
create policy "Entrenador asigna a su equipo" on public.athlete_items
  for insert with check (
    coach_id = auth.uid()
    and athlete_id in (select p.id from public.profiles p where p.coach_id = auth.uid())
  );

-- Deportista: solo ve y actualiza lo suyo (no puede crear ni borrar)
create policy "Deportista ve lo suyo" on public.athlete_items
  for select using (athlete_id = auth.uid());
create policy "Deportista actualiza lo suyo" on public.athlete_items
  for update using (athlete_id = auth.uid())
  with check (
    athlete_id = auth.uid()
    and coach_id in (select p.coach_id from public.profiles p where p.id = auth.uid())
  );

-- Copia lo ya asignado (sesiones y cuestionarios) a la tabla nueva
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

commit;

-- Comprobación: los dos números de cada fila deberían coincidir
select d.key as tipo,
       jsonb_array_length(d.value::jsonb) as en_lo_antiguo,
       (select count(*) from public.athlete_items i
         where i.coach_id = d.coach_id
           and i.kind = case d.key when 'assignments' then 'session' else 'questionnaire' end) as en_la_tabla_nueva
from public.app_data d
where d.key in ('assignments', 'questionnaire-assignments')
  and jsonb_typeof(d.value::jsonb) = 'array';
