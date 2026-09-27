import assert from "node:assert/strict";
import test from "node:test";
import {
  computeFollowingRunAt,
  computeNextRunAt,
  executionKey,
  isOneTime,
  weekdayLabel,
} from "./schedule";

test("one-time schedules have empty days", () => {
  assert.equal(isOneTime([]), true);
  assert.equal(isOneTime(["Mon"]), false);
});

test("weekday schedule repeats on the next matching day, not only once", () => {
  // Wednesday 2026-09-02 19:00 UTC, offset 0, Mon/Wed/Fri 19:00
  const from = new Date("2026-09-02T19:00:00.000Z");
  const next = computeFollowingRunAt({
    justExecutedUtc: from,
    hour: 19,
    minute: 0,
    days: ["Mon", "Wed", "Fri"],
    offsetMinutes: 0,
  });
  assert.equal(next.toISOString(), "2026-09-04T19:00:00.000Z");
});

test("daily schedule returns the next calendar day at the same time", () => {
  const from = new Date("2026-09-02T07:00:00.000Z");
  const next = computeFollowingRunAt({
    justExecutedUtc: from,
    hour: 7,
    minute: 0,
    days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    offsetMinutes: 0,
  });
  assert.equal(next.toISOString(), "2026-09-03T07:00:00.000Z");
});

test("selected weekdays skip days that are not selected", () => {
  const mondayMorning = new Date("2026-08-31T08:00:00.000Z");
  const next = computeNextRunAt({
    hour: 19,
    minute: 0,
    days: ["Mon", "Wed", "Fri"],
    fromUtc: mondayMorning,
    offsetMinutes: 0,
  });
  assert.equal(weekdayLabel(next), "Mon");
  assert.equal(next.toISOString(), "2026-08-31T19:00:00.000Z");
});

test("execution keys are stable per local minute", () => {
  assert.equal(executionKey(new Date("2026-09-02T19:00:00.000Z")), "2026-09-02-19-00");
});
