-- PEOPLE-UX-02 — one-tap punch in/out + celebrations card
-- APPLIED to Supabase 1 Sep 2026 (migration: people_ux_02_punch_and_celebrations)

alter table hr_attendance
  add column if not exists punch_in timestamptz,
  add column if not exists punch_out timestamptz,
  add column if not exists punch_in_lat double precision,
  add column if not exists punch_in_lng double precision,
  add column if not exists punch_out_lat double precision,
  add column if not exists punch_out_lng double precision;

create or replace function public.hr_celebrations()
returns table (full_name text, kind text, on_date date, years int)
language sql security definer set search_path = public stable
as $$
  with occ as (
    select e.full_name, 'birthday'::text as kind, p.dob as base
    from hr_profiles p
    join employees e on e.id = p.employee_id and e.status = 'active'
    where p.dob is not null
    union all
    select e.full_name, 'anniversary'::text, e.date_of_joining
    from employees e
    where e.status = 'active' and e.date_of_joining is not null
  ),
  nxt as (
    select full_name, kind, base,
      (base + make_interval(years =>
        (extract(year from current_date)::int - extract(year from base)::int)
        + case when (base + make_interval(years =>
            extract(year from current_date)::int - extract(year from base)::int))::date
            < current_date then 1 else 0 end))::date as on_date
    from occ
  )
  select full_name, kind, on_date,
    case when kind = 'anniversary'
      then extract(year from on_date)::int - extract(year from base)::int
      else null end as years
  from nxt
  where on_date between current_date and current_date + 6
    and (kind = 'birthday'
         or extract(year from on_date)::int - extract(year from base)::int >= 1)
    and (is_employee() or is_hr_admin())
  order by on_date, full_name;
$$;

revoke all on function public.hr_celebrations() from public;
grant execute on function public.hr_celebrations() to authenticated;
