-- ============================================================
--  Jr. Bros — Supabase setup
--  Run this once, whole file, in Supabase → SQL Editor → New query.
--  CHANGE THE PASSCODE on the marked line before running.
-- ============================================================

-- ---------- tables ----------

create table if not exists players (
  id      text primary key,
  name    text not null,
  goalie  boolean not null default false,
  sort    integer not null default 0,
  paid    boolean not null default false
);

create table if not exists checkins (
  session    date not null,
  player_id  text not null references players(id) on delete cascade,
  status     text not null check (status in ('in','out')),
  updated_at timestamptz not null default now(),
  primary key (session, player_id)
);

create table if not exists lines_assign (
  session   date not null,
  player_id text not null references players(id) on delete cascade,
  jersey    text check (jersey in ('light','dark')),
  pos       text check (pos in ('f','d')),
  primary key (session, player_id)
);

create table if not exists settings (
  key   text primary key,
  value text
);

-- ---------- the coach passcode ----------
--  >>> CHANGE 'bros2026' TO YOUR OWN PASSCODE <<<
insert into settings (key, value) values ('coach_code', 'bros2026')
  on conflict (key) do update set value = excluded.value;

insert into settings (key, value) values ('fee', '220')
  on conflict (key) do nothing;

-- ---------- roster ----------

insert into players (id, name, goalie, sort) values
  ('p1','Chase Cronk',false,1),       ('p2','Dax Wiffen',false,2),
  ('p3','Ari Wiffen',false,3),        ('p4','Kaia Allaire',false,4),
  ('p5','Vincent Mensah',false,5),    ('p6','Noah Ripley',false,6),
  ('p7','Gibson Wiebe',true,7),       ('p8','Layla Quinn',false,8),
  ('p9','Helena Quinn',false,9),      ('p10','Deklen Vermullen',false,10),
  ('p11','Jack Randall',false,11),    ('p12','Scarlett Randall',false,12),
  ('p13','Wavy Monk',false,13),       ('p14','Imogen Monk',false,14),
  ('p15','Corbin Rees',false,15),     ('p16','Lincon Klassen',false,16),
  ('p17','Paige Clague',false,17),    ('p18','Lexi Jo Germain',false,18),
  ('p19','Lucas Morgan',false,19)
on conflict (id) do nothing;

-- ============================================================
--  Row level security
--  The public key can: read roster, read + write check-ins, read lines.
--  It canNOT: change the roster, change lines, read the passcode.
--  Everything a coach does goes through the functions further down,
--  which check the passcode inside the database.
-- ============================================================

alter table players      enable row level security;
alter table checkins     enable row level security;
alter table lines_assign enable row level security;
alter table settings     enable row level security;

drop policy if exists players_read   on players;
drop policy if exists checkins_read  on checkins;
drop policy if exists checkins_write on checkins;
drop policy if exists checkins_edit  on checkins;
drop policy if exists lines_read     on lines_assign;

create policy players_read   on players      for select using (true);
create policy lines_read     on lines_assign for select using (true);
create policy checkins_read  on checkins     for select using (true);
create policy checkins_write on checkins     for insert with check (true);
create policy checkins_edit  on checkins     for update using (true) with check (true);

-- settings gets no policy at all, so the public key can never read the passcode.

-- ============================================================
--  Coach functions. Each one validates the passcode server-side.
-- ============================================================

create or replace function check_code(p_code text)
returns boolean language plpgsql security definer set search_path = public as $$
declare stored text;
begin
  select value into stored from settings where key = 'coach_code';
  return stored is not null and stored = p_code;
end $$;

create or replace function coach_set_line(
  p_code text, p_session date, p_player text, p_jersey text, p_pos text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not check_code(p_code) then raise exception 'bad passcode'; end if;
  if p_jersey is null and p_pos is null then
    delete from lines_assign where session = p_session and player_id = p_player;
  else
    insert into lines_assign (session, player_id, jersey, pos)
    values (p_session, p_player, p_jersey, p_pos)
    on conflict (session, player_id)
      do update set jersey = excluded.jersey, pos = excluded.pos;
  end if;
end $$;

create or replace function coach_clear_lines(p_code text, p_session date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not check_code(p_code) then raise exception 'bad passcode'; end if;
  delete from lines_assign where session = p_session;
end $$;

create or replace function coach_set_checkin(
  p_code text, p_session date, p_player text, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not check_code(p_code) then raise exception 'bad passcode'; end if;
  if p_status is null then
    delete from checkins where session = p_session and player_id = p_player;
  else
    insert into checkins (session, player_id, status, updated_at)
    values (p_session, p_player, p_status, now())
    on conflict (session, player_id)
      do update set status = excluded.status, updated_at = now();
  end if;
end $$;

create or replace function coach_add_player(p_code text, p_name text, p_goalie boolean)
returns void language plpgsql security definer set search_path = public as $$
declare nxt integer;
begin
  if not check_code(p_code) then raise exception 'bad passcode'; end if;
  select coalesce(max(sort), 0) + 1 into nxt from players;
  insert into players (id, name, goalie, sort)
  values ('p' || extract(epoch from now())::bigint, p_name, coalesce(p_goalie,false), nxt);
end $$;

create or replace function coach_remove_player(p_code text, p_player text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not check_code(p_code) then raise exception 'bad passcode'; end if;
  delete from players where id = p_player;
end $$;

create or replace function coach_set_paid(p_code text, p_player text, p_paid boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not check_code(p_code) then raise exception 'bad passcode'; end if;
  update players set paid = p_paid where id = p_player;
end $$;

create or replace function coach_set_fee(p_code text, p_fee text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not check_code(p_code) then raise exception 'bad passcode'; end if;
  insert into settings (key, value) values ('fee', p_fee)
    on conflict (key) do update set value = excluded.value;
end $$;

-- the coach page needs the fee and the paid flags; expose them read-only
create or replace function public_fee()
returns text language sql security definer set search_path = public as $$
  select value from settings where key = 'fee';
$$;

grant execute on function check_code(text)                                   to anon;
grant execute on function coach_set_line(text, date, text, text, text)       to anon;
grant execute on function coach_clear_lines(text, date)                      to anon;
grant execute on function coach_set_checkin(text, date, text, text)          to anon;
grant execute on function coach_add_player(text, text, boolean)              to anon;
grant execute on function coach_remove_player(text, text)                    to anon;
grant execute on function coach_set_paid(text, text, boolean)                to anon;
grant execute on function coach_set_fee(text, text)                          to anon;
grant execute on function public_fee()                                       to anon;

-- ============================================================
--  Done. Next: paste your project URL and anon key into config.js
-- ============================================================
