create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

drop policy if exists "admin_profiles_all" on public.profiles;
create policy "admin_profiles_all"
  on public.profiles
  for select
  to authenticated
  using ( public.is_admin() );

drop policy if exists "admin_manuscripts_all" on public.manuscripts;
create policy "admin_manuscripts_all"
  on public.manuscripts
  for select
  to authenticated
  using ( public.is_admin() );

drop policy if exists "admin_manuscripts_delete" on public.manuscripts;
create policy "admin_manuscripts_delete"
  on public.manuscripts
  for delete
  to authenticated
  using ( public.is_admin() );

drop policy if exists "admin_posts_delete" on public.posts;
create policy "admin_posts_delete"
  on public.posts
  for delete
  to authenticated
  using ( public.is_admin() );

drop policy if exists "admin_posts_update" on public.posts;
create policy "admin_posts_update"
  on public.posts
  for update
  to authenticated
  using ( public.is_admin() );

drop policy if exists "admin_comments_delete" on public.comments;
create policy "admin_comments_delete"
  on public.comments
  for delete
  to authenticated
  using ( public.is_admin() );

drop policy if exists "admin_settings_all" on public.user_settings;
create policy "admin_settings_select_all"
  on public.user_settings
  for select
  to authenticated
  using ( public.is_admin() );