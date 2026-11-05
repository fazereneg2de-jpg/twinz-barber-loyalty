-- TWINZ BARBER loyalty database
-- Futtasd le a Supabase Dashboard > SQL Editor felületén.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.loyalty_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  qr_token text not null unique default encode(gen_random_bytes(24),'hex'),
  stamps integer not null default 0 check (stamps between 0 and 8),
  reward_available boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.loyalty_visits (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references public.loyalty_cards(id) on delete cascade,
  recorded_by uuid not null references auth.users(id),
  visit_type text not null check (visit_type in ('stamp','reward_redeemed')),
  created_at timestamptz not null default now()
);

create or replace function public.create_customer_records()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  insert into public.profiles(id,full_name)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name',''));
  insert into public.loyalty_cards(user_id) values(new.id);
  return new;
end; $$;

drop trigger if exists on_auth_user_created_twinz on auth.users;
create trigger on_auth_user_created_twinz
after insert on auth.users
for each row execute procedure public.create_customer_records();

-- Admin ellenőrző segédfüggvény: SECURITY DEFINER, hogy az RLS ne hivatkozzon
-- önmagára a profiles táblán keresztül.
create or replace function public.is_twinz_admin()
returns boolean language sql stable security definer set search_path=public
as $$
  select exists(select 1 from public.profiles where id=auth.uid() and is_admin=true);
$$;
revoke all on function public.is_twinz_admin() from public, anon;
grant execute on function public.is_twinz_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.loyalty_cards enable row level security;
alter table public.loyalty_visits enable row level security;

drop policy if exists "profile read own or admin" on public.profiles;
create policy "profile read own or admin" on public.profiles for select to authenticated
using (id=auth.uid() or public.is_twinz_admin());

drop policy if exists "card read own or admin" on public.loyalty_cards;
create policy "card read own or admin" on public.loyalty_cards for select to authenticated
using (user_id=auth.uid() or public.is_twinz_admin());

drop policy if exists "visits read own or admin" on public.loyalty_visits;
create policy "visits read own or admin" on public.loyalty_visits for select to authenticated
using (exists(select 1 from public.loyalty_cards c where c.id=card_id and c.user_id=auth.uid())
or public.is_twinz_admin());

-- A vendég nem módosíthatja közvetlenül a kártyáját vagy a látogatásait.
revoke insert, update, delete on public.profiles from anon, authenticated;
revoke insert, update, delete on public.loyalty_cards from anon, authenticated;
revoke insert, update, delete on public.loyalty_visits from anon, authenticated;

create or replace function public.add_loyalty_visit(p_qr_token text)
returns jsonb language plpgsql security definer set search_path=public
as $$
declare c public.loyalty_cards%rowtype; admin_ok boolean;
begin
  admin_ok := public.is_twinz_admin();
  if not coalesce(admin_ok,false) then raise exception 'Nincs admin jogosultság.'; end if;
  select * into c from public.loyalty_cards where qr_token=p_qr_token for update;
  if not found then raise exception 'Ismeretlen hűségkártya.'; end if;
  if c.reward_available then raise exception 'A vendégnek már van beváltható ingyenes hajvágása. Előbb váltsd be.'; end if;
  update public.loyalty_cards
    set stamps=least(stamps+1,8), reward_available=(stamps+1>=8), updated_at=now()
    where id=c.id returning * into c;
  insert into public.loyalty_visits(card_id,recorded_by,visit_type) values(c.id,auth.uid(),'stamp');
  return jsonb_build_object('message','A látogatás rögzítve.','stamps',c.stamps,'reward_available',c.reward_available);
end; $$;

create or replace function public.redeem_loyalty_reward(p_qr_token text)
returns jsonb language plpgsql security definer set search_path=public
as $$
declare c public.loyalty_cards%rowtype; admin_ok boolean;
begin
  admin_ok := public.is_twinz_admin();
  if not coalesce(admin_ok,false) then raise exception 'Nincs admin jogosultság.'; end if;
  select * into c from public.loyalty_cards where qr_token=p_qr_token for update;
  if not found then raise exception 'Ismeretlen hűségkártya.'; end if;
  if not c.reward_available then raise exception 'Még nincs beváltható jutalom.'; end if;
  update public.loyalty_cards set stamps=0,reward_available=false,updated_at=now() where id=c.id;
  insert into public.loyalty_visits(card_id,recorded_by,visit_type) values(c.id,auth.uid(),'reward_redeemed');
  return jsonb_build_object('message','Az ingyenes hajvágás beváltva. A számláló újraindult.','stamps',0,'reward_available',false);
end; $$;

revoke all on function public.add_loyalty_visit(text) from public, anon;
grant execute on function public.add_loyalty_visit(text) to authenticated;
revoke all on function public.redeem_loyalty_reward(text) from public, anon;
grant execute on function public.redeem_loyalty_reward(text) to authenticated;

-- Admin vendéglista RPC. Csak admin hívhatja, az auth.users e-mail mezőjét
-- nem tesszük közvetlenül publikus nézeten keresztül elérhetővé.
create or replace function public.get_admin_customer_overview()
returns table(id uuid, full_name text, email text, stamps integer, reward_available boolean, created_at timestamptz)
language plpgsql security definer set search_path=public,auth
as $$
begin
  if not public.is_twinz_admin() then raise exception 'Nincs admin jogosultság.'; end if;
  return query
    select p.id,p.full_name,u.email,c.stamps,c.reward_available,c.created_at
    from public.profiles p
    join auth.users u on u.id=p.id
    join public.loyalty_cards c on c.user_id=p.id
    order by p.full_name;
end; $$;
revoke all on function public.get_admin_customer_overview() from public, anon;
grant execute on function public.get_admin_customer_overview() to authenticated;
