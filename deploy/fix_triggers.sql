-- ============================================================
-- 交流圈诊断 — trigger 和数字一致性检查
-- ============================================================

-- 1. 检查所有 trigger 是否存在
SELECT trigger_name, event_manipulation, event_object_table, action_timing
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table IN ('posts', 'comments', 'likes')
ORDER BY event_object_table, trigger_name;

-- 2. 检查 posts 表的 likes_count 和 comments_count 实际值
SELECT id, substring(content, 1, 30) as preview, likes_count, comments_count, created_at
FROM public.posts
ORDER BY created_at DESC
LIMIT 5;

-- 3. 实际计数 vs 字段值
SELECT
  p.id,
  substring(p.content, 1, 30) as preview,
  p.likes_count as field_likes,
  (SELECT count(*) FROM public.likes WHERE post_id = p.id) as actual_likes,
  p.comments_count as field_comments,
  (SELECT count(*) FROM public.comments WHERE post_id = p.id) as actual_comments
FROM public.posts p
ORDER BY p.created_at DESC
LIMIT 5;

-- ============================================================
-- 如果 trigger 缺失或数字不一致，执行下面的修复：
-- ============================================================

-- 重新创建 trigger（每次都重建，安全）
CREATE OR REPLACE FUNCTION public.increment_likes_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_likes_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_comments_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.decrement_comments_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_likes_insert ON public.likes;
CREATE TRIGGER trg_likes_insert AFTER INSERT ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.increment_likes_count();

DROP TRIGGER IF EXISTS trg_likes_delete ON public.likes;
CREATE TRIGGER trg_likes_delete AFTER DELETE ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.decrement_likes_count();

DROP TRIGGER IF EXISTS trg_comments_insert ON public.comments;
CREATE TRIGGER trg_comments_insert AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.increment_comments_count();

DROP TRIGGER IF EXISTS trg_comments_delete ON public.comments;
CREATE TRIGGER trg_comments_delete AFTER DELETE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.decrement_comments_count();

-- 把数字字段与实际计数同步
UPDATE public.posts p SET
  likes_count = COALESCE((SELECT count(*) FROM public.likes WHERE post_id = p.id), 0),
  comments_count = COALESCE((SELECT count(*) FROM public.comments WHERE post_id = p.id), 0);