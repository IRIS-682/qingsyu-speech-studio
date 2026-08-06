-- ============================================================
-- 青言青语 SaaS 平台 — 后台管理 RLS 策略
-- 在 Supabase Dashboard → SQL Editor 中粘贴执行
-- ============================================================

-- ============================================================
-- 1. 管理员权限函数：检测当前用户是否为 admin
-- ============================================================
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- ============================================================
-- 2. Admin 切换函数（由 Super Admin 手动执行，或 RLS 保护）
-- ============================================================
create or replace function public.toggle_admin(target_user_id uuid, make_admin boolean)
returns boolean
language plpgsql
security definer
as $$
begin
  -- 只有当前用户是 admin 才能操作
  if not (select coalesce(is_admin, false) from public.profiles where id = auth.uid()) then
    raise exception 'Permission denied: only admins can promote/demote users';
  end if;
  
  update public.profiles set is_admin = make_admin, updated_at = now()
  where id = target_user_id;
  
  return found;
end;
$$;

-- ============================================================
-- 3. Admin RLS 策略 — profiles
-- ============================================================
drop policy if exists "admin_profiles_all" on public.profiles;
create policy "admin_profiles_all"
  on public.profiles
  to authenticated
  using (public.is_admin());

-- ============================================================
-- 4. Admin RLS 策略 — manuscripts
-- ============================================================
drop policy if exists "admin_manuscripts_all" on public.manuscripts;
create policy "admin_manuscripts_all"
  on public.manuscripts for select
  to authenticated
  using (public.is_admin());

drop policy if exists "admin_manuscripts_delete" on public.manuscripts;
create policy "admin_manuscripts_delete"
  on public.manuscripts for delete
  to authenticated
  using (public.is_admin());

-- ============================================================
-- 5. Admin RLS 策略 — posts
-- ============================================================
drop policy if exists "admin_posts_delete" on public.posts;
create policy "admin_posts_delete"
  on public.posts for delete
  to authenticated
  using (public.is_admin());

drop policy if exists "admin_posts_update" on public.posts;
create policy "admin_posts_update"
  on public.posts for update
  to authenticated
  using (public.is_admin());

-- ============================================================
-- 6. Admin RLS 策略 — comments
-- ============================================================
drop policy if exists "admin_comments_delete" on public.comments;
create policy "admin_comments_delete"
  on public.comments for delete
  to authenticated
  using (public.is_admin());

-- ============================================================
-- 7. Admin RLS 策略 — user_settings
-- ============================================================
drop policy if exists "admin_settings_all" on public.user_settings;
create policy "admin_settings_select_all"
  on public.user_settings for select
  to authenticated
  using (public.is_admin());

-- ============================================================
-- 完成提示
-- ============================================================
do $$
begin
  raise notice '✅ Admin RLS 策略创建完成！is_admin() 函数、toggle_admin() 函数已就绪。';
end;
$$;
