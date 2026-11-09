/**
 * A date and time the way a person would say it: "Today, 6:42 PM",
 * "Yesterday, 6:42 PM", "Tuesday, 6:42 PM" within the last week, then
 * "Oct 24, 2:10 PM", adding the year for older walks. The time follows the
 * browser's locale.
 */
export function friendlyDateTime(value: string | Date, now = new Date()) {
  const when = typeof value === "string" ? new Date(value) : value;
  const time = when.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const daysAgo = Math.round((startOfDay(now) - startOfDay(when)) / 86400000);

  if (daysAgo === 0) return `Today, ${time}`;
  if (daysAgo === 1) return `Yesterday, ${time}`;
  if (daysAgo > 1 && daysAgo < 7) {
    return `${when.toLocaleDateString([], { weekday: "long" })}, ${time}`;
  }
  const date = when.toLocaleDateString([], { month: "short", day: "numeric" });
  return when.getFullYear() === now.getFullYear()
    ? `${date}, ${time}`
    : `${date}, ${when.getFullYear()}, ${time}`;
}
