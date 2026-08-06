-- ============================================================
-- 青言青语 — 云端稿件读写修复脚本
-- 在 Supabase Dashboard → SQL Editor 执行
-- 解决 403 错误 + 补全缺失的 user_settings 记录
-- ============================================================

-- 第1步：诊断 — 查看现有 RLS 策略状态（执行后看 Results 标签的输出）
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename IN ('manuscripts', 'user_settings')
ORDER BY tablename, cmd, policyname;

-- 第2步：彻底删除并重建所有相关 RLS 策略
DROP POLICY IF EXISTS "manuscripts_select_own_or_public" ON public.manuscripts;
DROP POLICY IF EXISTS "manuscripts_insert_own" ON public.manuscripts;
DROP POLICY IF EXISTS "manuscripts_update_own" ON public.manuscripts;
DROP POLICY IF EXISTS "manuscripts_delete_own" ON public.manuscripts;
DROP POLICY IF EXISTS "manuscripts_public_read" ON public.manuscripts;

CREATE POLICY "manuscripts_select_own_or_public"
  ON public.manuscripts FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR is_public = true);

CREATE POLICY "manuscripts_insert_own"
  ON public.manuscripts FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "manuscripts_update_own"
  ON public.manuscripts FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "manuscripts_delete_own"
  ON public.manuscripts FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- user_settings：合并为单一 ALL 策略，更可靠
DROP POLICY IF EXISTS "settings_select_own" ON public.user_settings;
DROP POLICY IF EXISTS "settings_insert_own" ON public.user_settings;
DROP POLICY IF EXISTS "settings_update_own" ON public.user_settings;
DROP POLICY IF EXISTS "settings_delete_own" ON public.user_settings;
DROP POLICY IF EXISTS "settings_all" ON public.user_settings;

CREATE POLICY "settings_all"
  ON public.user_settings FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 确保 RLS 已启用
ALTER TABLE public.manuscripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- 第3步：给已有用户补建 user_settings 记录
-- （新 trigger 只会管新用户，已有用户需要手动补）
INSERT INTO public.user_settings (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM public.user_settings)
ON CONFLICT (user_id) DO NOTHING;

-- 第4步：验证 — 再次查看策略（应该看到 5 条 manuscripts 策略 + 1 条 settings_all）
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename IN ('manuscripts', 'user_settings')
ORDER BY tablename, cmd, policyname;

-- 第5步：验证 — 应该返回 1（表示 RLS 启用）
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename IN ('manuscripts', 'user_settings');

-- ============================================================
-- 完成
-- ============================================================
DO $$
DECLARE
  user_count INTEGER;
  settings_count INTEGER;
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM auth.users;
  SELECT COUNT(*) INTO settings_count FROM public.user_settings;
  SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename IN ('manuscripts', 'user_settings');

  RAISE NOTICE '✅ 修复完成';
  RAISE NOTICE '   auth.users 总数: %', user_count;
  RAISE NOTICE '   user_settings 总数: % （应该等于用户数）';
  RAISE NOTICE '   有效策略总数: % （manuscripts 应有 4 条，user_settings 应有 1 条）';
END;
$$;