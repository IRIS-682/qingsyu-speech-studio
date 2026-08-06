-- ============================================================
-- 青言青语 — 深度诊断 + 修复 403 错误
-- 在 Supabase SQL Editor 执行
-- ============================================================

-- 第1步：检查 GRANT 权限（最容易忽略的坑！Supabase 表的访问权限）
SELECT 
  grantee, 
  string_agg(privilege_type, ', ') as privileges
FROM information_schema.role_table_grants 
WHERE table_schema = 'public' 
  AND table_name IN ('manuscripts', 'user_settings')
GROUP BY grantee
ORDER BY grantee;

-- 第2步：检查 anon 和 authenticated 角色对 manuscripts 的具体权限
SELECT 
  has_table_privilege('anon', 'public.manuscripts', 'SELECT') as anon_can_select,
  has_table_privilege('anon', 'public.manuscripts', 'INSERT') as anon_can_insert,
  has_table_privilege('authenticated', 'public.manuscripts', 'SELECT') as auth_can_select,
  has_table_privilege('authenticated', 'public.manuscripts', 'INSERT') as auth_can_insert,
  has_table_privilege('authenticated', 'public.manuscripts', 'UPDATE') as auth_can_update,
  has_table_privilege('authenticated', 'public.manuscripts', 'DELETE') as auth_can_delete;

-- 第3步：检查 user_settings 同上
SELECT 
  has_table_privilege('authenticated', 'public.user_settings', 'SELECT') as auth_can_select,
  has_table_privilege('authenticated', 'public.user_settings', 'INSERT') as auth_can_insert,
  has_table_privilege('authenticated', 'public.user_settings', 'UPDATE') as auth_can_update,
  has_table_privilege('authenticated', 'public.user_settings', 'DELETE') as auth_can_delete;

-- 第4步：检查 auth.users 中已注册用户
SELECT id, email, created_at FROM auth.users;

-- 第5步：检查 profiles 表里的 user_id 是否存在
SELECT id, nickname, email FROM public.profiles LIMIT 5;

-- 第6步：模拟测试 — 用 service_role 模拟 authenticated 用户查询
-- （这条只是诊断，不会真的修改数据）
DO $$
DECLARE
  test_uid UUID;
  test_count INTEGER;
BEGIN
  -- 取第一个用户的 ID
  SELECT id INTO test_uid FROM auth.users LIMIT 1;
  IF test_uid IS NULL THEN
    RAISE NOTICE '❌ auth.users 表为空，请先注册用户';
    RETURN;
  END IF;
  
  RAISE NOTICE '测试用户 ID: %', test_uid;
  
  -- 用 SECURITY DEFINER 函数模拟查询
  PERFORM set_config('request.jwt.claim.sub', test_uid::text, true);
  
  SELECT COUNT(*) INTO test_count FROM public.manuscripts WHERE user_id = test_uid;
  RAISE NOTICE '该用户的 manuscripts 数量: %', test_count;
  
  SELECT COUNT(*) INTO test_count FROM public.user_settings WHERE user_id = test_uid;
  RAISE NOTICE '该用户的 user_settings 数量: %', test_count;
END;
$$;

-- ============================================================
-- 第7步（如果上面都正常）：尝试禁用 RLS 测试
-- 如果禁用后 403 消失，说明 RLS 策略配置错误
-- 如果还在 403，说明是 GRANT 权限问题（运行第8步）
-- ============================================================

-- 第8步（备用）：强制 GRANT 权限
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated;

-- ============================================================
-- 完成
-- ============================================================
DO $$
BEGIN
  RAISE NOTICE '✅ 诊断完成 — 请把全部 Results 输出截图给我';
END;
$$;