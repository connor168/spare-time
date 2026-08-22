alter table news_items add column if not exists repository_full_name text not null default '';
alter table news_items add column if not exists tags jsonb not null default '[]'::jsonb;
alter table news_items add column if not exists stars integer not null default 0;
alter table news_items add column if not exists forks integer not null default 0;
alter table news_items add column if not exists score double precision not null default 0;
alter table news_items add column if not exists summary_version text not null default 'raw-description';
alter table news_items add column if not exists category text not null default 'github';
alter table news_items add column if not exists digest_date date not null default current_date;

create unique index if not exists news_items_digest_url_idx on news_items(digest_date, source_url);
create index if not exists news_items_digest_score_idx on news_items(digest_date, score desc);

create table if not exists daily_digest_deliveries (
  digest_date date not null,
  device_token_id uuid not null references device_tokens(id) on delete cascade,
  sent_at timestamptz not null default now(),
  primary key (digest_date, device_token_id)
);
