import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { scoreRepository, type GitHubRepository } from './scoring.ts';

const topics = ['artificial-intelligence', 'llm', 'generative-ai', 'agent'];
const githubApi = 'https://api.github.com';
const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, apikey, content-type, x-cron-secret',
};

function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

async function searchTopic(topic: string, token: string): Promise<GitHubRepository[]> {
  const since = new Date(Date.now() - 7 * 86_400_000).toISOString().slice(0, 10);
  const query = encodeURIComponent(`topic:${topic} pushed:>=${since}`);
  const headers = {
    accept: 'application/vnd.github+json',
    authorization: `Bearer ${token}`,
    'x-github-api-version': '2022-11-28',
    'user-agent': 'focus-flow-github-digest',
  };
  let response: Response | undefined;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    response = await fetch(`${githubApi}/search/repositories?q=${query}&sort=stars&order=desc&per_page=20`, { headers });
    if (response.ok) break;
    if (![429, 500, 502, 503, 504].includes(response.status)) break;
    const retryAfter = Number(response.headers.get('retry-after') ?? 0);
    const waitMs = Math.min(8000, Math.max(500, retryAfter * 1000 || 2 ** attempt * 1000));
    await new Promise((resolve) => setTimeout(resolve, waitMs));
  }
  if (!response?.ok) throw new Error(`GitHub search failed with ${response?.status ?? 'no response'}`);
  const payload = await response.json();
  return payload.items ?? [];
}

export async function buildDigest(token: string, now = new Date()) {
  const found = await Promise.all(topics.map(async (topic) => ({ topic, repositories: await searchTopic(topic, token) })));
  const unique = new Map<string, { repository: GitHubRepository; tags: Set<string> }>();
  for (const result of found) {
    for (const repository of result.repositories) {
      const existing = unique.get(repository.full_name);
      if (existing) existing.tags.add(result.topic);
      else unique.set(repository.full_name, { repository, tags: new Set([result.topic]) });
    }
  }

  return [...unique.values()]
    .map(({ repository, tags }) => ({
      repository_full_name: repository.full_name,
      title: repository.name,
      summary: repository.description ?? '暂无项目描述',
      source_url: repository.html_url,
      tags: [...tags],
      stars: repository.stargazers_count,
      forks: repository.forks_count,
      score: scoreRepository(repository, now),
      published_at: repository.pushed_at ?? repository.created_at,
      fetched_at: now.toISOString(),
      summary_version: 'raw-description',
    }))
    .sort((left, right) => right.score - left.score)
    .slice(0, 50);
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Missing Supabase configuration' }, 500);
  }
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  if (request.method === 'GET') {
    const { data, error } = await supabase
      .from('news_items')
      .select('repository_full_name,title,summary,source_url,tags,stars,forks,score,published_at,fetched_at,summary_version')
      .order('score', { ascending: false })
      .limit(50);
    if (error) return jsonResponse({ error: 'Unable to load digest' }, 502);
    return jsonResponse({ items: data ?? [] });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Use GET or POST' }, 405);
  }
  const cronSecret = Deno.env.get('CRON_SECRET');
  if (!cronSecret || request.headers.get('x-cron-secret') !== cronSecret) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const token = Deno.env.get('GITHUB_TOKEN');
  if (!token) return jsonResponse({ error: 'Missing GitHub configuration' }, 500);

  try {
    const digest = await buildDigest(token);
    const { error } = await supabase.from('news_items').upsert(digest, { onConflict: 'repository_full_name', ignoreDuplicates: false });
    if (error) throw error;
    return jsonResponse({ inserted: digest.length, items: digest });
  } catch (error) {
    console.error('github-digest failed', error);
    return jsonResponse({ error: 'GitHub digest failed' }, 502);
  }
});
