// ============================================================
// Supabase 配置文件 — 青言青语Team
// 项目地址：https://pxvjconwixrntvyupzkw.supabase.co
// ============================================================

const SUPABASE_URL = 'https://pxvjconwixrntvyupzkw.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4dmpjb253aXhybnR2eXVwemt3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5NjM3MjAsImV4cCI6MjEwMTUzOTcyMH0.C2de-8czDJe0PhpxuNmnsik8hs88eQ1wgf00cuIo5Yk';

// 初始化 Supabase 客户端
let supabaseClient = null;

function initSupabase() {
  if (SUPABASE_URL === 'YOUR_PROJECT_URL_HERE' || SUPABASE_ANON_KEY === 'YOUR_ANON_KEY_HERE') {
    console.warn('[Supabase] 尚未配置，云端功能不可用。请在 supabase-config.js 中填入 URL 和 KEY。');
    return null;
  }
  if (typeof window !== 'undefined' && window.supabase) {
    supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true
      }
    });
    console.log('[Supabase] 初始化成功');
    return supabaseClient;
  }
  console.warn('[Supabase] SDK 未加载，请确保 CDN 脚本已引入');
  return null;
}

// ============================================================
// 认证相关函数
// ============================================================

// 获取当前用户
async function getCurrentUser() {
  if (!supabaseClient) return null;
  const { data: { user } } = await supabaseClient.auth.getUser();
  return user;
}

// 注册
async function signUp(email, password, nickname) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const { data, error } = await supabaseClient.auth.signUp({
    email: email,
    password: password,
    options: {
      data: { nickname: nickname || '' }
    }
  });
  return { data, error };
}

// 登录
async function signIn(email, password) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const { data, error } = await supabaseClient.auth.signInWithPassword({
    email: email,
    password: password
  });
  return { data, error };
}

// 退出登录
async function signOut() {
  if (!supabaseClient) return;
  await supabaseClient.auth.signOut();
}

// 更新昵称
async function updateNickname(nickname) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };
  const { error } = await supabaseClient
    .from('profiles')
    .update({ nickname: nickname })
    .eq('id', user.id);
  return { error };
}

// ============================================================
// 稿件云端同步
// ============================================================

// 保存稿件到云端
async function saveManuscriptToCloud(manuscript) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  const { data, error } = await supabaseClient
    .from('manuscripts')
    .insert({
      user_id: user.id,
      title: manuscript.title,
      content: manuscript.content,
      type: manuscript.type || 'drama',
      word_count: manuscript.content ? manuscript.content.length : 0,
      is_public: manuscript.is_public || false
    })
    .select();
  return { data, error };
}

// 更新云端稿件
async function updateManuscriptInCloud(id, updates) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const { data, error } = await supabaseClient
    .from('manuscripts')
    .update(updates)
    .eq('id', id)
    .select();
  return { data, error };
}

// 从云端删除稿件
async function deleteManuscriptFromCloud(id) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const { error } = await supabaseClient
    .from('manuscripts')
    .delete()
    .eq('id', id);
  return { error };
}

// 获取用户的云端稿件列表
async function fetchMyManuscripts() {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  const { data, error } = await supabaseClient
    .from('manuscripts')
    .select('id, title, content, type, word_count, is_public, created_at, updated_at')
    .eq('user_id', user.id)
    .order('updated_at', { ascending: false });
  return { data, error };
}

// 获取单篇云端稿件
async function fetchManuscriptById(id) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const { data, error } = await supabaseClient
    .from('manuscripts')
    .select('*')
    .eq('id', id)
    .single();
  return { data, error };
}

// ============================================================
// 用户设置同步
// ============================================================

// 同步设置到云端
async function syncSettingsToCloud(settings) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  const { error } = await supabaseClient
    .from('user_settings')
    .upsert({
      user_id: user.id,
      ai_settings: settings.aiSettings || {},
      quote_favs: settings.quoteFavs || [],
      custom_quotes: settings.customQuotes || [],
      wb_data: settings.wbData || {},
      updated_at: new Date().toISOString()
    });
  return { error };
}

// 从云端拉取设置
async function fetchSettingsFromCloud() {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  const { data, error } = await supabaseClient
    .from('user_settings')
    .select('*')
    .eq('user_id', user.id)
    .single();
  return { data, error };
}

// ============================================================
// 首次登录数据迁移
// ============================================================

// 将 localStorage 数据迁移到云端
async function migrateLocalDataToCloud() {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  // 1. 迁移设置
  const aiSettings = JSON.parse(localStorage.getItem('aiSettings') || '{}');
  const quoteFavs = JSON.parse(localStorage.getItem('quoteFavs') || '[]');
  const customQuotes = JSON.parse(localStorage.getItem('customQuotes') || '[]');
  const wbData = JSON.parse(localStorage.getItem('wbData') || '{}');

  await syncSettingsToCloud({ aiSettings, quoteFavs, customQuotes, wbData });

  // 2. 迁移稿件
  const myManuscripts = JSON.parse(localStorage.getItem('myManuscripts') || '[]');
  let migrated = 0;
  for (const ms of myManuscripts) {
    const { error } = await saveManuscriptToCloud({
      title: ms.title || '未命名',
      content: ms.content || '',
      type: ms.type || 'drama',
      is_public: false
    });
    if (!error) migrated++;
  }

  console.log(`[迁移完成] 稿件 ${migrated}/${myManuscripts.length} 篇，设置已同步`);
  return { migrated, total: myManuscripts.length };
}

// ============================================================
// 写作交流圈
// ============================================================

// 获取信息流帖子
async function fetchPosts(page, pageSize) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  page = page || 1;
  pageSize = pageSize || 20;

  // 1. 查询帖子（不依赖外键名）
  const { data: posts, error, count } = await supabaseClient
    .from('posts')
    .select('id, user_id, content, manuscript_id, images, likes_count, comments_count, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((page - 1) * pageSize, page * pageSize - 1);

  if (error) return { data: null, error, count };
  if (!posts || posts.length === 0) return { data: [], error: null, count: 0 };

  // 2. 单独查询作者昵称（避免外键关系名不匹配的问题）
  const userIds = [...new Set(posts.map(p => p.user_id))];
  const { data: profiles } = await supabaseClient
    .from('profiles')
    .select('id, nickname')
    .in('id', userIds);

  const profileMap = {};
  (profiles || []).forEach(p => { profileMap[p.id] = p; });

  // 3. 合并数据
  const enriched = posts.map(p => Object.assign({}, p, { profiles: profileMap[p.user_id] || null }));

  return { data: enriched, error: null, count };
}

// 获取单个帖子详情
async function fetchPostById(postId) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const { data: post, error } = await supabaseClient
    .from('posts')
    .select('id, user_id, content, manuscript_id, images, likes_count, comments_count, created_at')
    .eq('id', postId)
    .single();
  if (error) return { data: null, error };

  // 查询作者
  if (post) {
    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('id, nickname')
      .eq('id', post.user_id)
      .single();
    post.profiles = profile || null;
  }
  return { data: post, error: null };
}

// 上传图片到 Storage
async function uploadPostImage(file) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  const ext = file.name.split('.').pop().toLowerCase();
  const fileName = user.id + '/' + Date.now() + '_' + Math.random().toString(36).slice(2,8) + '.' + ext;

  const { data, error } = await supabaseClient
    .storage
    .from('community-images')
    .upload(fileName, file, { cacheControl: '3600', upsert: false });

  if (error) return { error };

  const { data: urlData } = supabaseClient
    .storage
    .from('community-images')
    .getPublicUrl(data.path);

  return { url: urlData.publicUrl, error: null };
}

// 发帖
async function createPost(content, manuscriptId, images) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  const { data, error } = await supabaseClient
    .from('posts')
    .insert({
      user_id: user.id,
      content: content,
      manuscript_id: manuscriptId || null,
      images: images || []
    })
    .select()
    .single();
  return { data, error };
}

// 删除帖子
async function deletePost(postId) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const { error } = await supabaseClient
    .from('posts')
    .delete()
    .eq('id', postId);
  return { error };
}

// 点赞（切换）
async function togglePostLike(postId) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  // 先检查是否已点赞
  const { data: existing } = await supabaseClient
    .from('likes')
    .select('post_id')
    .eq('post_id', postId)
    .eq('user_id', user.id)
    .single();

  if (existing) {
    // 已点赞 → 取消
    const { error } = await supabaseClient
      .from('likes')
      .delete()
      .eq('post_id', postId)
      .eq('user_id', user.id);
    return { liked: false, error };
  } else {
    // 未点赞 → 点赞
    const { error } = await supabaseClient
      .from('likes')
      .insert({
        post_id: postId,
        user_id: user.id
      });
    return { liked: true, error };
  }
}

// 检查当前用户是否已点赞某些帖子
async function checkLikedPosts(postIds) {
  if (!supabaseClient) return { data: [], error: null };
  const user = await getCurrentUser();
  if (!user) return { data: [], error: null };

  const { data, error } = await supabaseClient
    .from('likes')
    .select('post_id')
    .in('post_id', postIds)
    .eq('user_id', user.id);
  return { data, error };
}

// 获取帖子评论
async function fetchComments(postId) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  // 1. 查询评论
  const { data: comments, error } = await supabaseClient
    .from('comments')
    .select('id, post_id, user_id, content, created_at')
    .eq('post_id', postId)
    .order('created_at', { ascending: true });
  if (error) return { data: null, error };
  if (!comments || comments.length === 0) return { data: [], error: null };

  // 2. 查询评论者昵称
  const userIds = [...new Set(comments.map(c => c.user_id))];
  const { data: profiles } = await supabaseClient
    .from('profiles')
    .select('id, nickname')
    .in('id', userIds);

  const profileMap = {};
  (profiles || []).forEach(p => { profileMap[p.id] = p; });

  const enriched = comments.map(c => Object.assign({}, c, { profiles: profileMap[c.user_id] || null }));
  return { data: enriched, error: null };
}

// 发表评论
async function createComment(postId, content) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  // 1. 插入评论
  const { data: comment, error } = await supabaseClient
    .from('comments')
    .insert({
      post_id: postId,
      user_id: user.id,
      content: content
    })
    .select('id, post_id, user_id, content, created_at')
    .single();
  if (error) return { data: null, error };

  // 2. 补充作者昵称
  if (comment) {
    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('id, nickname')
      .eq('id', user.id)
      .single();
    comment.profiles = profile || null;
  }
  return { data: comment, error: null };
}

// 获取用户资料（含帖子数）
async function fetchUserProfile(userId) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const { data, error } = await supabaseClient
    .from('profiles')
    .select('id, nickname, avatar_url, bio, created_at')
    .eq('id', userId)
    .single();
  return { data, error };
}

// 关注/取消关注（切换）
async function toggleFollow(targetUserId) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const user = await getCurrentUser();
  if (!user) return { error: '未登录' };

  // 检查是否已关注
  const { data: existing } = await supabaseClient
    .from('follows')
    .select('follower_id')
    .eq('follower_id', user.id)
    .eq('following_id', targetUserId)
    .single();

  if (existing) {
    const { error } = await supabaseClient
      .from('follows')
      .delete()
      .eq('follower_id', user.id)
      .eq('following_id', targetUserId);
    return { following: false, error };
  } else {
    const { error } = await supabaseClient
      .from('follows')
      .insert({
        follower_id: user.id,
        following_id: targetUserId
      });
    return { following: true, error };
  }
}

// ============================================================
// 第三阶段：后台管理面板 API
// ============================================================

// 检查当前用户是否为管理员
async function checkIsAdmin() {
  if (!supabaseClient) return false;
  const user = await getCurrentUser();
  if (!user) return false;
  
  const { data, error } = await supabaseClient
    .from('profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single();
  
  if (error || !data) return false;
  return data.is_admin === true;
}

// 获取仪表盘统计数据
async function fetchDashboardStats() {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const results = {};
  
  // 用户总数
  const { count: totalUsers } = await supabaseClient
    .from('profiles').select('*', { count: 'exact', head: true });
  results.totalUsers = totalUsers || 0;
  
  // 帖子总数
  const { count: totalPosts } = await supabaseClient
    .from('posts').select('*', { count: 'exact', head: true });
  results.totalPosts = totalPosts || 0;
  
  // 评论总数
  const { count: totalComments } = await supabaseClient
    .from('comments').select('*', { count: 'exact', head: true });
  results.totalComments = totalComments || 0;
  
  // 稿件总数
  const { count: totalManuscripts } = await supabaseClient
    .from('manuscripts').select('*', { count: 'exact', head: true });
  results.totalManuscripts = totalManuscripts || 0;
  
  // 今日新增帖子
  const today = new Date().toISOString().split('T')[0];
  const { count: todayPosts } = await supabaseClient
    .from('posts').select('*', { count: 'exact', head: true })
    .gte('created_at', today);
  results.todayPosts = todayPosts || 0;
  
  // 今日新增用户
  const { count: todayUsers } = await supabaseClient
    .from('profiles').select('*', { count: 'exact', head: true })
    .gte('created_at', today);
  results.todayUsers = todayUsers || 0;
  
  return { data: results, error: null };
}

// 获取所有用户列表（管理员专用）
async function fetchAllUsers() {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  
  const { data: profiles, error: profileErr } = await supabaseClient
    .from('profiles')
    .select('id, nickname, is_admin, created_at')
    .order('created_at', { ascending: false });
  if (profileErr) return { data: null, error: profileErr };
  
  // 获取每个用户的帖子和稿件数量
  const enriched = [];
  for (const p of (profiles || [])) {
    const { count: postCount } = await supabaseClient
      .from('posts').select('*', { count: 'exact', head: true })
      .eq('user_id', p.id);
    const { count: msCount } = await supabaseClient
      .from('manuscripts').select('*', { count: 'exact', head: true })
      .eq('user_id', p.id);
    enriched.push({
      id: p.id,
      nickname: p.nickname,
      is_admin: p.is_admin,
      created_at: p.created_at,
      post_count: postCount || 0,
      manuscript_count: msCount || 0
    });
  }
  return { data: enriched, error: null };
}

// 切换用户管理员状态（直接 update，RLS 策略会阻止非管理员操作）
async function toggleUserAdmin(userId, makeAdmin) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  const { error } = await supabaseClient
    .from('profiles')
    .update({ is_admin: makeAdmin, updated_at: new Date().toISOString() })
    .eq('id', userId);
  return { error };
}

// 管理员删除帖子
async function adminDeletePost(postId) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  
  const { error } = await supabaseClient
    .from('posts')
    .delete()
    .eq('id', postId);
  return { error };
}

// 管理员删除评论
async function adminDeleteComment(commentId) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  
  const { error } = await supabaseClient
    .from('comments')
    .delete()
    .eq('id', commentId);
  return { error };
}

// 获取所有帖子（管理员视角，含作者信息）
async function adminFetchAllPosts(page, pageSize) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  page = page || 1;
  pageSize = pageSize || 20;
  
  const { data: posts, error, count } = await supabaseClient
    .from('posts')
    .select('id, user_id, content, images, likes_count, comments_count, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((page - 1) * pageSize, page * pageSize - 1);
  
  if (error) return { data: null, error, count };
  if (!posts || posts.length === 0) return { data: [], count: 0, error: null };
  
  // 查询作者
  const userIds = [...new Set(posts.map(p => p.user_id))];
  const { data: profiles } = await supabaseClient
    .from('profiles')
    .select('id, nickname')
    .in('id', userIds);
  
  const profileMap = {};
  (profiles || []).forEach(p => { profileMap[p.id] = p; });
  
  const enriched = posts.map(p => Object.assign({}, p, { profiles: profileMap[p.user_id] || null }));
  return { data: enriched, count, error: null };
}

// 管理员获取所有评论（含帖子和作者信息）
async function adminFetchAllComments(page, pageSize) {
  if (!supabaseClient) return { error: 'Supabase 未初始化' };
  page = page || 1;
  pageSize = pageSize || 30;
  
  const { data: comments, error, count } = await supabaseClient
    .from('comments')
    .select('id, post_id, user_id, content, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((page - 1) * pageSize, page * pageSize - 1);
  
  if (error) return { data: null, error, count };
  if (!comments || comments.length === 0) return { data: [], count: 0, error: null };
  
  // 查询作者和帖子内容摘要
  const userIds = [...new Set(comments.map(c => c.user_id))];
  const postIds = [...new Set(comments.map(c => c.post_id))];
  
  const [{ data: profiles }, { data: posts }] = await Promise.all([
    supabaseClient.from('profiles').select('id, nickname').in('id', userIds),
    supabaseClient.from('posts').select('id, content').in('id', postIds)
  ]);
  
  const profileMap = {}; (profiles || []).forEach(p => { profileMap[p.id] = p; });
  const postMap = {}; (posts || []).forEach(p => { postMap[p.id] = p; });
  
  const enriched = comments.map(c => Object.assign({}, c, {
    profiles: profileMap[c.user_id] || null,
    post_title: (postMap[c.post_id] || {}).content ? (postMap[c.post_id].content || '').substring(0, 40) + '...' : '(帖子已删除)'
  }));
  
  return { data: enriched, count, error: null };
}
