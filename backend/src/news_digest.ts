import type pg from 'pg';

export type GitHubRepository = {
  full_name?: unknown;
  html_url?: unknown;
  name?: unknown;
  description?: unknown;
  topics?: unknown;
  stargazers_count?: unknown;
  forks_count?: unknown;
  pushed_at?: unknown;
  created_at?: unknown;
};

export type NewsDigestItem = {
  repositoryFullName: string;
  title: string;
  summary: string;
  sourceUrl: string;
  tags: string[];
  stars: number;
  forks: number;
  score: number;
  publishedAt: string | null;
};

type GitHubResponse = { items?: GitHubRepository[] };
type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

const githubApi = 'https://api.github.com/search/repositories';

export async function fetchGitHubDigest(
  token: string | null,
  now = new Date(),
  fetcher: FetchLike = fetch,
): Promise<NewsDigestItem[]> {
  const headers: Record<string, string> = {
    accept: 'application/vnd.github+json',
    'user-agent': 'focus-flow-news-digest',
    'x-github-api-version': '2022-11-28',
  };
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetcher(`${githubApi}?q=stars:%3E100&sort=updated&order=desc&per_page=50`, { headers });
  if (!response.ok) throw new Error(`GitHub API returned ${response.status}`);
  const payload = await response.json() as GitHubResponse;
  const items = payload.items ?? [];
  return items
    .map(toDigestItem)
    .filter((item): item is NewsDigestItem => item !== null)
    .sort((left, right) => right.score - left.score)
    .slice(0, 50);
}

export async function refreshGitHubDigest(
  pool: pg.Pool,
  token: string | null,
  now = new Date(),
  fetcher: FetchLike = fetch,
): Promise<number> {
  const items = await fetchGitHubDigest(token, now, fetcher);
  const digestDate = shanghaiDate(now);
  const client = await pool.connect();
  try {
    await client.query('begin');
    for (const item of items) {
      await client.query(
        `insert into news_items
          (id, source, source_url, title, summary, language, published_at, fetched_at,
           repository_full_name, tags, stars, forks, score, summary_version, category, digest_date)
         values (gen_random_uuid(), 'github', $1, $2, $3, 'en', $4, now(), $5, $6, $7, $8, $9, 'github-description', 'repository', $10)
         on conflict (source, source_url) do update set
           title = excluded.title, summary = excluded.summary, published_at = excluded.published_at,
           fetched_at = now(), repository_full_name = excluded.repository_full_name,
           tags = excluded.tags, stars = excluded.stars, forks = excluded.forks, score = excluded.score,
           summary_version = excluded.summary_version, category = excluded.category, digest_date = excluded.digest_date`,
        [item.sourceUrl, item.title, item.summary, item.publishedAt, item.repositoryFullName,
          JSON.stringify(item.tags), item.stars, item.forks, item.score, digestDate],
      );
    }
    await client.query('commit');
    return items.length;
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    client.release();
  }
}

function toDigestItem(repository: GitHubRepository): NewsDigestItem | null {
  const fullName = stringValue(repository.full_name);
  const sourceUrl = stringValue(repository.html_url);
  if (!fullName || !sourceUrl) return null;
  const stars = numberValue(repository.stargazers_count);
  const forks = numberValue(repository.forks_count);
  const tags = Array.isArray(repository.topics)
    ? repository.topics.filter((tag): tag is string => typeof tag === 'string').slice(0, 8)
    : [];
  const description = stringValue(repository.description);
  return {
    repositoryFullName: fullName,
    title: stringValue(repository.name) || fullName,
    summary: description,
    sourceUrl,
    tags,
    stars,
    forks,
    score: stars + forks * 0.5,
    publishedAt: stringValue(repository.pushed_at) || stringValue(repository.created_at) || null,
  };
}

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function numberValue(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0;
}

export function shanghaiDate(value: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(value);
}
