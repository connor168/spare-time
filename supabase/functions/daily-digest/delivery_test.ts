import { dueDigestKey } from './delivery.ts';

const preference = {
  timezone_id: 'Asia/Tokyo',
  digest_time: '08:00:00',
  quiet_start: null,
  quiet_end: null,
};

Deno.test('digest is due in the user local delivery window', () => {
  const key = dueDigestKey(preference, new Date('2026-08-07T23:05:00Z'));
  if (key !== '2026-08-08') throw new Error(`Unexpected digest key: ${key}`);
});

Deno.test('digest is not due before the local delivery window', () => {
  const key = dueDigestKey(preference, new Date('2026-08-07T22:59:00Z'));
  if (key !== null) throw new Error(`Expected no digest, received: ${key}`);
});

Deno.test('digest inside overnight quiet hours is deferred to quiet end', () => {
  const quietPreference = {
    ...preference,
    digest_time: '23:00:00',
    quiet_start: '22:00:00',
    quiet_end: '07:00:00',
  };
  const key = dueDigestKey(quietPreference, new Date('2026-08-07T22:05:00Z'));
  if (key !== '2026-08-07') throw new Error(`Unexpected digest key: ${key}`);
});

Deno.test('invalid time zones do not trigger delivery', () => {
  const key = dueDigestKey(
    { ...preference, timezone_id: 'Invalid/Zone' },
    new Date('2026-08-07T23:05:00Z'),
  );
  if (key !== null) throw new Error(`Expected no digest, received: ${key}`);
});
