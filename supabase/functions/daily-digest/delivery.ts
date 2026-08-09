export type DeliveryPreference = {
  timezone_id: string;
  digest_time: string;
  quiet_start: string | null;
  quiet_end: string | null;
};

type LocalClock = {
  dateKey: string;
  minuteOfDay: number;
};

function parseTime(value: string | null): number | null {
  if (!value) return null;
  const match = /^(\d{1,2}):(\d{2})/.exec(value);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

function localClock(now: Date, timeZone: string): LocalClock | null {
  try {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(now);
    const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return {
      dateKey: `${values.year}-${values.month}-${values.day}`,
      minuteOfDay: Number(values.hour) * 60 + Number(values.minute),
    };
  } catch {
    return null;
  }
}

function previousDateKey(dateKey: string): string {
  const date = new Date(`${dateKey}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() - 1);
  return date.toISOString().slice(0, 10);
}

function effectiveDeliveryMinute(preference: DeliveryPreference): {
  minute: number;
  nextDay: boolean;
} | null {
  const digest = parseTime(preference.digest_time);
  if (digest === null) return null;
  const quietStart = parseTime(preference.quiet_start);
  const quietEnd = parseTime(preference.quiet_end);
  if (quietStart === null || quietEnd === null || quietStart === quietEnd) {
    return { minute: digest, nextDay: false };
  }

  const wrapsMidnight = quietStart > quietEnd;
  const isQuiet = wrapsMidnight
    ? digest >= quietStart || digest < quietEnd
    : digest >= quietStart && digest < quietEnd;
  if (!isQuiet) return { minute: digest, nextDay: false };
  return {
    minute: quietEnd,
    nextDay: wrapsMidnight && digest >= quietStart,
  };
}

export function dueDigestKey(
  preference: DeliveryPreference,
  now = new Date(),
  windowMinutes = 15,
): string | null {
  const clock = localClock(now, preference.timezone_id);
  const delivery = effectiveDeliveryMinute(preference);
  if (!clock || !delivery || windowMinutes < 1) return null;

  const end = delivery.minute + windowMinutes;
  const insideWindow = end <= 1440
    ? clock.minuteOfDay >= delivery.minute && clock.minuteOfDay < end
    : clock.minuteOfDay >= delivery.minute || clock.minuteOfDay < end - 1440;
  if (!insideWindow) return null;

  const deliveredAfterMidnight = end > 1440 && clock.minuteOfDay < end - 1440;
  return delivery.nextDay || deliveredAfterMidnight
    ? previousDateKey(clock.dateKey)
    : clock.dateKey;
}
