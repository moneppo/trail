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
const CACHE_VERSION = 1;

export type LngLat = [number, number];

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

async function matchChunk(chunk: LngLat[]): Promise<LngLat[] | null> {
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
  // 400/442 mean Valhalla found nothing to snap this chunk to: keep the raw
  // points. Anything else (429, 5xx) is transient, so abort and don't cache.
  if (response.status === 400 || response.status === 442) return null;
  if (!response.ok) throw new Error(`Valhalla returned ${response.status}`);

  const matched: MatchedPoint[] = (await response.json()).matched_points ?? [];
  if (matched.length !== chunk.length) return null;

  return chunk.map((raw, i) => {
    const m = matched[i];
    if (m.type === "unmatched" || m.lat == null || m.lon == null) return raw;
    const snapped: LngLat = [m.lon, m.lat];
    return distanceMeters(raw, snapped) > MAX_SNAP_METERS ? raw : snapped;
  });
}

/** Returns the snapped route, or null if matching didn't run to completion. */
async function matchRoute(raw: LngLat[]): Promise<LngLat[] | null> {
  if (raw.length < 2) return raw;
  const result = raw.slice();
  try {
    for (let start = 0; start < raw.length - 1; start += CHUNK_SIZE) {
      const end = Math.min(start + CHUNK_SIZE + OVERLAP, raw.length);
      const snapped = await matchChunk(raw.slice(start, end));
      if (!snapped) continue;
      // Each chunk carries a few extra trailing points so matching has
      // context at the seam; only the chunk's own points are kept.
      const take = start + CHUNK_SIZE < raw.length ? CHUNK_SIZE : snapped.length;
      for (let i = 0; i < take && i < snapped.length; i++) {
        result[start + i] = snapped[i];
      }
    }
  } catch {
    return null;
  }
  return result;
}

function cacheKey(walkId: string, pointCount: number) {
  return `trail:snapped:${walkId}:${pointCount}:v${CACHE_VERSION}`;
}

/**
 * Snapped route for a walk, cached in localStorage so each walk is only sent
 * to the matching service once per browser. A failed match resolves to the
 * raw route and is not cached.
 */
export async function snapRoute(walkId: string, raw: LngLat[]): Promise<LngLat[]> {
  const key = cacheKey(walkId, raw.length);
  try {
    const cached = localStorage.getItem(key);
    if (cached) {
      const parsed = JSON.parse(cached) as LngLat[];
      if (parsed.length === raw.length) return parsed;
    }
  } catch {
    // Unreadable cache entry: fall through and re-match.
  }

  const snapped = await matchRoute(raw);
  if (!snapped) return raw;
  try {
    localStorage.setItem(key, JSON.stringify(snapped));
  } catch {
    // Caching is best-effort (storage full or blocked).
  }
  return snapped;
}
