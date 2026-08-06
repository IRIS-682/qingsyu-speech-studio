-- ============================================================
-- 交流圈图片功能 — Storage 策略
-- 在 Supabase SQL Editor 执行
-- ============================================================

-- 允许已登录用户上传图片
CREATE POLICY "community_images_upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'community-images');

-- 允许所有人读取（公开图片）
CREATE POLICY "community_images_read"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'community-images');

-- 允许用户删除自己上传的图片
CREATE POLICY "community_images_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'community-images' AND owner = auth.uid());
