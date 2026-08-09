export type GitHubRepository = {
  full_name: string;
  name: string;
  html_url: string;
  description: string | null;
  stargazers_count: number;
  forks_count: number;
  pushed_at: string | null;
  created_at: string;
};

export function scoreRepository(repository: GitHubRepository, now = new Date()): number {
  const pushedAt = repository.pushed_at ? new Date(repository.pushed_at).getTime() : now.getTime();
  const ageDays = Math.max(0, (now.getTime() - pushedAt) / 86_400_000);
  const freshness = Math.max(0, 30 - ageDays) * 2;
  const popularity = Math.log10(repository.stargazers_count + 1) * 12;
  const collaboration = Math.log10(repository.forks_count + 1) * 4;
  return Number((freshness + popularity + collaboration).toFixed(4));
}
