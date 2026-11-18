-- Fridge Organizer – jednorazowa konfiguracja bazy (Supabase → SQL Editor → New query → wklej → Run)
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.fo_households (
  id text primary key,                         -- skrót SHA-256 kodu domowego (sam kod nie jest zapisywany)
  data jsonb not null default '{}'::jsonb,     -- przepisy, lodówka, plan, zakupy, oceny…
  version bigint not null default 0,
  updated_at timestamptz not null default now()
);
create table if not exists public.fo_photos (
  household text not null references public.fo_households(id) on delete cascade,
  id text not null,
  data text not null,
  updated_at timestamptz not null default now(),
  primary key (household, id)
);

-- Tabele są zamknięte: brak bezpośredniego dostępu, tylko przez funkcje poniżej (z kodem domowym).
alter table public.fo_households enable row level security;
alter table public.fo_photos enable row level security;
revoke all on public.fo_households from anon, authenticated;
revoke all on public.fo_photos from anon, authenticated;

create or replace function public.fo_hid(p_code text) returns text
language sql immutable set search_path = public, extensions as $$
  select encode(extensions.digest(convert_to(upper(trim(p_code)), 'UTF8'), 'sha256'), 'hex')
$$;

create or replace function public.fo_load(p_code text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare h public.fo_households;
begin
  if length(trim(p_code)) < 10 then raise exception 'code too short'; end if;
  select * into h from public.fo_households where id = public.fo_hid(p_code);
  if not found then return json_build_object('exists', false); end if;
  return json_build_object('exists', true, 'data', h.data, 'version', h.version);
end $$;

create or replace function public.fo_version(p_code text) returns bigint
language sql security definer set search_path = public, extensions as $$
  select coalesce((select version from public.fo_households where id = public.fo_hid(p_code)), -1)
$$;

create or replace function public.fo_save(p_code text, p_data jsonb, p_base bigint) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare v_id text := public.fo_hid(p_code); h public.fo_households;
begin
  if length(trim(p_code)) < 10 then raise exception 'code too short'; end if;
  select * into h from public.fo_households where id = v_id for update;
  if not found then
    if p_base <> 0 then return json_build_object('ok', false, 'missing', true, 'version', 0); end if;
    insert into public.fo_households(id, data, version) values (v_id, p_data, 1);
    return json_build_object('ok', true, 'version', 1);
  end if;
  if h.version <> p_base then
    return json_build_object('ok', false, 'data', h.data, 'version', h.version);
  end if;
  update public.fo_households set data = p_data, version = h.version + 1, updated_at = now() where id = v_id;
  return json_build_object('ok', true, 'version', h.version + 1);
end $$;

create or replace function public.fo_photo_list(p_code text) returns json
language sql security definer set search_path = public, extensions as $$
  select coalesce(json_agg(json_build_object('id', p.id, 'data', p.data)), '[]'::json)
  from public.fo_photos p where p.household = public.fo_hid(p_code)
$$;

create or replace function public.fo_photo_put(p_code text, p_id text, p_data text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare v_id text := public.fo_hid(p_code);
begin
  if length(p_data) > 700000 then raise exception 'photo too large'; end if;
  if not exists (select 1 from public.fo_households where id = v_id) then raise exception 'no household'; end if;
  insert into public.fo_photos(household, id, data) values (v_id, p_id, p_data)
  on conflict (household, id) do update set data = excluded.data, updated_at = now();
end $$;

create or replace function public.fo_photo_del(p_code text, p_id text) returns void
language sql security definer set search_path = public, extensions as $$
  delete from public.fo_photos where household = public.fo_hid(p_code) and id = p_id
$$;

revoke execute on function public.fo_hid(text) from public, anon, authenticated;
revoke execute on function public.fo_load(text), public.fo_version(text), public.fo_save(text, jsonb, bigint),
  public.fo_photo_list(text), public.fo_photo_put(text, text, text), public.fo_photo_del(text, text) from public;
grant execute on function public.fo_load(text), public.fo_version(text), public.fo_save(text, jsonb, bigint),
  public.fo_photo_list(text), public.fo_photo_put(text, text, text), public.fo_photo_del(text, text) to anon, authenticated;

notify pgrst, 'reload schema';
