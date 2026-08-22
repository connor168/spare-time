import { describe, expect, it } from 'vitest';
import { fetchGitHubDigest } from '../src/news_digest.js';

describe('GitHub daily digest', () => {
  it('normalizes and ranks repository results', async () => {
    const result = await fetchGitHubDigest(null, new Date('2026-08-22T00:00:00Z'), async () => new Response(JSON.stringify({
      items: [
        { full_name: 'owner/low', name: 'low', html_url: 'https://github.com/owner/low', stargazers_count: 100, forks_count: 0, topics: ['one'] },
        { full_name: 'owner/high', name: 'high', html_url: 'https://github.com/owner/high', stargazers_count: 500, forks_count: 20, description: 'A project', topics: ['two'] },
      ],
    }), { status: 200 }));
    expect(result).toHaveLength(2);
    expect(result[0].repositoryFullName).toBe('owner/high');
    expect(result[0].score).toBe(510);
  });
});
