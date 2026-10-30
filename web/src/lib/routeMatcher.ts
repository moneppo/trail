// Snaps a recorded GPS track to known streets, sidewalks and trails using
// Valhalla's map matching (OpenStreetMap data, pedestrian costing). Mirrors
// mobile/lib/services/route_matcher.dart.
//
// Anything Valhalla can't match, or that would move a point further than
// MAX_SNAP_METERS from where we measured it, keeps its raw GPS position.

// Public FOSSGIS instance: fine for prototyping, but has fair-use limits.
// Point this at a self-hosted Valhalla for heavier use.
const ENDPOINT = "https://valhalla1.openstreetmap.de/trace_attributes";
const CHUNK_SIZE = 400;
const OVERLAP = 10;
const MAX_SNAP_METERS = 25;
const CACHE_VERSION = 2;

export type LngLat = [number, number];

/** What happened when a route was matched, for showing in the UI and logs. */
export type MatchSummary = {
  total: number;
  snapped: number; // moved onto a street/sidewalk/trail
  unmatched: number; // Valhalla found nothing nearby: raw GPS kept
  rejected: number; // snap would move the point > MAX_SNAP_METERS: raw kept
  problems: string[];
  fromCache: boolean;
};

export function describeSummary(s: MatchSummary) {
  if (s.fromCache) return "Snapped route loaded from cache";
  return [
    `${s.snapped} of ${s.total} points snapped`,
    s.unmatched > 0 ? `${s.unmatched} had no street/trail nearby` : null,
    s.rejected > 0 ? `${s.rejected} too far to snap` : null,
    s.problems.length > 0 ? `problems: ${s.problems.join("; ")}` : null,
  ]
    .filter(Boolean)
    .join(", ");
}

function log(message: string, ...rest: unknown[]) {
  console.info(`[routeMatcher] ${message}`, ...rest);
}

type MatchedPoint = { lat?: number; lon?: number; type?: string };

function distanceMeters(a: LngLat, b: LngLat) {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b[1] - a[1]);
  const dLng = toRad(b[0] - a[0]);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a[1])) * Math.cos(toRad(b[1])) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

async function matchChunk(
  chunk: LngLat[],
  index: number,
  summary: MatchSummary,
): Promise<LngLat[] | null> {
  const response = await fetch(ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      shape: chunk.map(([lon, lat]) => ({ lat, lon })),
      costing: "pedestrian",
      shape_match: "map_snap",
      trace_options: { search_radius: MAX_SNAP_METERS, gps_accuracy: 10 },
      filters: { attributes: ["matched.point", "matched.type"], action: "include" },
    }),
    signal: AbortSignal.timeout(20000),
  });
  log(`chunk ${index} (${chunk.length} pts): HTTP ${response.status}`);

  // 400/442 mean Valhalla found nothing to snap this chunk to: keep the raw
  // points. Anything else (429, 5xx) is a failure worth surfacing.
  if (response.status === 400 || response.status === 442) {
    const body = (await response.text()).slice(0, 160);
    summary.problems.push(`chunk ${index}: no match (HTTP ${response.status}) ${body}`);
    return null;
  }
  if (!response.ok) throw new Error(`Valhalla returned ${response.status}`);

  const matched: MatchedPoint[] = (await response.json()).matched_points ?? [];
  if (matched.length !== chunk.length) {
    summary.problems.push(
      `chunk ${index}: got ${matched.length} matched points for ${chunk.length}`,
    );
    return null;
  }

  return chunk.map((raw, i) => {
    const m = matched[i];
    if (m.type === "unmatched" || m.lat == null || m.lon == null) {
      summary.unmatched++;
      return raw;
    }
    const snapped: LngLat = [m.lon, m.lat];
    if (distanceMeters(raw, snapped) > MAX_SNAP_METERS) {
      summary.rejected++;
      return raw;
    }
    return snapped;
  });
}

async function matchRoute(
  raw: LngLat[],
  summary: MatchSummary,
): Promise<LngLat[]> {
  const result = raw.slice();
  if (raw.length < 2) return result;
  let index = 0;
  for (let start = 0; start < raw.length - 1; start += CHUNK_SIZE) {
    const end = Math.min(start + CHUNK_SIZE + OVERLAP, raw.length);
    index++;
    try {
      const snapped = await matchChunk(raw.slice(start, end), index, summary);
      if (!snapped) continue;
      // Each chunk carries a few extra trailing points so matching has
      // context at the seam; only the chunk's own points are kept.
      const take = start + CHUNK_SIZE < raw.length ? CHUNK_SIZE : snapped.length;
      for (let i = 0; i < take && i < snapped.length; i++) {
        result[start + i] = snapped[i];
      }
    } catch (e) {
      summary.problems.push(`chunk ${index}: ${e instanceof Error ? e.message : e}`);
      log(`chunk ${index} failed`, e);
    }
  }
  summary.snapped = result.filter(
    (p, i) => p[0] !== raw[i][0] || p[1] !== raw[i][1],
  ).length;
  return result;
}

function cacheKey(walkId: string, pointCount: number) {
  return `trail:snapped:${walkId}:${pointCount}:v${CACHE_VERSION}`;
}

/**
 * Snapped route for a walk, cached in localStorage so each walk is only sent
 * to the matching service once per browser. A failed match, or one that
 * didn't actually move any points, is not cached so it is retried next time.
 */
export async function snapRoute(
  walkId: string,
  raw: LngLat[],
): Promise<{ route: LngLat[]; summary: MatchSummary }> {
  const summary: MatchSummary = {
    total: raw.length,
    snapped: 0,
    unmatched: 0,
    rejected: 0,
    problems: [],
    fromCache: false,
  };

  const key = cacheKey(walkId, raw.length);
  try {
    const cached = localStorage.getItem(key);
    if (cached) {
      const parsed = JSON.parse(cached) as LngLat[];
      if (parsed.length === raw.length) {
        summary.fromCache = true;
        log(`walk ${walkId}: snapped route from cache`);
        return { route: parsed, summary };
      }
    }
  } catch {
    // Unreadable cache entry: fall through and re-match.
  }

  log(`walk ${walkId}: matching ${raw.length} points`);
  const route = await matchRoute(raw, summary);
  log(`walk ${walkId}: ${describeSummary(summary)}`);

  if (summary.problems.length === 0 && summary.snapped > 0) {
    try {
      localStorage.setItem(key, JSON.stringify(route));
    } catch {
      // Caching is best-effort (storage full or blocked).
    }
  }
  return { route, summary };
}
