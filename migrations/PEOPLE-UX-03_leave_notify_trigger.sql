-- PEOPLE-UX-03 — DB trigger: new pending leave request → people-leave edge fn
-- APPLIED to Supabase 1 Sep 2026 (migration: people_ux_03_leave_notify_trigger)
-- Mirrors the notify_client_reply pattern (pg_net + vault cron_secret).
-- notified_at dedupes the trigger against the portal's own client-side call:
-- the edge fn (v3) atomically claims it before emailing → admins get ONE email.

alter table hr_leave_requests add column if not exists notified_at timestamptz;

create or replace function public.notify_leave_request()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'cron_secret' limit 1;

  perform net.http_post(
    url     := 'https://cxgxmqspvpuizvwfbnjq.supabase.co/functions/v1/people-leave',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-cron-secret', coalesce(v_secret, '')
               ),
    body    := jsonb_build_object('request_id', new.id),
    timeout_milliseconds := 15000
  );
  return new;
exception when others then
  raise warning 'leave-request alert dispatch failed for request %: %', new.id, sqlerrm;
  return new;
end;
$$;

drop trigger if exists trg_notify_leave_request on hr_leave_requests;
create trigger trg_notify_leave_request
  after insert on hr_leave_requests
  for each row
  when (new.status = 'pending')
  execute function public.notify_leave_request();
