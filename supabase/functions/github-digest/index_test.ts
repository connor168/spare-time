import { scoreRepository } from './scoring.ts';

const baseRepository = {
  full_name: 'example/ai-project',
  name: 'ai-project',
  html_url: 'https://github.com/example/ai-project',
  description: 'An AI project',
  stargazers_count: 1000,
  forks_count: 100,
  pushed_at: '2026-08-06T00:00:00Z',
  created_at: '2026-07-01T00:00:00Z',
};

Deno.test('fresh repositories receive a positive score', () => {
  const score = scoreRepository(baseRepository, new Date('2026-08-07T00:00:00Z'));
  if (score <= 0) throw new Error('Expected a positive score for a fresh repository.');
});

Deno.test('recent activity matters more than an otherwise equal stale project', () => {
  const recent = scoreRepository(baseRepository, new Date('2026-08-07T00:00:00Z'));
  const stale = scoreRepository({ ...baseRepository, pushed_at: '2026-06-01T00:00:00Z' }, new Date('2026-08-07T00:00:00Z'));
  if (recent <= stale) throw new Error('Expected recent activity to increase the score.');
});
