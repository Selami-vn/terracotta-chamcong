-- =====================================================================
-- Terracotta · Chấm công thời vụ — Cơ sở dữ liệu Supabase (PostgreSQL)
-- Chạy toàn bộ file này trong Supabase → SQL Editor → New query → Run.
--
-- Nguyên tắc bảo mật:
--  1. Mọi bảng bật Row Level Security (RLS): nhân sự chỉ đọc được dữ liệu
--     của chính mình, admin đọc/sửa được tất cả.
--  2. Nhân sự KHÔNG được ghi thẳng vào bảng chấm công. Check in/out đi qua
--     hàm check_in()/check_out() chạy trên máy chủ, giờ lấy bằng now()
--     của máy chủ → không gian lận bằng cách chỉnh giờ điện thoại.
--  3. Ảnh lưu trong bucket riêng tư (private), chỉ chủ ảnh và admin xem
--     được, qua đường link có hạn (signed URL).
--  4. Mật khẩu do Supabase Auth quản lý (băm bcrypt), không ai xem được.
-- =====================================================================

-- ---------- Hồ sơ nhân sự (1-1 với tài khoản đăng nhập auth.users) ----------
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique not null check (username ~ '^[a-z0-9._-]{3,30}$'),
  full_name     text not null,
  department    text default 'Nhà Hàng',
  hourly_rate   integer not null default 35000 check (hourly_rate >= 0),
  worker_type   text not null default 'TV' check (worker_type in ('TV','TT')),
  bank_name     text,
  bank_account  text,
  photo_path    text,                       -- ảnh gốc hồ sơ trong Storage
  role          text not null default 'staff' check (role in ('staff','admin')),
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

-- ---------- Ca làm ----------
create table if not exists public.shifts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id),
  check_in      timestamptz not null default now(),
  check_out     timestamptz,
  in_photo      text,                       -- đường dẫn ảnh trong Storage
  out_photo     text,
  hourly_rate   integer not null,           -- chốt mức công tại thời điểm vào ca
  manual        boolean not null default false,
  edited_by     uuid references public.profiles(id),
  edited_at     timestamptz,
  edit_note     text,
  orig_check_in  timestamptz,               -- giờ gốc trước khi admin sửa
  orig_check_out timestamptz,
  created_at    timestamptz not null default now(),
  check (check_out is null or check_out > check_in)
);
create index if not exists shifts_user_in_idx on public.shifts(user_id, check_in desc);
-- mỗi người chỉ có tối đa 1 ca đang mở
create unique index if not exists shifts_one_open on public.shifts(user_id) where check_out is null;

-- ---------- Cài đặt chung (1 dòng) ----------
create table if not exists public.settings (
  id    int primary key default 1 check (id = 1),
  data  jsonb not null default '{}'::jsonb
);
insert into public.settings(id) values (1) on conflict do nothing;

-- ---------- Nhật ký thay đổi (ai sửa gì, lúc nào) ----------
create table if not exists public.audit_log (
  id         bigserial primary key,
  actor      uuid default auth.uid(),
  action     text not null,
  table_name text not null,
  row_id     text,
  old_data   jsonb,
  new_data   jsonb,
  at         timestamptz not null default now()
);

-- ---------- Hàm kiểm tra quyền admin ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin' and active);
$$;

-- ---------- Bật RLS ----------
alter table public.profiles  enable row level security;
alter table public.shifts    enable row level security;
alter table public.settings  enable row level security;
alter table public.audit_log enable row level security;

-- profiles: tự xem hồ sơ mình; admin xem + sửa tất cả. Nhân sự không tự sửa được (kể cả quyền, mức lương).
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_admin_all on public.profiles;
create policy profiles_admin_all on public.profiles for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- shifts: tự xem ca mình; admin xem + sửa + xoá tất cả. Nhân sự không có quyền insert/update trực tiếp.
drop policy if exists shifts_select on public.shifts;
create policy shifts_select on public.shifts for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists shifts_admin_all on public.shifts;
create policy shifts_admin_all on public.shifts for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- settings: ai đăng nhập cũng đọc được (để in tiêu đề), chỉ admin sửa
drop policy if exists settings_select on public.settings;
create policy settings_select on public.settings for select to authenticated using (true);
drop policy if exists settings_admin on public.settings;
create policy settings_admin on public.settings for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- audit_log: chỉ admin đọc; không ai sửa/xoá
drop policy if exists audit_select on public.audit_log;
create policy audit_select on public.audit_log for select to authenticated using (public.is_admin());

-- ---------- Check in / Check out: giờ do MÁY CHỦ quyết định ----------
create or replace function public.check_in(photo_path text) returns public.shifts
language plpgsql security definer set search_path = public as $$
declare p public.profiles; r public.shifts;
begin
  select * into p from public.profiles where id = auth.uid() and active;
  if not found then raise exception 'Tài khoản không hợp lệ hoặc đã bị khoá'; end if;
  if photo_path is null or photo_path not like auth.uid()::text || '/%' then
    raise exception 'Thiếu ảnh check in';
  end if;
  if exists (select 1 from public.shifts where user_id = auth.uid() and check_out is null) then
    raise exception 'Bạn đang có ca chưa check out';
  end if;
  insert into public.shifts(user_id, check_in, in_photo, hourly_rate)
  values (auth.uid(), now(), photo_path, p.hourly_rate) returning * into r;
  return r;
end $$;

create or replace function public.check_out(photo_path text) returns public.shifts
language plpgsql security definer set search_path = public as $$
declare r public.shifts;
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and active) then
    raise exception 'Tài khoản không hợp lệ hoặc đã bị khoá';
  end if;
  if photo_path is null or photo_path not like auth.uid()::text || '/%' then
    raise exception 'Thiếu ảnh check out';
  end if;
  update public.shifts set check_out = now(), out_photo = photo_path
   where user_id = auth.uid() and check_out is null
  returning * into r;
  if r.id is null then raise exception 'Không có ca nào đang mở'; end if;
  return r;
end $$;

revoke all on function public.check_in(text)  from public, anon;
revoke all on function public.check_out(text) from public, anon;
grant execute on function public.check_in(text)  to authenticated;
grant execute on function public.check_out(text) to authenticated;

-- ---------- Ghi nhật ký mọi thay đổi ca làm và hồ sơ ----------
create or replace function public.log_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_log(action, table_name, row_id, old_data, new_data)
  values (tg_op, tg_table_name,
          coalesce(new.id::text, old.id::text),
          case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end);
  return coalesce(new, old);
end $$;
drop trigger if exists shifts_audit on public.shifts;
create trigger shifts_audit after insert or update or delete on public.shifts
  for each row execute function public.log_change();
drop trigger if exists profiles_audit on public.profiles;
create trigger profiles_audit after insert or update or delete on public.profiles
  for each row execute function public.log_change();

-- ---------- Storage: bucket ảnh riêng tư ----------
insert into storage.buckets (id, name, public)
values ('checkin-photos', 'checkin-photos', false)
on conflict (id) do update set public = false;

-- Ảnh lưu theo đường dẫn: <user_id>/<thời-gian>.jpg
drop policy if exists photos_insert_own on storage.objects;
create policy photos_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'checkin-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists photos_read on storage.objects;
create policy photos_read on storage.objects for select to authenticated
  using (bucket_id = 'checkin-photos'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

drop policy if exists photos_admin_all on storage.objects;
create policy photos_admin_all on storage.objects for all to authenticated
  using (bucket_id = 'checkin-photos' and public.is_admin())
  with check (bucket_id = 'checkin-photos' and public.is_admin());
-- Không có policy update/delete cho nhân sự → họ không xoá hay thay được ảnh đã chụp.

-- =====================================================================
-- SAU KHI CHẠY FILE NÀY:
-- 1. Authentication → Users → Add user: tạo tài khoản admin đầu tiên
--    (email dạng admin@terracotta.local, tick "Auto confirm").
-- 2. Chạy lệnh dưới (thay email) để gán quyền admin:
--    insert into public.profiles(id, username, full_name, role)
--    select id, 'admin', 'Quản trị viên', 'admin' from auth.users where email = 'admin@terracotta.local';
-- 3. Authentication → Providers → Email: TẮT "Allow new users to sign up"
--    (chỉ admin mới được tạo tài khoản).
-- =====================================================================
