-- TAMA Store Supabase setup (fixed admin + live chat RPC)
-- Create the Auth user first, then run this whole file in Supabase SQL Editor.
-- Admin email used by this store: fyesty8@gmail.com

create extension if not exists pgcrypto;

-- Drop chat RPC overloads so PostgREST sees one exact signature per function name.
do $$
declare
  fn record;
begin
  for fn in
    select p.oid, p.proname, oidvectortypes(p.proargtypes) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public'
      and p.proname in ('get_or_create_chat','get_user_chat','send_user_chat_message','close_user_chat')
  loop
    execute format('drop function if exists public.%I(%s)', fn.proname, fn.args);
  end loop;
end $$;

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  price integer not null,
  budget text not null,
  thumbnail_url text not null,
  thumbnail_path text,
  image_path text,
  created_at timestamptz not null default now()
);

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  image_url text not null,
  image_path text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  username text not null check (char_length(username) between 2 and 24),
  rating smallint not null check (rating between 1 and 5),
  text text,
  published boolean not null default true,
  created_at timestamptz not null default now()
);

-- Compatibility for earlier review schemas that used another text column name.
alter table public.reviews add column if not exists text text;
do $review_migration$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='comment') then
    execute $sql$update public.reviews set text = coalesce(nullif(text,''), comment) where text is null or text = ''$sql$;
  elsif exists (select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='review_text') then
    execute $sql$update public.reviews set text = coalesce(nullif(text,''), review_text) where text is null or text = ''$sql$;
  elsif exists (select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='content') then
    execute $sql$update public.reviews set text = coalesce(nullif(text,''), content) where text is null or text = ''$sql$;
  elsif exists (select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='message') then
    execute $sql$update public.reviews set text = coalesce(nullif(text,''), message) where text is null or text = ''$sql$;
  end if;
end $review_migration$;
update public.reviews set text = 'Ulasan' where text is null or btrim(text) = '';
alter table public.reviews alter column text set not null;
alter table public.reviews drop constraint if exists reviews_text_check;
alter table public.reviews add constraint reviews_text_check check (char_length(text) between 1 and 300);

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  category text not null check (category in ('Pesanan','Pembayaran','Produk','Lainnya')),
  status text not null default 'open' check (status in ('open','closed')),
  access_token text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_type text not null check (sender_type in ('user','admin')),
  message text not null check (char_length(message) between 1 and 500),
  created_at timestamptz not null default now()
);

-- Compatibility for stores created by earlier versions.
alter table public.products add column if not exists thumbnail_url text;
alter table public.products add column if not exists thumbnail_path text;
alter table public.products add column if not exists image_path text;
alter table public.products add column if not exists budget text;

-- Remove old incompatible constraints and rebuild the intended ones.
alter table public.products drop constraint if exists products_status_check;
alter table public.products drop constraint if exists products_budget_price_check;
alter table public.products drop constraint if exists products_budget_check;
alter table public.products drop constraint if exists products_price_check;
alter table public.products add constraint products_budget_check check (budget in ('20-100','200-1000'));
alter table public.products add constraint products_price_check check (price between 20000 and 1000000);
alter table public.products add constraint products_budget_price_check check (
  (budget='20-100' and price between 20000 and 100000) or
  (budget='200-1000' and price between 200000 and 1000000)
);

-- Admin test: either the explicit admin row OR the fixed Auth email is accepted.
alter table public.admins enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.reviews enable row level security;
alter table public.chats enable row level security;
alter table public.chat_messages enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select lower(coalesce(auth.jwt() ->> 'email','')) = lower('fyesty8@gmail.com')
      or exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

grant usage on schema public to anon, authenticated;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "admins self" on public.admins;
create policy "admins self" on public.admins for select to authenticated using (user_id = auth.uid() or public.is_admin());

drop policy if exists "products public read" on public.products;
create policy "products public read" on public.products for select to anon, authenticated using (true);
drop policy if exists "products admin insert" on public.products;
create policy "products admin insert" on public.products for insert to authenticated with check (public.is_admin());
drop policy if exists "products admin update" on public.products;
create policy "products admin update" on public.products for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "products admin delete" on public.products;
create policy "products admin delete" on public.products for delete to authenticated using (public.is_admin());

drop policy if exists "product images public read" on public.product_images;
create policy "product images public read" on public.product_images for select to anon, authenticated using (true);
drop policy if exists "product images admin insert" on public.product_images;
create policy "product images admin insert" on public.product_images for insert to authenticated with check (public.is_admin());
drop policy if exists "product images admin delete" on public.product_images;
create policy "product images admin delete" on public.product_images for delete to authenticated using (public.is_admin());

drop policy if exists "reviews public read published" on public.reviews;
create policy "reviews public read published" on public.reviews for select to anon, authenticated using (published = true or public.is_admin());
drop policy if exists "reviews public insert" on public.reviews;
create policy "reviews public insert" on public.reviews for insert to anon, authenticated with check (char_length(username) between 2 and 24 and rating between 1 and 5 and char_length(text) between 1 and 300);
drop policy if exists "reviews admin update" on public.reviews;
create policy "reviews admin update" on public.reviews for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "reviews admin delete" on public.reviews;
create policy "reviews admin delete" on public.reviews for delete to authenticated using (public.is_admin());

drop policy if exists "chats admin read" on public.chats;
create policy "chats admin read" on public.chats for select to authenticated using (public.is_admin());
drop policy if exists "chats admin update" on public.chats;
create policy "chats admin update" on public.chats for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "messages admin read" on public.chat_messages;
create policy "messages admin read" on public.chat_messages for select to authenticated using (public.is_admin());
drop policy if exists "messages admin insert" on public.chat_messages;
create policy "messages admin insert" on public.chat_messages for insert to authenticated with check (public.is_admin());

-- EXACT parameter names expected by the frontend/PostgREST schema cache.
create or replace function public.get_or_create_chat(p_category text, p_token text, p_username text)
returns public.chats
language plpgsql
security definer
set search_path = public
as $$
declare c public.chats;
begin
  if p_category not in ('Pesanan','Pembayaran','Produk','Lainnya') then
    raise exception 'Kategori chat tidak valid';
  end if;
  if p_username is null or char_length(trim(p_username)) < 2 or char_length(trim(p_username)) > 24 then
    raise exception 'Username tidak valid';
  end if;
  if p_token is null or char_length(p_token) < 10 then
    raise exception 'Token chat tidak valid';
  end if;
  select * into c from public.chats where access_token=p_token and status='open' order by updated_at desc limit 1;
  if c.id is null then
    insert into public.chats(username,category,access_token) values(trim(p_username),p_category,p_token) returning * into c;
  else
    update public.chats set username=trim(p_username), category=p_category, updated_at=now() where id=c.id returning * into c;
  end if;
  return c;
end;
$$;

grant execute on function public.get_or_create_chat(text,text,text) to anon, authenticated;

create or replace function public.get_user_chat(p_chat_id uuid, p_token text)
returns json
language sql
security definer
set search_path = public
as $$
  select json_build_object(
    'chat',(select row_to_json(c) from public.chats c where c.id=p_chat_id and c.access_token=p_token),
    'messages',(select coalesce(json_agg(m order by m.created_at asc),'[]'::json) from public.chat_messages m join public.chats c on c.id=m.chat_id where m.chat_id=p_chat_id and c.access_token=p_token)
  );
$$;

grant execute on function public.get_user_chat(uuid,text) to anon, authenticated;

create or replace function public.send_user_chat_message(p_chat_id uuid, p_token text, p_message text)
returns public.chat_messages
language plpgsql
security definer
set search_path = public
as $$
declare m public.chat_messages;
begin
  if p_message is null or char_length(trim(p_message)) < 1 or char_length(trim(p_message)) > 500 then
    raise exception 'Pesan tidak valid';
  end if;
  if not exists(select 1 from public.chats where id=p_chat_id and access_token=p_token and status='open') then
    raise exception 'Chat tidak ditemukan atau sudah ditutup';
  end if;
  insert into public.chat_messages(chat_id,sender_type,message) values(p_chat_id,'user',trim(p_message)) returning * into m;
  update public.chats set updated_at=now() where id=p_chat_id;
  return m;
end;
$$;

grant execute on function public.send_user_chat_message(uuid,text,text) to anon, authenticated;

create or replace function public.close_user_chat(p_chat_id uuid, p_token text)
returns public.chats
language plpgsql
security definer
set search_path = public
as $$
declare c public.chats;
begin
  update public.chats set status='closed',updated_at=now() where id=p_chat_id and access_token=p_token returning * into c;
  if c.id is null then raise exception 'Chat tidak ditemukan'; end if;
  return c;
end;
$$;

grant execute on function public.close_user_chat(uuid,text) to anon, authenticated;

-- Storage
-- The admin uploader always uses the exact bucket ID: product-images.
insert into storage.buckets (id,name,public) values ('product-images','product-images',true)
on conflict (id) do update set name='product-images', public=true;

drop policy if exists "product images public read" on storage.objects;
create policy "product images public read" on storage.objects for select to public using (bucket_id='product-images');
drop policy if exists "product images admin upload" on storage.objects;
create policy "product images admin upload" on storage.objects for insert to authenticated with check (bucket_id='product-images' and public.is_admin());
drop policy if exists "product images admin delete" on storage.objects;
create policy "product images admin delete" on storage.objects for delete to authenticated using (bucket_id='product-images' and public.is_admin());

-- Sync the known admin Auth user into the admins table when it already exists.
insert into public.admins(user_id)
select id from auth.users where lower(email)=lower('fyesty8@gmail.com')
on conflict (user_id) do nothing;

-- Helpful cache refresh hint for Supabase/PostgREST.
NOTIFY pgrst, 'reload schema';
