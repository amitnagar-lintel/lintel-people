-- PEOPLE-UX-01 — "Out today" card on the Lintel People home screen
-- APPLIED to Supabase 1 Sep 2026 (migration: people_ux_01_whos_out_today)
-- Why an RPC: RLS on hr_leave_requests/employees restricts employees to their
-- own rows. This SECURITY DEFINER function exposes ONLY (name, leave type,
-- return date) of teammates on approved leave covering today — nothing else.

create or replace function public.hr_whos_out_today()
returns table (full_name text, leave_type text, back_on date)
language sql
security definer
set search_path = public
stable
as $$
  select e.full_name, l.leave_type, (l.to_date + 1)::date as back_on
  from hr_leave_requests l
  join employees e on e.id = l.employee_id
  where l.status = 'approved'
    and current_date between l.from_date and l.to_date
    -- only employees may ask (reuses the existing helper used by RLS policies)
    and (is_employee() or is_hr_admin())
  order by e.full_name;
$$;

revoke all on function public.hr_whos_out_today() from public;
grant execute on function public.hr_whos_out_today() to authenticated;
