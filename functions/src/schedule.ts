export const WEEKDAY_LABELS = [
  "Mon",
  "Tue",
  "Wed",
  "Thu",
  "Fri",
  "Sat",
  "Sun",
] as const;

const DAY_ALIASES: Record<string, string> = {
  mon: "Mon",
  monday: "Mon",
  tue: "Tue",
  tues: "Tue",
  tuesday: "Tue",
  wed: "Wed",
  wednesday: "Wed",
  thu: "Thu",
  thur: "Thu",
  thurs: "Thu",
  thursday: "Thu",
  fri: "Fri",
  friday: "Fri",
  sat: "Sat",
  saturday: "Sat",
  sun: "Sun",
  sunday: "Sun",
};

export function normalizeDay(raw: unknown): string | null {
  if (raw == null) return null;
  const value = String(raw).trim();
  if (!value) return null;
  if ((WEEKDAY_LABELS as readonly string[]).includes(value)) return value;
  return DAY_ALIASES[value.toLowerCase()] ?? null;
}

export function normalizeDays(days: unknown): Set<string> {
  const result = new Set<string>();
  if (!Array.isArray(days)) return result;
  for (const day of days) {
    const normalized = normalizeDay(day);
    if (normalized) result.add(normalized);
  }
  return result;
}

export function isOneTime(days: unknown): boolean {
  return normalizeDays(days).size === 0;
}

export function weekdayLabel(date: Date): string {
  const jsDay = date.getUTCDay();
  const mondayBased = jsDay === 0 ? 6 : jsDay - 1;
  return WEEKDAY_LABELS[mondayBased];
}

export function pad(value: number): string {
  return String(value).padStart(2, "0");
}

export function executionKey(wallAsUtcFields: Date): string {
  return `${wallAsUtcFields.getUTCFullYear()}-${pad(wallAsUtcFields.getUTCMonth() + 1)}-${pad(wallAsUtcFields.getUTCDate())}-${pad(wallAsUtcFields.getUTCHours())}-${pad(wallAsUtcFields.getUTCMinutes())}`;
}

/**
 * Shift a UTC instant into a "wall clock" Date using a fixed offset (minutes east of UTC).
 * getFullYear/getHours then return that local wall time (via UTC getters).
 */
export function toOffsetWallClock(utc: Date, offsetMinutes: number): Date {
  return new Date(utc.getTime() + offsetMinutes * 60_000);
}

export function fromOffsetWallClock(wall: Date, offsetMinutes: number): Date {
  return new Date(wall.getTime() - offsetMinutes * 60_000);
}

export function computeNextRunAt(params: {
  hour: number;
  minute: number;
  days: unknown;
  fromUtc: Date;
  offsetMinutes: number;
}): Date {
  const hour = Math.min(23, Math.max(0, params.hour));
  const minute = Math.min(59, Math.max(0, params.minute));
  const allowed = normalizeDays(params.days);
  const fromWall = toOffsetWallClock(params.fromUtc, params.offsetMinutes);

  let candidate = new Date(Date.UTC(
    fromWall.getUTCFullYear(),
    fromWall.getUTCMonth(),
    fromWall.getUTCDate(),
    hour,
    minute,
    0,
    0,
  ));

  if (!(candidate.getTime() > fromWall.getTime())) {
    candidate = new Date(candidate.getTime() + 24 * 60 * 60 * 1000);
    candidate = new Date(Date.UTC(
      candidate.getUTCFullYear(),
      candidate.getUTCMonth(),
      candidate.getUTCDate(),
      hour,
      minute,
      0,
      0,
    ));
  }

  if (allowed.size === 0) {
    return fromOffsetWallClock(candidate, params.offsetMinutes);
  }

  for (let i = 0; i < 8; i++) {
    const label = WEEKDAY_LABELS[(candidate.getUTCDay() === 0 ? 6 : candidate.getUTCDay() - 1)];
    if (allowed.has(label)) {
      return fromOffsetWallClock(candidate, params.offsetMinutes);
    }
    candidate = new Date(candidate.getTime() + 24 * 60 * 60 * 1000);
    candidate = new Date(Date.UTC(
      candidate.getUTCFullYear(),
      candidate.getUTCMonth(),
      candidate.getUTCDate(),
      hour,
      minute,
      0,
      0,
    ));
  }

  return fromOffsetWallClock(candidate, params.offsetMinutes);
}

export function computeFollowingRunAt(params: {
  justExecutedUtc: Date;
  hour: number;
  minute: number;
  days: unknown;
  offsetMinutes: number;
}): Date {
  return computeNextRunAt({
    hour: params.hour,
    minute: params.minute,
    days: params.days,
    fromUtc: new Date(params.justExecutedUtc.getTime() + 60_000),
    offsetMinutes: params.offsetMinutes,
  });
}

export function scheduleActionToState(action: unknown): boolean {
  const value = String(action ?? "on").trim().toLowerCase();
  return value === "on" || value === "turn_on" || value === "true";
}
