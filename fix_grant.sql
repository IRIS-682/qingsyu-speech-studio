-- ============================================================
-- 强制 GRANT 权限修复（关键！）
-- ============================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated;

-- 验证：应该看到 anon 和 authenticated 都有 INSERT/SELECT 等权限
SELECT 
  table_name,
  grantee,
  string_agg(privilege_type, ', ' ORDER BY privilege_type) as privileges
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('manuscripts', 'user_settings', 'profiles')
GROUP BY table_name, grantee
ORDER BY table_name, grantee;