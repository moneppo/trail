import type { MatchStatus } from "@/lib/routeMatcher";

/**
 * Shortest run of consecutive unmapped points worth suggesting as a trail
 * (about 45 m at the 3 m recording interval).
 */
export const MIN_UNMAPPED_RUN = 15;

/** Fewest points a submitted trail can span (about 15 m at 3 m spacing). */
export const MIN_TRAIL_POINTS = 5;

/**
 * Runs of consecutive points that aren't on a mapped path, as inclusive
 * [start, end] index pairs.
 */
export function findUnmappedRuns(statuses: MatchStatus[]): [number, number][] {
  const runs: [number, number][] = [];
  let start: number | null = null;
  for (let i = 0; i <= statuses.length; i++) {
    const unmapped = i < statuses.length && statuses[i] !== "matched";
    if (unmapped) {
      start ??= i;
    } else if (start !== null) {
      if (i - start >= MIN_UNMAPPED_RUN) runs.push([start, i - 1]);
      start = null;
    }
  }
  return runs;
}
