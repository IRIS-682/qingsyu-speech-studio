-- ============================================================
-- 青言青语 SaaS 平台 — 增量迁移脚本
-- 在原有数据库基础上添加新功能，保留已有数据
-- 在 Supabase Dashboard → SQL Editor 中粘贴执行
-- ============================================================

-- ============================================================
-- 第0步：profiles 表结构补全（你的旧表缺少这些列）
-- ============================================================
alter table public.profiles 
  add column if not exists nickname text default '';
alter table public.profiles 
  add column if not exists bio text default '';
alter table public.profiles 
  add column if not exists is_admin boolean default false;
alter table public.profiles 
  add column if not exists updated_at timestamp with time zone default now();

-- 将已有的 username 迁移到 nickname（保留旧字段不动）
update public.profiles 
  set nickname = username 
  where (nickname is null or nickname = '') and username is not null;

-- ============================================================
-- 第1步：创建新表（与原表不冲突）
-- ============================================================

-- 1. 稿件表（你已有的 content 表不受影响，这是独立的新表）
create table if not exists public.manuscripts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  title text not null,
  content text default '',
  type text default 'drama',         -- drama / talk / theory
  word_count integer default 0,
  is_public boolean default false,
  tags text[] default '{}',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- 2. 用户设置表（新表）
create table if not exists public.user_settings (
  user_id uuid references auth.users on delete cascade primary key,
  ai_settings jsonb default '{}',
  quote_favs jsonb default '[]',
  custom_quotes jsonb default '[]',
  wb_data jsonb default '{}',
  updated_at timestamp with time zone default now()
);

-- 3. 动态/帖子表（交流圈用）
create table if not exists public.posts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  content text not null,
  manuscript_id uuid references public.manuscripts on delete set null,
  likes_count integer default 0,
  comments_count integer default 0,
  created_at timestamp with time zone default now()
);

-- 4. 评论表
create table if not exists public.comments (
  id uuid default gen_random_uuid() primary key,
  post_id uuid references public.posts on delete cascade not null,
  user_id uuid references auth.users on delete cascade not null,
  content text not null,
  created_at timestamp with time zone default now()
);

-- 5. 点赞表
create table if not exists public.likes (
  post_id uuid references public.posts on delete cascade not null,
  user_id uuid references auth.users on delete cascade not null,
  created_at timestamp with time zone default now(),
  primary key (post_id, user_id)
);

-- 6. 关注关系表
create table if not exists public.follows (
  follower_id uuid references auth.users on delete cascade not null,
  following_id uuid references auth.users on delete cascade not null,
  created_at timestamp with time zone default now(),
  primary key (follower_id, following_id)
);

-- ============================================================
-- 第2步：索引
-- ============================================================
create index if not exists idx_manuscripts_user_id on public.manuscripts(user_id);
create index if not exists idx_manuscripts_type on public.manuscripts(type);
create index if not exists idx_manuscripts_public on public.manuscripts(is_public) where is_public = true;
create index if not exists idx_manuscripts_created_at on public.manuscripts(created_at desc);

create index if not exists idx_posts_user_id on public.posts(user_id);
create index if not exists idx_posts_created_at on public.posts(created_at desc);
create index if not exists idx_comments_post_id on public.comments(post_id);
create index if not exists idx_likes_post_id on public.likes(post_id);
create index if not exists idx_likes_user_id on public.likes(user_id);
create index if not exists idx_follows_follower on public.follows(follower_id);
create index if not exists idx_follows_following on public.follows(following_id);

-- ============================================================
-- 第3步：替换注册触发器（新版同时创建 user_settings）
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nickname)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nickname', split_part(new.email, '@', 1))
  );
  insert into public.user_settings (user_id) values (new.id);
  return new;
end;
$$;

-- 删旧建新（触发器名相同，会替换）
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 第4步：updated_at 自动维护触发器
-- ============================================================
create or replace function public.update_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_manuscripts_updated on public.manuscripts;
create trigger trg_manuscripts_updated
  before update on public.manuscripts
  for each row execute function public.update_updated_at();

drop trigger if exists trg_user_settings_updated on public.user_settings;
create trigger trg_user_settings_updated
  before update on public.user_settings
  for each row execute function public.update_updated_at();

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated
  before update on public.profiles
  for each row execute function public.update_updated_at();

-- ============================================================
-- 第5步：RLS 策略
-- （你原有的中文名策略不会被删，新策略是补充/替换）
-- ============================================================

-- === profiles（补充：已登录用户可读所有人，便于社交圈显示昵称） ===
alter table public.profiles enable row level security;
drop policy if exists "profiles_select_all" on public.profiles;
create policy "profiles_select_all"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

-- === manuscripts ===
alter table public.manuscripts enable row level security;

drop policy if exists "manuscripts_select_own_or_public" on public.manuscripts;
create policy "manuscripts_select_own_or_public"
  on public.manuscripts for select
  to authenticated
  using (auth.uid() = user_id or is_public = true);

drop policy if exists "manuscripts_insert_own" on public.manuscripts;
create policy "manuscripts_insert_own"
  on public.manuscripts for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "manuscripts_update_own" on public.manuscripts;
create policy "manuscripts_update_own"
  on public.manuscripts for update
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "manuscripts_delete_own" on public.manuscripts;
create policy "manuscripts_delete_own"
  on public.manuscripts for delete
  to authenticated
  using (auth.uid() = user_id);

-- === user_settings ===
alter table public.user_settings enable row level security;

drop policy if exists "settings_select_own" on public.user_settings;
create policy "settings_select_own"
  on public.user_settings for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "settings_insert_own" on public.user_settings;
create policy "settings_insert_own"
  on public.user_settings for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "settings_update_own" on public.user_settings;
create policy "settings_update_own"
  on public.user_settings for update
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "settings_delete_own" on public.user_settings;
create policy "settings_delete_own"
  on public.user_settings for delete
  to authenticated
  using (auth.uid() = user_id);

-- === posts ===
alter table public.posts enable row level security;

drop policy if exists "posts_select_all" on public.posts;
create policy "posts_select_all"
  on public.posts for select
  to authenticated
  using (true);

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own"
  on public.posts for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own"
  on public.posts for delete
  to authenticated
  using (auth.uid() = user_id);

-- === comments ===
alter table public.comments enable row level security;

drop policy if exists "comments_select_all" on public.comments;
create policy "comments_select_all"
  on public.comments for select
  to authenticated
  using (true);

drop policy if exists "comments_insert_own" on public.comments;
create policy "comments_insert_own"
  on public.comments for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "comments_delete_own" on public.comments;
create policy "comments_delete_own"
  on public.comments for delete
  to authenticated
  using (auth.uid() = user_id);

-- === likes ===
alter table public.likes enable row level security;

drop policy if exists "likes_select_all" on public.likes;
create policy "likes_select_all"
  on public.likes for select
  to authenticated
  using (true);

drop policy if exists "likes_insert_own" on public.likes;
create policy "likes_insert_own"
  on public.likes for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "likes_delete_own" on public.likes;
create policy "likes_delete_own"
  on public.likes for delete
  to authenticated
  using (auth.uid() = user_id);

-- === follows ===
alter table public.follows enable row level security;

drop policy if exists "follows_select_all" on public.follows;
create policy "follows_select_all"
  on public.follows for select
  to authenticated
  using (true);

drop policy if exists "follows_insert_own" on public.follows;
create policy "follows_insert_own"
  on public.follows for insert
  to authenticated
  with check (auth.uid() = follower_id);

drop policy if exists "follows_delete_own" on public.follows;
create policy "follows_delete_own"
  on public.follows for delete
  to authenticated
  using (auth.uid() = follower_id);

-- ============================================================
-- 第6步：点赞/评论计数触发器
-- ============================================================

-- 点赞 +1
create or replace function public.increment_likes_count()
returns trigger
language plpgsql
as $$
begin
  update public.posts set likes_count = likes_count + 1 where id = new.post_id;
  return new;
end;
$$;

drop trigger if exists trg_likes_insert on public.likes;
create trigger trg_likes_insert
  after insert on public.likes
  for each row execute function public.increment_likes_count();

-- 取消点赞 -1
create or replace function public.decrement_likes_count()
returns trigger
language plpgsql
as $$
begin
  update public.posts set likes_count = likes_count - 1 where id = old.post_id;
  return old;
end;
$$;

drop trigger if exists trg_likes_delete on public.likes;
create trigger trg_likes_delete
  after delete on public.likes
  for each row execute function public.decrement_likes_count();

-- 评论 +1
create or replace function public.increment_comments_count()
returns trigger
language plpgsql
as $$
begin
  update public.posts set comments_count = comments_count + 1 where id = new.post_id;
  return new;
end;
$$;

drop trigger if exists trg_comments_insert on public.comments;
create trigger trg_comments_insert
  after insert on public.comments
  for each row execute function public.increment_comments_count();

-- 删评论 -1
create or replace function public.decrement_comments_count()
returns trigger
language plpgsql
as $$
begin
  update public.posts set comments_count = comments_count - 1 where id = old.post_id;
  return old;
end;
$$;

drop trigger if exists trg_comments_delete on public.comments;
create trigger trg_comments_delete
  after delete on public.comments
  for each row execute function public.decrement_comments_count();

-- ============================================================
-- 第7步：实时订阅
-- ============================================================
alter publication supabase_realtime add table public.posts;
alter publication supabase_realtime add table public.comments;
alter publication supabase_realtime add table public.likes;

-- ============================================================
-- 完成
-- ============================================================
do $$
begin
  raise notice '✅ 增量迁移完成！';
  raise notice '   profiles 表已补全 nickname/bio/is_admin/updated_at 列';
  raise notice '   新增表：manuscripts, user_settings, posts, comments, likes, follows';
  raise notice '   所有触发器、RLS、实时订阅已就绪';
  raise notice '   你原有的 content 表和中文名策略保持不变，不受影响';
end;
$$;
