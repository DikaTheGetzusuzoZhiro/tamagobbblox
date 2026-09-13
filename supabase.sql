-- ============================================================
-- TAMA STORE - SUPABASE FINAL COMPATIBILITY SETUP
-- ============================================================
-- Admin utama: fyesty8@gmail.com
--
-- Perbaikan:
-- 1) reviews.comment lama yang NOT NULL tetap didukung
-- 2) products.image_url lama yang NOT NULL tetap didukung
-- 3) Kategori/Budget produk DIHAPUS dari UI dan tidak diwajibkan DB
-- 4) Admin tambahan tetap memakai public.admins.email
-- 5) Chat RPC memakai nama parameter yang cocok dengan frontend
-- 6) Storage bucket product-images dibuat otomatis
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1. Hapus overload RPC chat yang lama supaya schema cache bersih
-- ------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select n.nspname as schema_name,
           p.proname,
           pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public'
      and p.proname in ('get_or_create_chat','get_user_chat','send_user_chat_message','close_user_chat')
  loop
    execute format('drop function if exists %I.%I(%s)', r.schema_name, r.proname, r.args);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 2. ADMINS - pertahankan skema lama berbasis email
-- ------------------------------------------------------------
create table if not exists public.admins (
  id uuid default gen_random_uuid(),
  email text,
  created_at timestamptz default now()
);

alter table public.admins add column if not exists id uuid;
alter table public.admins add column if not exists email text;
alter table public.admins add column if not exists created_at timestamptz;
alter table public.admins alter column created_at set default now();

-- ------------------------------------------------------------
-- 3. PRODUCTS - tanpa ketergantungan kategori budget
-- ------------------------------------------------------------
create table if not exists public.products (
  id uuid default gen_random_uuid(),
  title text,
  description text,
  price integer,
  thumbnail_url text,
  thumbnail_path text,
  image_url text,
  image_path text,
  budget text,
  created_at timestamptz default now()
);

alter table public.products add column if not exists id uuid;
alter table public.products add column if not exists title text;
alter table public.products add column if not exists description text;
alter table public.products add column if not exists price integer;
alter table public.products add column if not exists thumbnail_url text;
alter table public.products add column if not exists thumbnail_path text;
alter table public.products add column if not exists image_url text;
alter table public.products add column if not exists image_path text;
alter table public.products add column if not exists budget text;
alter table public.products add column if not exists created_at timestamptz;
alter table public.products alter column created_at set default now();

-- Produk lama yang memakai image_url tetap terbaca oleh UI baru.
update public.products
set thumbnail_url = coalesce(nullif(thumbnail_url,''), nullif(image_url,''))
where thumbnail_url is null or btrim(thumbnail_url)='';

-- Produk lama yang punya thumbnail_url memenuhi kolom legacy image_url.
update public.products
set image_url = coalesce(nullif(image_url,''), nullif(thumbnail_url,''), '')
where image_url is null or btrim(image_url)='';

-- Tidak lagi mewajibkan kolom legacy budget/image_url.
alter table public.products alter column budget drop not null;
alter table public.products alter column image_url drop not null;

update public.products set title='Produk' where title is null or btrim(title)='';
update public.products set description='' where description is null;
update public.products set price=20000 where price is null;
update public.products set created_at=now() where created_at is null;

-- Hapus constraint budget lama karena kategori budget sudah dihapus.
alter table public.products drop constraint if exists products_status_check;
alter table public.products drop constraint if exists products_budget_price_check;
alter table public.products drop constraint if exists products_budget_check;
alter table public.products drop constraint if exists products_price_check;

-- Harga tetap dibatasi pada rentang umum toko.
do $$
begin
  begin
    alter table public.products
      add constraint products_price_check check (price between 20000 and 1000000);
  exception when duplicate_object then null;
  end;
end $$;

-- ------------------------------------------------------------
-- 4. PRODUCT IMAGES
-- ------------------------------------------------------------
create table if not exists public.product_images (
  id uuid default gen_random_uuid(),
  product_id uuid,
  image_url text,
  image_path text,
  sort_order integer default 0,
  created_at timestamptz default now()
);

alter table public.product_images add column if not exists id uuid;
alter table public.product_images add column if not exists product_id uuid;
alter table public.product_images add column if not exists image_url text;
alter table public.product_images add column if not exists image_path text;
alter table public.product_images add column if not exists sort_order integer;
alter table public.product_images add column if not exists created_at timestamptz;
alter table public.product_images alter column sort_order set default 0;
alter table public.product_images alter column created_at set default now();
update public.product_images set sort_order=0 where sort_order is null;
update public.product_images set created_at=now() where created_at is null;

-- ------------------------------------------------------------
-- 5. REVIEWS - kompatibel dengan kolom lama comment
-- ------------------------------------------------------------
create table if not exists public.reviews (
  id uuid default gen_random_uuid(),
  username text,
  rating smallint,
  text text,
  comment text,
  published boolean default true,
  created_at timestamptz default now()
);

alter table public.reviews add column if not exists id uuid;
alter table public.reviews add column if not exists username text;
alter table public.reviews add column if not exists rating smallint;
alter table public.reviews add column if not exists text text;
alter table public.reviews add column if not exists comment text;
alter table public.reviews add column if not exists published boolean;
alter table public.reviews add column if not exists created_at timestamptz;
alter table public.reviews alter column published set default true;
alter table public.reviews alter column created_at set default now();

-- Migrasikan isi dari nama kolom review lama ke text baru, dan sebaliknya.
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='review_text') then
    execute 'update public.reviews set text=coalesce(nullif(btrim(text),''''), review_text) where text is null or btrim(text)='''''';';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='content') then
    execute 'update public.reviews set text=coalesce(nullif(btrim(text),''''), content) where text is null or btrim(text)='''''';';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='message') then
    execute 'update public.reviews set text=coalesce(nullif(btrim(text),''''), message) where text is null or btrim(text)='''''';';
  end if;
end $$;

update public.reviews
set text=coalesce(nullif(btrim(text),''), nullif(btrim(comment),''), 'Ulasan')
where text is null or btrim(text)='';

update public.reviews
set comment=coalesce(nullif(btrim(comment),''), nullif(btrim(text),''), 'Ulasan')
where comment is null or btrim(comment)='';

alter table public.reviews alter column comment drop not null;

update public.reviews set username='User' where username is null or btrim(username)='';
update public.reviews set username=left(btrim(username),24) where char_length(username)>24;
update public.reviews set rating=5 where rating is null or rating<1 or rating>5;
update public.reviews set text=left(btrim(text),300) where char_length(text)>300;
update public.reviews set comment=left(btrim(comment),300) where char_length(comment)>300;
update public.reviews set published=true where published is null;
update public.reviews set created_at=now() where created_at is null;

alter table public.reviews drop constraint if exists reviews_text_check;
alter table public.reviews drop constraint if exists reviews_username_check;
alter table public.reviews drop constraint if exists reviews_rating_check;

do $$
begin
  begin alter table public.reviews add constraint reviews_username_check check (char_length(username) between 2 and 24); exception when duplicate_object then null; end;
  begin alter table public.reviews add constraint reviews_rating_check check (rating between 1 and 5); exception when duplicate_object then null; end;
  begin alter table public.reviews add constraint reviews_text_check check (char_length(text) between 1 and 300); exception when duplicate_object then null; end;
end $$;

-- ------------------------------------------------------------
-- 6. CHATS
-- ------------------------------------------------------------
create table if not exists public.chats (
  id uuid default gen_random_uuid(),
  username text,
  category text,
  status text default 'open',
  access_token text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.chats add column if not exists id uuid;
alter table public.chats add column if not exists username text;
alter table public.chats add column if not exists category text;
alter table public.chats add column if not exists status text;
alter table public.chats add column if not exists access_token text;
alter table public.chats add column if not exists created_at timestamptz;
alter table public.chats add column if not exists updated_at timestamptz;
alter table public.chats alter column status set default 'open';
alter table public.chats alter column created_at set default now();
alter table public.chats alter column updated_at set default now();

update public.chats set username='User' where username is null or btrim(username)='';
update public.chats set username=left(btrim(username),24) where char_length(username)>24;
update public.chats set category='Lainnya' where category is null or category not in ('Pesanan','Pembayaran','Produk','Lainnya');
update public.chats set status='open' where status is null or status not in ('open','closed');
update public.chats set access_token=encode(gen_random_bytes(24),'hex') where access_token is null or btrim(access_token)='';
update public.chats set created_at=now() where created_at is null;
update public.chats set updated_at=created_at where updated_at is null;

create table if not exists public.chat_messages (
  id uuid default gen_random_uuid(),
  chat_id uuid,
  sender_type text,
  message text,
  created_at timestamptz default now()
);

alter table public.chat_messages add column if not exists id uuid;
alter table public.chat_messages add column if not exists chat_id uuid;
alter table public.chat_messages add column if not exists sender_type text;
alter table public.chat_messages add column if not exists message text;
alter table public.chat_messages add column if not exists created_at timestamptz;
alter table public.chat_messages alter column created_at set default now();
update public.chat_messages set sender_type='user' where sender_type is null or sender_type not in ('user','admin');
update public.chat_messages set message='Pesan' where message is null or btrim(message)='';
update public.chat_messages set message=left(btrim(message),500) where char_length(message)>500;
update public.chat_messages set created_at=now() where created_at is null;

-- ------------------------------------------------------------
-- 7. RLS + GRANTS
-- ------------------------------------------------------------
alter table public.admins enable row level security;
alter table public.products enable row level security;
alter table public.product_images enable row level security;
alter table public.reviews enable row level security;
alter table public.chats enable row level security;
alter table public.chat_messages enable row level security;

grant usage on schema public to anon, authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on public.product_images to anon, authenticated;
grant insert, update, delete on public.product_images to authenticated;
grant select, insert on public.reviews to anon, authenticated;
grant update, delete on public.reviews to authenticated;
grant select, update on public.chats to authenticated;
grant select, insert on public.chat_messages to authenticated;
grant select on public.admins to authenticated;

-- ------------------------------------------------------------
-- 8. ADMIN CHECK
-- ------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select lower(coalesce(auth.jwt()->>'email','')) = lower('fyesty8@gmail.com')
      or exists (
        select 1 from public.admins a
        where lower(coalesce(a.email,'')) = lower(coalesce(auth.jwt()->>'email',''))
      );
$$;

grant execute on function public.is_admin() to authenticated;

-- ------------------------------------------------------------
-- 9. POLICIES
-- ------------------------------------------------------------
drop policy if exists "admins self" on public.admins;
create policy "admins self" on public.admins for select to authenticated
using (lower(coalesce(email,''))=lower(coalesce(auth.jwt()->>'email','')) or public.is_admin());

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
drop policy if exists "product images admin update" on public.product_images;
create policy "product images admin update" on public.product_images for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "product images admin delete" on public.product_images;
create policy "product images admin delete" on public.product_images for delete to authenticated using (public.is_admin());

drop policy if exists "reviews public read published" on public.reviews;
create policy "reviews public read published" on public.reviews for select to anon, authenticated using (published=true or public.is_admin());
drop policy if exists "reviews public insert" on public.reviews;
create policy "reviews public insert" on public.reviews for insert to anon, authenticated
with check (char_length(username) between 2 and 24 and rating between 1 and 5 and char_length(text) between 1 and 300);
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

-- ------------------------------------------------------------
-- 10. CHAT RPC
-- ------------------------------------------------------------
create or replace function public.get_or_create_chat(p_category text, p_token text, p_username text)
returns public.chats
language plpgsql
security definer
set search_path=public
as $$
declare c public.chats;
begin
  if p_category is null or p_category not in ('Pesanan','Pembayaran','Produk','Lainnya') then
    raise exception 'Kategori chat tidak valid';
  end if;
  if p_username is null or char_length(trim(p_username))<2 or char_length(trim(p_username))>24 then
    raise exception 'Username tidak valid';
  end if;
  if p_token is null or char_length(p_token)<10 then
    raise exception 'Token chat tidak valid';
  end if;

  select * into c from public.chats where access_token=p_token and status='open' order by updated_at desc limit 1;
  if c.id is null then
    insert into public.chats(username,category,status,access_token,created_at,updated_at)
    values(trim(p_username),p_category,'open',p_token,now(),now()) returning * into c;
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
set search_path=public
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
set search_path=public
as $$
declare m public.chat_messages;
begin
  if p_message is null or char_length(trim(p_message))<1 or char_length(trim(p_message))>500 then raise exception 'Pesan tidak valid'; end if;
  if not exists(select 1 from public.chats where id=p_chat_id and access_token=p_token and status='open') then raise exception 'Chat tidak ditemukan atau sudah ditutup'; end if;
  insert into public.chat_messages(chat_id,sender_type,message,created_at) values(p_chat_id,'user',trim(p_message),now()) returning * into m;
  update public.chats set updated_at=now() where id=p_chat_id;
  return m;
end;
$$;

grant execute on function public.send_user_chat_message(uuid,text,text) to anon, authenticated;

create or replace function public.close_user_chat(p_chat_id uuid, p_token text)
returns public.chats
language plpgsql
security definer
set search_path=public
as $$
declare c public.chats;
begin
  update public.chats set status='closed',updated_at=now() where id=p_chat_id and access_token=p_token returning * into c;
  if c.id is null then raise exception 'Chat tidak ditemukan'; end if;
  return c;
end;
$$;

grant execute on function public.close_user_chat(uuid,text) to anon, authenticated;

-- ------------------------------------------------------------
-- 11. STORAGE
-- ------------------------------------------------------------
insert into storage.buckets(id,name,public)
values('product-images','product-images',true)
on conflict(id) do update set name='product-images',public=true;

drop policy if exists "product images public read" on storage.objects;
create policy "product images public read" on storage.objects for select to public using(bucket_id='product-images');
drop policy if exists "product images admin upload" on storage.objects;
create policy "product images admin upload" on storage.objects for insert to authenticated with check(bucket_id='product-images' and public.is_admin());
drop policy if exists "product images admin update" on storage.objects;
create policy "product images admin update" on storage.objects for update to authenticated using(bucket_id='product-images' and public.is_admin()) with check(bucket_id='product-images' and public.is_admin());
drop policy if exists "product images admin delete" on storage.objects;
create policy "product images admin delete" on storage.objects for delete to authenticated using(bucket_id='product-images' and public.is_admin());

-- Refresh PostgREST schema cache.
notify pgrst, 'reload schema';
