import { supabase } from "@/lib/supabaseClient";
import { fetchAllByWalk } from "@/lib/walkData";

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

export type LngLat = [number, number];

/** What the matcher did with one point. Stored as snapped_points.match_status. */
export type MatchStatus = "matched" | "unmatched" | "rejected";

export type MatchResult = {
  route: LngLat[];
  statuses: MatchStatus[];
  /** Transient failures; when non-empty the result must not be stored. */
  errors: string[];
  /** Chunks Valhalla answered "no match" for; their points are unmatched. */
  notes: string[];
  /** True when the route was read from the database rather than matched. */
  fromDatabase: boolean;
  /** Outcome of saving to the database, if a save was attempted. */
  saveMessage?: string;
};

type MatchedPoint = { lat?: number; lon?: number; type?: string };

export function describeResult(r: MatchResult) {
  if (r.fromDatabase) return "Snapped route loaded from database";
  const count = (s: MatchStatus) => r.statuses.filter((x) => x === s).length;
  return [
    `${count("matched")} of ${r.route.length} points snapped`,
    count("unmatched") > 0 ? `${count("unmatched")} had no street/trail nearby` : null,
    count("rejected") > 0 ? `${count("rejected")} too far to snap` : null,
    r.notes.length > 0 ? r.notes.join("; ") : null,
    r.errors.length > 0 ? `problems: ${r.errors.join("; ")}` : null,
    r.saveMessage ?? null,
  ]
    .filter(Boolean)
    .join(", ");
}

function log(message: string, ...rest: unknown[]) {
  console.info(`[routeMatcher] ${message}`, ...rest);
}

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
  notes: string[],
): Promise<[LngLat, MatchStatus][] | null> {
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

  // 400/442 mean Valhalla found nothing to snap this chunk to: all of its
  // points are unmatched. Anything else (429, 5xx) is a transient failure.
  if (response.status === 400 || response.status === 442) {
    notes.push(`chunk ${index}: no match (HTTP ${response.status})`);
    return null;
  }
  if (!response.ok) throw new Error(`Valhalla returned ${response.status}`);

  const matched: MatchedPoint[] = (await response.json()).matched_points ?? [];
  if (matched.length !== chunk.length) {
    throw new Error(`got ${matched.length} matched points for ${chunk.length}`);
  }

  return chunk.map((raw, i): [LngLat, MatchStatus] => {
    const m = matched[i];
    if (m.type === "unmatched" || m.lat == null || m.lon == null) {
      return [raw, "unmatched"];
    }
    const snapped: LngLat = [m.lon, m.lat];
    return distanceMeters(raw, snapped) > MAX_SNAP_METERS
      ? [raw, "rejected"]
      : [snapped, "matched"];
  });
}

async function matchRoute(raw: LngLat[]): Promise<MatchResult> {
  const route = raw.slice();
  const statuses: MatchStatus[] = raw.map(() => "unmatched");
  const errors: string[] = [];
  const notes: string[] = [];
  let index = 0;
  for (let start = 0; start < raw.length - 1; start += CHUNK_SIZE) {
    const end = Math.min(start + CHUNK_SIZE + OVERLAP, raw.length);
    index++;
    try {
      const chunk = await matchChunk(raw.slice(start, end), index, notes);
      if (!chunk) continue;
      // Each chunk carries a few extra trailing points so matching has
      // context at the seam; only the chunk's own points are kept.
      const take = start + CHUNK_SIZE < raw.length ? CHUNK_SIZE : chunk.length;
      for (let i = 0; i < take && i < chunk.length; i++) {
        [route[start + i], statuses[start + i]] = chunk[i];
      }
    } catch (e) {
      errors.push(`chunk ${index}: ${e instanceof Error ? e.message : e}`);
      log(`chunk ${index} failed`, e);
    }
  }
  return { route, statuses, errors, notes, fromDatabase: false };
}

type SnappedRow = { lat: number; lng: number };

/**
 * The snapped route for a walk. Reads the stored route from the database
 * when there is one; otherwise matches the raw points against Valhalla and,
 * if matching ran to completion, stores the result so every device reuses it.
 * A failed match resolves to the raw route and is retried next time.
 */
export async function snapRoute(walkId: string, raw: LngLat[]): Promise<MatchResult> {
  try {
    const stored = await fetchAllByWalk<SnappedRow>("snapped_points", walkId);
    if (stored.length === raw.length) {
      log(`walk ${walkId}: snapped route loaded from database`);
      return {
        route: stored.map((r) => [r.lng, r.lat] as LngLat),
        statuses: stored.map(() => "matched" as MatchStatus),
        errors: [],
        notes: [],
        fromDatabase: true,
      };
    }
  } catch (e) {
    log(`walk ${walkId}: reading snapped route failed`, e);
  }

  log(`walk ${walkId}: matching ${raw.length} points`);
  const result = await matchRoute(raw);

  if (result.errors.length === 0) {
    const rows = result.route.map(([lng, lat], sequence) => ({
      walk_id: walkId,
      sequence,
      lat,
      lng,
      match_status: result.statuses[sequence],
    }));
    for (let i = 0; i < rows.length; i += 500) {
      const { error } = await supabase
        .from("snapped_points")
        .upsert(rows.slice(i, i + 500), { onConflict: "walk_id,sequence" });
      if (error) {
        log(`walk ${walkId}: saving snapped route failed`, error);
        result.saveMessage = `could not save: ${error.message}`;
        break;
      }
    }
    if (!result.saveMessage) result.saveMessage = "saved";
  }
  log(`walk ${walkId}: ${describeResult(result)}`);
  return result;
}
